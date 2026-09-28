from __future__ import annotations

import argparse
import json
import os
import sqlite3
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

try:
    from plyer import notification as plyer_notification
except Exception:  # pragma: no cover - optional dependency fallback
    plyer_notification = None


class VocPayload(BaseModel):
    id: str
    title: str
    content: str
    category: str = "운영문의"
    tags: Optional[str] = None
    customer: str = "미입력"
    project: str = "미입력"
    priority: str = "MEDIUM"
    status: str = "OPEN"
    business_type: Optional[str] = None
    urgency: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class VocCreatedEvent(BaseModel):
    event: str = Field(default="voc.created")
    sent_at: Optional[str] = None
    source_app: str = "unknown-app"
    voc: VocPayload


class FullSyncSnapshot(BaseModel):
    vocs: list[dict[str, Any]] = []
    responses: list[dict[str, Any]] = []
    manuals: list[dict[str, Any]] = []


class FullSyncEvent(BaseModel):
    event: str = Field(default="sync.full")
    sent_at: Optional[str] = None
    source_app: str = "unknown-app"
    sync_mode: str = "upsert"
    snapshot: FullSyncSnapshot


def _now_iso() -> str:
    return datetime.utcnow().isoformat()


def _ensure_schema(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS responses (
            id TEXT PRIMARY KEY,
            voc_id TEXT NOT NULL,
            content TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'DRAFT',
            ai_generated INTEGER NOT NULL DEFAULT 0,
            confidence_score REAL,
            referenced_voc_ids TEXT,
            approved_by TEXT,
            approved_at TEXT,
            adoption_count INTEGER NOT NULL DEFAULT 0,
            usage_count INTEGER NOT NULL DEFAULT 0,
            last_used_at TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS knowledge_base (
            id TEXT PRIMARY KEY,
            question TEXT NOT NULL,
            answer TEXT NOT NULL,
            category TEXT NOT NULL,
            customer TEXT,
            project TEXT,
            voc_id TEXT,
            embedding TEXT,
            resolved_at TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS vocs (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            category TEXT NOT NULL,
            tags TEXT,
            customer TEXT NOT NULL,
            project TEXT NOT NULL,
            priority TEXT NOT NULL DEFAULT 'MEDIUM',
            status TEXT NOT NULL DEFAULT 'OPEN',
            ai_category TEXT,
            is_business_related INTEGER NOT NULL DEFAULT 1,
            business_score REAL,
            category_score REAL,
            urgency TEXT,
            urgency_score REAL,
            business_type TEXT,
            department TEXT,
            department_score REAL,
            assignee TEXT,
            assignee_score REAL,
            duplicate_of_voc_id TEXT,
            duplicate_score REAL,
            jira_required INTEGER NOT NULL DEFAULT 0,
            jira_score REAL,
            analysis_reason TEXT,
            embedding TEXT,
            source TEXT,
            source_ref TEXT,
            processing_minutes INTEGER,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS sync_events (
            seq INTEGER PRIMARY KEY AUTOINCREMENT,
            event_type TEXT NOT NULL,
            source_app TEXT,
            sync_mode TEXT,
            status TEXT NOT NULL,
            endpoint TEXT,
            message TEXT,
            counts_json TEXT,
            created_at TEXT NOT NULL
        )
        """
    )
    conn.commit()


def _insert_or_replace(
    conn: sqlite3.Connection,
    table: str,
    columns: list[str],
    rows: list[dict[str, Any]],
    defaults: dict[str, Any],
) -> int:
    if not rows:
        return 0

    placeholders = ",".join(["?"] * len(columns))
    col_clause = ",".join(columns)
    sql = f"INSERT OR REPLACE INTO {table} ({col_clause}) VALUES ({placeholders})"

    count = 0
    for row in rows:
        values = []
        for col in columns:
            if col in row and row[col] is not None:
                values.append(row[col])
            else:
                values.append(defaults.get(col))
        conn.execute(sql, tuple(values))
        count += 1
    return count


def _connect(db_path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(str(db_path), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    _ensure_schema(conn)
    return conn


def _log_sync_event(
    conn: sqlite3.Connection,
    *,
    event_type: str,
    source_app: Optional[str],
    sync_mode: Optional[str],
    status: str,
    endpoint: Optional[str],
    message: Optional[str],
    counts: Optional[dict[str, int]],
) -> None:
    conn.execute(
        """
        INSERT INTO sync_events (
            event_type, source_app, sync_mode, status,
            endpoint, message, counts_json, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            event_type,
            source_app,
            sync_mode,
            status,
            endpoint,
            message,
            json.dumps(counts or {}, ensure_ascii=False),
            _now_iso(),
        ),
    )
    conn.commit()


def _notify_desktop(enabled: bool, title: str, message: str) -> None:
    if not enabled or plyer_notification is None:
        return
    try:
        plyer_notification.notify(
            title=title,
            message=message,
            app_name="AI VOC Sync Receiver",
            timeout=5,
        )
    except Exception:
        # 알림 실패는 수신 자체를 막지 않는다.
        pass


def _require_auth(authorization: Optional[str], bearer_token: Optional[str]) -> None:
    if not bearer_token:
        return
    if not authorization:
        raise HTTPException(status_code=401, detail="missing authorization header")

    parts = authorization.strip().split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(status_code=401, detail="invalid authorization scheme")

    if parts[1].strip() != bearer_token:
        raise HTTPException(status_code=401, detail="invalid bearer token")


def create_app(
    db_path: Path,
    bearer_token: Optional[str] = None,
    desktop_notify: bool = True,
) -> FastAPI:
    app = FastAPI(title="AI VOC Sync Receiver")
    conn = _connect(db_path)

    @app.get("/health")
    def health() -> dict:
        row = conn.execute("SELECT COUNT(*) AS cnt FROM vocs").fetchone()
        return {
            "status": "ok",
            "db_path": str(db_path),
            "voc_count": int(row["cnt"] if row else 0),
        }

    @app.post("/webhook/voc")
    def receive_voc(
        event: VocCreatedEvent,
        authorization: Optional[str] = Header(default=None),
    ) -> dict:
        if event.event != "voc.created":
            raise HTTPException(status_code=400, detail="unsupported event")
        _require_auth(authorization, bearer_token)

        source_ref = f"{event.source_app}:{event.voc.id}"
        exists = conn.execute(
            "SELECT id FROM vocs WHERE source = ? AND source_ref = ? LIMIT 1",
            ("peer-sync", source_ref),
        ).fetchone()
        if exists:
            return {
                "ok": True,
                "action": "duplicate",
                "id": exists["id"],
                "source_ref": source_ref,
            }

        now = _now_iso()
        created_at = event.voc.created_at or now
        updated_at = event.voc.updated_at or now
        new_id = str(uuid.uuid4())

        conn.execute(
            """
            INSERT INTO vocs (
                id, title, content, category, tags, customer, project,
                priority, status, urgency, business_type,
                source, source_ref, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                new_id,
                event.voc.title.strip() or "제목없음",
                event.voc.content.strip() or "내용 없음",
                event.voc.category.strip() or "운영문의",
                event.voc.tags,
                event.voc.customer.strip() or "미입력",
                event.voc.project.strip() or "미입력",
                event.voc.priority.strip() or "MEDIUM",
                event.voc.status.strip() or "OPEN",
                event.voc.urgency,
                event.voc.business_type,
                "peer-sync",
                source_ref,
                created_at,
                updated_at,
            ),
        )
        conn.commit()

        _log_sync_event(
            conn,
            event_type="voc.created",
            source_app=event.source_app,
            sync_mode="upsert",
            status="created",
            endpoint="/webhook/voc",
            message=f"VOC 1건 수신: {event.voc.title.strip() or '제목없음'}",
            counts={"vocs": 1, "responses": 0, "manuals": 0},
        )
        _notify_desktop(
            desktop_notify,
            "VOC 동기화 수신",
            f"{event.source_app}에서 VOC 1건을 받았습니다.",
        )

        return {
            "ok": True,
            "action": "created",
            "id": new_id,
            "source_ref": source_ref,
        }

    @app.post("/webhook/sync/full")
    def receive_full_sync(
        event: FullSyncEvent,
        authorization: Optional[str] = Header(default=None),
    ) -> dict:
        if event.event != "sync.full":
            raise HTTPException(status_code=400, detail="unsupported event")
        _require_auth(authorization, bearer_token)

        now = _now_iso()

        voc_columns = [
            "id",
            "title",
            "content",
            "category",
            "tags",
            "customer",
            "project",
            "priority",
            "status",
            "ai_category",
            "is_business_related",
            "business_score",
            "category_score",
            "urgency",
            "urgency_score",
            "business_type",
            "department",
            "department_score",
            "assignee",
            "assignee_score",
            "duplicate_of_voc_id",
            "duplicate_score",
            "jira_required",
            "jira_score",
            "analysis_reason",
            "embedding",
            "source",
            "source_ref",
            "processing_minutes",
            "created_at",
            "updated_at",
        ]
        response_columns = [
            "id",
            "voc_id",
            "content",
            "status",
            "ai_generated",
            "confidence_score",
            "referenced_voc_ids",
            "approved_by",
            "approved_at",
            "adoption_count",
            "usage_count",
            "last_used_at",
            "created_at",
            "updated_at",
        ]
        manual_columns = [
            "id",
            "question",
            "answer",
            "category",
            "customer",
            "project",
            "voc_id",
            "embedding",
            "resolved_at",
            "created_at",
        ]

        voc_defaults = {
            "id": None,
            "title": "제목없음",
            "content": "내용 없음",
            "category": "운영문의",
            "tags": None,
            "customer": "미입력",
            "project": "미입력",
            "priority": "MEDIUM",
            "status": "OPEN",
            "ai_category": None,
            "is_business_related": 1,
            "business_score": None,
            "category_score": None,
            "urgency": None,
            "urgency_score": None,
            "business_type": None,
            "department": None,
            "department_score": None,
            "assignee": None,
            "assignee_score": None,
            "duplicate_of_voc_id": None,
            "duplicate_score": None,
            "jira_required": 0,
            "jira_score": None,
            "analysis_reason": None,
            "embedding": None,
            "source": "peer-sync-full",
            "source_ref": None,
            "processing_minutes": None,
            "created_at": now,
            "updated_at": now,
        }

        response_defaults = {
            "id": None,
            "voc_id": None,
            "content": "",
            "status": "DRAFT",
            "ai_generated": 0,
            "confidence_score": None,
            "referenced_voc_ids": None,
            "approved_by": None,
            "approved_at": None,
            "adoption_count": 0,
            "usage_count": 0,
            "last_used_at": None,
            "created_at": now,
            "updated_at": now,
        }

        manual_defaults = {
            "id": None,
            "question": "",
            "answer": "",
            "category": "시스템매뉴얼",
            "customer": None,
            "project": "manual-upload",
            "voc_id": None,
            "embedding": None,
            "resolved_at": now,
            "created_at": now,
        }

        try:
            conn.execute("BEGIN")
            voc_count = _insert_or_replace(
                conn,
                "vocs",
                voc_columns,
                event.snapshot.vocs,
                voc_defaults,
            )

            # voc_id 또는 id가 없는 응답은 무시
            valid_responses = [
                r
                for r in event.snapshot.responses
                if (r.get("id") is not None and r.get("voc_id") is not None)
            ]
            response_count = _insert_or_replace(
                conn,
                "responses",
                response_columns,
                valid_responses,
                response_defaults,
            )

            # question/answer가 비어 있는 매뉴얼은 무시
            valid_manuals = [
                m
                for m in event.snapshot.manuals
                if (m.get("id") is not None and m.get("question") and m.get("answer"))
            ]
            manual_count = _insert_or_replace(
                conn,
                "knowledge_base",
                manual_columns,
                valid_manuals,
                manual_defaults,
            )

            conn.commit()
            _log_sync_event(
                conn,
                event_type="sync.full",
                source_app=event.source_app,
                sync_mode=event.sync_mode,
                status="applied",
                endpoint="/webhook/sync/full",
                message="전체 VOC/매뉴얼 동기화 수신",
                counts={
                    "vocs": voc_count,
                    "responses": response_count,
                    "manuals": manual_count,
                },
            )
            _notify_desktop(
                desktop_notify,
                "전체 동기화 수신",
                f"{event.source_app}에서 VOC {voc_count}건, 매뉴얼 {manual_count}건을 받았습니다.",
            )
        except Exception as exc:  # pragma: no cover - runtime safety
            conn.rollback()
            raise HTTPException(status_code=500, detail=f"sync failed: {exc}") from exc

        return {
            "ok": True,
            "action": "sync.full.applied",
            "source_app": event.source_app,
            "sync_mode": event.sync_mode,
            "counts": {
                "vocs": voc_count,
                "responses": response_count,
                "manuals": manual_count,
            },
        }

    return app


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--db-path",
        default="./voc_assistant.db",
        help="Target sqlite db path for VOC insert",
    )
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8788)
    parser.add_argument(
        "--bearer-token",
        default=os.environ.get("VOC_SYNC_BEARER_TOKEN", ""),
        help="Optional bearer token for /webhook endpoints",
    )
    parser.add_argument(
        "--desktop-notify",
        default=os.environ.get("VOC_SYNC_DESKTOP_NOTIFY", "true"),
        help="Enable desktop notification on inbound sync events (true/false)",
    )
    args = parser.parse_args()

    db_path = Path(args.db_path).expanduser().resolve()
    db_path.parent.mkdir(parents=True, exist_ok=True)

    bearer_token = args.bearer_token.strip() or None
    desktop_notify = str(args.desktop_notify).strip().lower() not in {
        "0",
        "false",
        "off",
        "no",
    }
    app = create_app(
        db_path,
        bearer_token=bearer_token,
        desktop_notify=desktop_notify,
    )

    import uvicorn

    uvicorn.run(app, host=args.host, port=args.port)


if __name__ == "__main__":
    main()
