import '../../../domain/entities/voc_entity.dart';
import '../outlook_service.dart';

abstract class IntegrationConnector {
  String get key;
  String get displayName;
  bool get isConfigured;
}

abstract class OutlookCollectorConnector extends IntegrationConnector {
  Future<List<OutlookMail>> collectMails({int top = 20});
  Future<String?> saveAttachment(OutlookAttachment attachment);
}

abstract class AlertNotifierConnector extends IntegrationConnector {
  Future<void> sendUrgentVoc(VocEntity voc);
  Future<void> shareVoc(VocEntity voc);
  Future<void> shareAiAnswer({
    required VocEntity voc,
    required String answer,
  });
}

abstract class KnowledgeBasePublisherConnector extends IntegrationConnector {
  Future<String> publishApprovedAnswer({
    required VocEntity voc,
    required String approvedAnswer,
  });
}
