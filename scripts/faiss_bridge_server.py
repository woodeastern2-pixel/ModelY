from typing import Dict, List, Any
import threading
from functools import wraps

import numpy as np
from fastapi import FastAPI
from pydantic import BaseModel, Field

try:
    import faiss
except Exception as exc:
    raise RuntimeError(
        "faiss-cpu가 설치되어야 합니다. pip install faiss-cpu"
    ) from exc


class UpsertRequest(BaseModel):
    id: str
    vector: List[float]
    payload: Dict[str, Any] = {}


class SearchRequest(BaseModel):
    vector: List[float]
    top_k: int = Field(default=5, ge=1, le=100)


app = FastAPI(title="AI VOC FAISS Bridge")

_DIM = None
_INDEX = None
_IDS: List[str] = []
_PAYLOADS: Dict[str, Dict[str, Any]] = {}
_VECTORS: Dict[str, np.ndarray] = {}
_LOCK = threading.RLock()


def _locked(function):
    @wraps(function)
    def wrapped(*args, **kwargs):
        with _LOCK:
            return function(*args, **kwargs)
    return wrapped


def _ensure_index(dim: int):
    global _DIM, _INDEX
    if _INDEX is None:
        _DIM = dim
        # 코사인 유사도: 벡터 정규화 + Inner Product
        _INDEX = faiss.IndexFlatIP(dim)
    elif _DIM != dim:
        raise ValueError(f"임베딩 차원이 다릅니다. expected={_DIM}, got={dim}")


def _normalize(v: np.ndarray) -> np.ndarray:
    norm = np.linalg.norm(v, axis=1, keepdims=True)
    norm[norm == 0] = 1.0
    return v / norm


@app.get("/health")
@_locked
def health():
    return {"status": "ok", "count": len(_IDS), "dim": _DIM}


@app.post("/upsert")
@_locked
def upsert(req: UpsertRequest):
    vec = np.array([req.vector], dtype=np.float32)
    _ensure_index(vec.shape[1])
    vec = _normalize(vec)

    replacing = req.id in _VECTORS
    _VECTORS[req.id] = vec
    if replacing:
        _INDEX.reset()
        _INDEX.add(np.concatenate([_VECTORS[item_id] for item_id in _IDS], axis=0))
    else:
        _INDEX.add(vec)
        _IDS.append(req.id)
    _PAYLOADS[req.id] = req.payload

    return {"ok": True, "count": len(_IDS)}


@app.post("/search")
@_locked
def search(req: SearchRequest):
    if _INDEX is None or len(_IDS) == 0:
        return {"results": []}

    q = np.array([req.vector], dtype=np.float32)
    if q.shape[1] != _DIM:
        return {"results": []}

    q = _normalize(q)
    scores, indices = _INDEX.search(q, min(req.top_k, len(_IDS)))

    results = []
    for score, idx in zip(scores[0], indices[0]):
        if idx < 0 or idx >= len(_IDS):
            continue
        item_id = _IDS[idx]
        results.append(
            {
                "id": item_id,
                "score": float(score),
                "payload": _PAYLOADS.get(item_id, {}),
            }
        )

    return {"results": results}
