class AppConstants {
  AppConstants._();

  static const String appName = 'AI VOC Assistant';
  static const String appVersion = '1.0.0';

  // DB
  static const String dbName = 'voc_assistant.db';
  static const int dbVersion = 4;

  // Tables
  static const String tableVocs = 'vocs';
  static const String tableResponses = 'responses';
  static const String tableKnowledgeBase = 'knowledge_base';
  static const String tableJiraLinks = 'jira_links';
  static const String tableSettings = 'settings';
  static const String tableEmails = 'emails';
  static const String tableEmailAttachments = 'email_attachments';
  static const String tableAgentLogs = 'agent_logs';
  static const String tableAiAccuracyMetrics = 'ai_accuracy_metrics';
  static const String tableSyncEvents = 'sync_events';

  // Settings Keys
  static const String settingAiProvider = 'ai_provider';
  static const String settingAiTemperature = 'ai_temperature';
  static const String settingAiMaxTokens = 'ai_max_tokens';
  static const String settingOllamaUrl = 'ollama_url';
  static const String settingOllamaModel = 'ollama_model';
  static const String settingOpenAiKey = 'openai_api_key';
  static const String settingOpenAiModel = 'openai_model';
  static const String settingGeminiKey = 'gemini_api_key';
  static const String settingGeminiModel = 'gemini_model';
  static const String settingClaudeKey = 'claude_api_key';
  static const String settingClaudeModel = 'claude_model';
  static const String settingClaudeBaseUrl = 'claude_base_url';
  static const String settingFaissEndpoint = 'faiss_endpoint';
  static const String settingJiraUrl = 'jira_url';
  static const String settingJiraProjectKey = 'jira_project_key';
  static const String settingJiraToken = 'jira_token';
  static const String settingJiraEmail = 'jira_email';
  static const String settingAdminPassword = 'admin_password';
  static const String settingUserName = 'user_name';
  static const String settingUserRole = 'user_role';
  static const String settingCustomCategories = 'custom_categories';
  static const String settingProjectCodes = 'project_codes';
  static const String settingBusinessTypeOptions = 'business_type_options';
  static const String settingProjectNameOptions = 'project_name_options';
  static const String settingTextScale = 'text_scale';
  static const String settingThemeMode = 'theme_mode'; // light, dark
  static const String settingOutlookAccessToken = 'outlook_access_token';
  static const String settingOutlookMailbox = 'outlook_mailbox';
  static const String settingOutlookFolder = 'outlook_folder';
  static const String settingTeamsWebhook = 'teams_webhook';
  static const String settingSlackWebhook = 'slack_webhook';
  static const String settingConfluenceUrl = 'confluence_url';
  static const String settingConfluenceSpace = 'confluence_space';
  static const String settingConfluenceEmail = 'confluence_email';
  static const String settingConfluenceToken = 'confluence_token';
  static const String settingRedmineUrl = 'redmine_url';
  static const String settingRedmineProject = 'redmine_project';
  static const String settingRedmineApiKey = 'redmine_api_key';
  static const String settingNotionWorkspace = 'notion_workspace';
  static const String settingNotionDatabaseId = 'notion_database_id';
  static const String settingNotionApiKey = 'notion_api_key';
  static const String settingGithubRepo = 'github_repo';
  static const String settingGithubToken = 'github_token';
  static const String settingAsanaWorkspace = 'asana_workspace';
  static const String settingAsanaProject = 'asana_project';
  static const String settingAsanaToken = 'asana_token';
  static const String settingUrgencyWebhookThreshold =
      'urgency_webhook_threshold';
  static const String settingAiAutoAnswerOnVocRegister =
      'ai_auto_answer_on_voc_register';
  static const String settingAppInstanceName = 'app_instance_name';
  static const String settingVocAutoForwardEnabled = 'voc_auto_forward_enabled';
  static const String settingVocForwardWebhookTargets =
      'voc_forward_webhook_targets';
  static const String settingVocSyncBearerToken = 'voc_sync_bearer_token';
  static const String settingVocSyncRetryQueue = 'voc_sync_retry_queue';

  // AI Providers
  static const String aiProviderOllama = 'ollama';
  static const String aiProviderOpenAi = 'openai';
  static const String aiProviderGemini = 'gemini';
  static const String aiProviderClaude = 'claude';

  // Default values
  static const String defaultOllamaUrl = 'http://localhost:11434';
  static const String defaultOllamaModel = 'llama3.2';
  static const String defaultAiTemperature = '0.3';
  static const String defaultAiMaxTokens = '2048';
  static const String defaultOpenAiModel = 'gpt-4o-mini';
  static const String defaultGeminiModel = 'gemini-1.5-flash';
  static const String defaultClaudeModel = 'claude-3-5-sonnet-latest';
  static const String defaultClaudeBaseUrl = 'https://api.anthropic.com/v1';
  static const String defaultAdminPassword = 'share2012!!';
  static const String defaultUrgencyWebhookThreshold = 'High';
  static const String defaultTextScale = '1.0';
  static const String defaultAiAutoAnswerOnVocRegister = 'true';
  static const String defaultAppInstanceName = 'AI-VOC-APP';
  static const String defaultVocAutoForwardEnabled = 'false';

  // VOC Status
  static const String vocStatusOpen = 'OPEN';
  static const String vocStatusInProgress = 'IN_PROGRESS';
  static const String vocStatusResolved = 'RESOLVED';
  static const String vocStatusRejected = 'REJECTED';

  // Response Status
  static const String responseDraft = 'DRAFT';
  static const String responseApproved = 'APPROVED';

  // Priority
  static const String priorityHigh = 'HIGH';
  static const String priorityMedium = 'MEDIUM';
  static const String priorityLow = 'LOW';

  // Default Categories
  static const List<String> defaultCategories = [
    '장애',
    '기능문의',
    '사용법',
    '개선요청',
    '운영문의',
    '계약문의',
    '성능',
    '보안',
    '연동',
    '데이터',
    '권한',
    'UI/UX',
    '모바일',
    '인프라',
    '기타',
  ];

  static const List<String> defaultBusinessTypeOptions = [
    '메일',
    '유저',
    '미팅',
    '메신저',
    'Aipage',
  ];

  static const List<String> defaultProjectNameOptions = [
    'BW서비스운영',
  ];

  // Vector Search
  static const int topKSimilar = 5;
  static const double similarityThreshold = 0.3;

  // Embedding dimension (OpenAI text-embedding-3-small)
  static const int embeddingDim = 1536;
}
