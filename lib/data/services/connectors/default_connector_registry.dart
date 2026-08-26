import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/voc_entity.dart';
import '../../../presentation/viewmodels/settings_viewmodel.dart';
import '../confluence_service.dart';
import '../outlook_service.dart';
import '../webhook_service.dart';
import 'integration_connectors.dart';

class DefaultConnectorRegistry {
  final SettingsViewModel settings;
  final OutlookService _outlook;
  final WebhookService _webhook;

  DefaultConnectorRegistry(
    this.settings, {
    OutlookService? outlook,
    WebhookService? webhook,
  })  : _outlook = outlook ?? OutlookService(),
        _webhook = webhook ?? WebhookService();

  OutlookCollectorConnector get outlookCollector =>
      OutlookGraphConnector(settings: settings, service: _outlook);

  AlertNotifierConnector get teamsNotifier =>
      TeamsWebhookConnector(settings: settings, service: _webhook);

  AlertNotifierConnector get slackNotifier =>
      SlackWebhookConnector(settings: settings, service: _webhook);

  KnowledgeBasePublisherConnector get confluencePublisher =>
      ConfluenceFaqConnector(settings: settings);
}

class OutlookGraphConnector implements OutlookCollectorConnector {
  final SettingsViewModel settings;
  final OutlookService service;

  OutlookGraphConnector({required this.settings, required this.service});

  @override
  String get key => 'outlook-graph';

  @override
  String get displayName => 'Outlook Graph';

  @override
  bool get isConfigured =>
      (settings.settings[AppConstants.settingOutlookAccessToken] ?? '')
          .trim()
          .isNotEmpty;

  @override
  Future<List<OutlookMail>> collectMails({int top = 20}) async {
    final token = settings.settings[AppConstants.settingOutlookAccessToken] ?? '';
    final folder =
        settings.settings[AppConstants.settingOutlookFolder] ?? 'Inbox';
    if (token.trim().isEmpty) {
      throw Exception('Outlook Access Token이 설정되지 않았습니다.');
    }
    return service.collectMails(accessToken: token, folder: folder, top: top);
  }

  @override
  Future<String?> saveAttachment(OutlookAttachment attachment) {
    return service.saveAttachment(attachment);
  }
}

class TeamsWebhookConnector implements AlertNotifierConnector {
  final SettingsViewModel settings;
  final WebhookService service;

  TeamsWebhookConnector({required this.settings, required this.service});

  @override
  String get key => 'teams-webhook';

  @override
  String get displayName => 'Teams Webhook';

  @override
  bool get isConfigured =>
      (settings.settings[AppConstants.settingTeamsWebhook] ?? '')
          .trim()
          .isNotEmpty;

  String get _webhook {
    final value = settings.settings[AppConstants.settingTeamsWebhook] ?? '';
    if (value.trim().isEmpty) {
      throw Exception('Teams Webhook이 설정되지 않았습니다.');
    }
    return value;
  }

  @override
  Future<void> sendUrgentVoc(VocEntity voc) {
    return service.sendTeamsAlert(
      webhookUrl: _webhook,
      title: '[긴급 VOC] ${voc.title}',
      message: voc.content,
      extra: {
        '고객': voc.customer,
        '프로젝트': voc.project,
        '긴급도': voc.urgency ?? '-',
        '담당부서': voc.department ?? '-',
        '담당자': voc.assignee ?? '-',
      },
    );
  }

  @override
  Future<void> shareVoc(VocEntity voc) {
    return service.sendTeamsAlert(
      webhookUrl: _webhook,
      title: '[VOC 공유] ${voc.title}',
      message: voc.content,
      extra: {
        '고객': voc.customer,
        '카테고리': voc.category,
        '긴급도': voc.urgency ?? '-',
      },
    );
  }

  @override
  Future<void> shareAiAnswer({
    required VocEntity voc,
    required String answer,
  }) {
    return service.sendTeamsAlert(
      webhookUrl: _webhook,
      title: '[AI 답변 공유] ${voc.title}',
      message: answer,
      extra: {
        '고객': voc.customer,
        '카테고리': voc.category,
        '담당자 추천': voc.assignee ?? '-',
      },
    );
  }
}

