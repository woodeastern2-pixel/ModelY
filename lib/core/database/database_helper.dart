import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onOpen(Database db) async {
    await _ensureVocTableColumns(db);
    await _ensureSyncEventTable(db);
    await db.insert(
      AppConstants.tableSettings,
      {
        'key': AppConstants.settingAdminPassword,
        'value': AppConstants.defaultAdminPassword,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tableVocs} (
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
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableResponses} (
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
        updated_at TEXT NOT NULL,
        FOREIGN KEY (voc_id) REFERENCES ${AppConstants.tableVocs}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableKnowledgeBase} (
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
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableJiraLinks} (
        id TEXT PRIMARY KEY,
        voc_id TEXT NOT NULL,
        jira_key TEXT NOT NULL,
        jira_summary TEXT,
        jira_status TEXT,
        jira_assignee TEXT,
        jira_url TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (voc_id) REFERENCES ${AppConstants.tableVocs}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableSettings} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableEmails} (
        id TEXT PRIMARY KEY,
        outlook_message_id TEXT NOT NULL UNIQUE,
        sender TEXT,
        subject TEXT,
        body_preview TEXT,
        received_at TEXT,
        imported_voc_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableEmailAttachments} (
        id TEXT PRIMARY KEY,
        email_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        content_type TEXT,
        size INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (email_id) REFERENCES ${AppConstants.tableEmails}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableAgentLogs} (
        id TEXT PRIMARY KEY,
        voc_id TEXT NOT NULL,
        workflow_id TEXT NOT NULL,
        step_index INTEGER NOT NULL,
        step_name TEXT NOT NULL,
        step_id TEXT NOT NULL,
        status TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        result_json TEXT,
        error_message TEXT,
        duration_ms INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (voc_id) REFERENCES ${AppConstants.tableVocs}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableAiAccuracyMetrics} (
        id TEXT PRIMARY KEY,
        voc_id TEXT NOT NULL,
        category_correct INTEGER NOT NULL DEFAULT 0,
        assignee_correct INTEGER NOT NULL DEFAULT 0,
        urgency_correct INTEGER NOT NULL DEFAULT 0,
        answer_adopted INTEGER NOT NULL DEFAULT 0,
        category_confidence REAL,
        assignee_confidence REAL,
        urgency_confidence REAL,
        user_feedback TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (voc_id) REFERENCES ${AppConstants.tableVocs}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_feedback (
        id TEXT PRIMARY KEY,
        voc_id TEXT NOT NULL,
        response_id TEXT,
        feedback_type TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (voc_id) REFERENCES ${AppConstants.tableVocs}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_chat_messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        category TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        referenced_voc_ids TEXT,
        confidence REAL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableSyncEvents} (
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
    ''');

    await _insertDefaultSettings(db);
    await _insertSampleData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN business_score REAL',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN tags TEXT',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN category_score REAL',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN urgency TEXT',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN urgency_score REAL',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN department TEXT',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN department_score REAL',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN assignee TEXT',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN assignee_score REAL',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN duplicate_of_voc_id TEXT',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN duplicate_score REAL',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN jira_required INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN jira_score REAL',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN analysis_reason TEXT',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN embedding TEXT',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN source TEXT',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN source_ref TEXT',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN processing_minutes INTEGER',
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tableEmails} (
          id TEXT PRIMARY KEY,
          outlook_message_id TEXT NOT NULL UNIQUE,
          sender TEXT,
          subject TEXT,
          body_preview TEXT,
          received_at TEXT,
          imported_voc_id TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tableEmailAttachments} (
          id TEXT PRIMARY KEY,
          email_id TEXT NOT NULL,
          file_name TEXT NOT NULL,
          file_path TEXT NOT NULL,
          content_type TEXT,
          size INTEGER,
          created_at TEXT NOT NULL,
          FOREIGN KEY (email_id) REFERENCES ${AppConstants.tableEmails}(id)
        )
      ''');

      await _insertDefaultSettings(db);
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tableAgentLogs} (
          id TEXT PRIMARY KEY,
          voc_id TEXT NOT NULL,
          workflow_id TEXT NOT NULL,
          step_index INTEGER NOT NULL,
          step_name TEXT NOT NULL,
          step_id TEXT NOT NULL,
          status TEXT NOT NULL,
          start_time TEXT NOT NULL,
          end_time TEXT,
          result_json TEXT,
          error_message TEXT,
          duration_ms INTEGER,
          created_at TEXT NOT NULL,
          FOREIGN KEY (voc_id) REFERENCES ${AppConstants.tableVocs}(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tableAiAccuracyMetrics} (
          id TEXT PRIMARY KEY,
          voc_id TEXT NOT NULL,
          category_correct INTEGER NOT NULL DEFAULT 0,
          assignee_correct INTEGER NOT NULL DEFAULT 0,
          urgency_correct INTEGER NOT NULL DEFAULT 0,
          answer_adopted INTEGER NOT NULL DEFAULT 0,
          category_confidence REAL,
          assignee_confidence REAL,
          urgency_confidence REAL,
          user_feedback TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (voc_id) REFERENCES ${AppConstants.tableVocs}(id)
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE ${AppConstants.tableResponses} ADD COLUMN adoption_count INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableResponses} ADD COLUMN usage_count INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableResponses} ADD COLUMN last_used_at TEXT',
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ai_feedback (
          id TEXT PRIMARY KEY,
          voc_id TEXT NOT NULL,
          response_id TEXT,
          feedback_type TEXT NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (voc_id) REFERENCES ${AppConstants.tableVocs}(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ai_chat_messages (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          category TEXT NOT NULL,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          referenced_voc_ids TEXT,
          confidence REAL,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _ensureVocTableColumns(Database db) async {
    final requiredVocColumns = <String, String>{
      'tags': 'TEXT',
      'business_score': 'REAL',
      'category_score': 'REAL',
      'urgency': 'TEXT',
      'urgency_score': 'REAL',
      'business_type': 'TEXT',
      'department': 'TEXT',
      'department_score': 'REAL',
      'assignee': 'TEXT',
      'assignee_score': 'REAL',
      'duplicate_of_voc_id': 'TEXT',
      'duplicate_score': 'REAL',
      'jira_required': 'INTEGER NOT NULL DEFAULT 0',
      'jira_score': 'REAL',
      'analysis_reason': 'TEXT',
      'embedding': 'TEXT',
      'source': 'TEXT',
      'source_ref': 'TEXT',
      'processing_minutes': 'INTEGER',
    };

    for (final entry in requiredVocColumns.entries) {
      final column = entry.key;
      if (await _hasColumn(db, AppConstants.tableVocs, column)) {
        continue;
      }
      await db.execute(
        'ALTER TABLE ${AppConstants.tableVocs} ADD COLUMN $column ${entry.value}',
      );
    }
  }

  Future<void> _ensureSyncEventTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableSyncEvents} (
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
    ''');
  }

  Future<bool> _hasColumn(Database db, String table, String column) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    for (final row in columns) {
      final name = row['name']?.toString().toLowerCase();
      if (name == column.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  Future<void> _insertDefaultSettings(Database db) async {
    final now = DateTime.now().toIso8601String();
    final defaults = {
      AppConstants.settingAiProvider: AppConstants.aiProviderOllama,
      AppConstants.settingAiTemperature: AppConstants.defaultAiTemperature,
      AppConstants.settingAiMaxTokens: AppConstants.defaultAiMaxTokens,
      AppConstants.settingOllamaUrl: AppConstants.defaultOllamaUrl,
      AppConstants.settingOllamaModel: AppConstants.defaultOllamaModel,
      AppConstants.settingOpenAiKey: '',
      AppConstants.settingOpenAiModel: AppConstants.defaultOpenAiModel,
      AppConstants.settingGeminiKey: '',
      AppConstants.settingGeminiModel: AppConstants.defaultGeminiModel,
      AppConstants.settingClaudeKey: '',
      AppConstants.settingClaudeModel: AppConstants.defaultClaudeModel,
      AppConstants.settingClaudeBaseUrl: AppConstants.defaultClaudeBaseUrl,
      AppConstants.settingFaissEndpoint: '',
      AppConstants.settingJiraUrl: '',
      AppConstants.settingJiraProjectKey: '',
      AppConstants.settingJiraToken: '',
      AppConstants.settingJiraEmail: '',
      AppConstants.settingAdminPassword: AppConstants.defaultAdminPassword,
      AppConstants.settingUserName: '담당자',
      AppConstants.settingUserRole: 'user',
      AppConstants.settingCustomCategories: '',
      AppConstants.settingOutlookAccessToken: '',
      AppConstants.settingOutlookMailbox: '',
      AppConstants.settingOutlookFolder: 'Inbox',
      AppConstants.settingTeamsWebhook: '',
      AppConstants.settingSlackWebhook: '',
      AppConstants.settingConfluenceUrl: '',
      AppConstants.settingConfluenceSpace: '',
      AppConstants.settingConfluenceEmail: '',
      AppConstants.settingConfluenceToken: '',
      AppConstants.settingAppInstanceName: AppConstants.defaultAppInstanceName,
      AppConstants.settingVocAutoForwardEnabled:
          AppConstants.defaultVocAutoForwardEnabled,
      AppConstants.settingVocForwardWebhookTargets: '',
      AppConstants.settingUrgencyWebhookThreshold:
          AppConstants.defaultUrgencyWebhookThreshold,
        AppConstants.settingAiAutoAnswerOnVocRegister:
          AppConstants.defaultAiAutoAnswerOnVocRegister,
    };

    for (final entry in defaults.entries) {
      await db.insert(
        AppConstants.tableSettings,
        {
          'key': entry.key,
          'value': entry.value,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _insertSampleData(Database db) async {
    final now = DateTime.now().toIso8601String();

    final sampleKb = [
      {
        'id': 'kb-001',
        'question': '로그인이 안됩니다. 비밀번호를 잊어버렸어요.',
        'answer':
            '비밀번호 초기화를 위해 로그인 화면 하단의 "비밀번호 찾기"를 클릭하세요. 등록된 이메일로 초기화 링크가 발송됩니다. 이메일을 확인하시고 링크를 통해 비밀번호를 재설정해 주세요.',
        'category': '사용법',
        'customer': '샘플고객A',
        'project': '포털시스템',
        'voc_id': null,
        'embedding': null,
        'resolved_at': now,
        'created_at': now,
      },
      {
        'id': 'kb-002',
        'question': '시스템이 갑자기 느려졌습니다. 화면이 로딩이 안 됩니다.',
        'answer':
            '현재 서버 모니터링 결과 특이사항이 없습니다. 브라우저 캐시 삭제 후 재시도해 주세요. Chrome 기준: 설정 > 개인정보 > 인터넷 사용 기록 삭제. 문제가 지속되면 사용 중인 브라우저와 OS 버전을 알려주시면 추가 확인하겠습니다.',
        'category': '장애',
        'customer': '샘플고객B',
        'project': '업무시스템',
        'voc_id': null,
        'embedding': null,
        'resolved_at': now,
        'created_at': now,
      },
      {
        'id': 'kb-003',
        'question': '엑셀 다운로드 기능이 동작하지 않습니다.',
        'answer':
            '엑셀 다운로드 시 팝업이 차단되고 있을 수 있습니다. 브라우저 주소창 우측의 팝업 차단 아이콘을 클릭하여 팝업을 허용해 주세요. 또는 보안 소프트웨어가 파일 다운로드를 차단하는 경우 보안 설정을 확인해 주세요.',
        'category': '기능문의',
        'customer': '샘플고객C',
        'project': '리포트시스템',
        'voc_id': null,
        'embedding': null,
        'resolved_at': now,
        'created_at': now,
      },
      {
        'id': 'kb-004',
        'question': '결재선 설정을 변경하고 싶습니다.',
        'answer':
            '결재선 변경은 [시스템 설정] > [결재 관리] > [결재선 설정] 메뉴에서 가능합니다. 단, 결재선 변경 권한은 관리자에게 있으므로 소속 부서의 시스템 관리자에게 요청해 주시기 바랍니다.',
        'category': '사용법',
        'customer': '샘플고객D',
        'project': '전자결재',
        'voc_id': null,
        'embedding': null,
        'resolved_at': now,
        'created_at': now,
      },
      {
        'id': 'kb-005',
        'question': '데이터가 저장되지 않고 사라집니다.',
        'answer':
            '세션 만료로 인해 데이터가 저장되지 않는 경우가 발생할 수 있습니다. 장시간 작업 시 중간중간 저장을 권장합니다. 현상이 반복된다면 발생 시간과 수행 중이던 작업을 상세히 알려주시면 로그를 확인하여 원인을 파악하겠습니다.',
        'category': '장애',
        'customer': '샘플고객E',
        'project': '데이터관리',
        'voc_id': null,
        'embedding': null,
        'resolved_at': now,
        'created_at': now,
      },
    ];

    for (final kb in sampleKb) {
      await db.insert(AppConstants.tableKnowledgeBase, kb);
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