class SlackWebhookConnector implements AlertNotifierConnector {
  final SettingsViewModel settings;
  final WebhookService service;

  SlackWebhookConnector({required this.settings, required this.service});

  @override
  String get key => 'slack-webhook';

  @override
  String get displayName => 'Slack Webhook';

  @override
  bool get isConfigured =>
      (settings.settings[AppConstants.settingSlackWebhook] ?? '')
          .trim()
          .isNotEmpty;

  String get _webhook {
    final value = settings.settings[AppConstants.settingSlackWebhook] ?? '';
    if (value.trim().isEmpty) {
      throw Exception('Slack Webhook이 설정되지 않았습니다.');
    }
    return value;
  }

  @override
  Future<void> sendUrgentVoc(VocEntity voc) {
    return service.sendSlackMessage(
      webhookUrl: _webhook,
      text: '[긴급 VOC] ${voc.title}\n${voc.content}',
      fields: {
        '고객': voc.customer,
        '프로젝트': voc.project,
        '긴급도': voc.urgency ?? '-',
        '담당부서': voc.department ?? '-',
        '담당자': voc.assignee ?? '-',
      },
    );
  }

  @override
  Future<void> shareVoc(VocEntity voc) {
    return service.sendSlackMessage(
      webhookUrl: _webhook,
      text: '[VOC 공유] ${voc.title}\n${voc.content}',
      fields: {
        '고객': voc.customer,
        '프로젝트': voc.project,
        '카테고리': voc.category,
        '긴급도': voc.urgency ?? '-',
      },
    );
  }

  @override
  Future<void> shareAiAnswer({
    required VocEntity voc,
    required String answer,
  }) {
    return service.sendSlackMessage(
      webhookUrl: _webhook,
      text: '[VOC 공유] ${voc.title}\n\nAI 추천 답변:\n$answer',
      fields: {
        '고객': voc.customer,
        '카테고리': voc.category,
        '긴급도': voc.urgency ?? '-',
        '담당자 추천': voc.assignee ?? '-',
      },
    );
  }
}

class ConfluenceFaqConnector implements KnowledgeBasePublisherConnector {
  final SettingsViewModel settings;

  ConfluenceFaqConnector({required this.settings});

  @override
  String get key => 'confluence-faq';

  @override
  String get displayName => 'Confluence FAQ';

  @override
  bool get isConfigured {
    final url = settings.settings[AppConstants.settingConfluenceUrl] ?? '';
    final space = settings.settings[AppConstants.settingConfluenceSpace] ?? '';
    final email = settings.settings[AppConstants.settingConfluenceEmail] ?? '';
    final token = settings.settings[AppConstants.settingConfluenceToken] ?? '';
    return url.trim().isNotEmpty &&
        space.trim().isNotEmpty &&
        email.trim().isNotEmpty &&
        token.trim().isNotEmpty;
  }

  @override
  Future<String> publishApprovedAnswer({
    required VocEntity voc,
    required String approvedAnswer,
  }) async {
    final url = settings.settings[AppConstants.settingConfluenceUrl] ?? '';
    final space = settings.settings[AppConstants.settingConfluenceSpace] ?? '';
    final email = settings.settings[AppConstants.settingConfluenceEmail] ?? '';
    final token = settings.settings[AppConstants.settingConfluenceToken] ?? '';

    if (url.isEmpty || space.isEmpty || email.isEmpty || token.isEmpty) {
      throw Exception('Confluence 설정이 미완성입니다.');
    }

    final service = ConfluenceService(
      baseUrl: url,
      email: email,
      token: token,
      spaceKey: space,
    );

    return service.createFaqPage(
      title: '[VOC FAQ] ${voc.title}',
      question: voc.content,
      answer: approvedAnswer,
      category: voc.category,
    );
  }
}
