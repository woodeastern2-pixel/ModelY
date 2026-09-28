import 'package:ai_voc_assistant/presentation/viewmodels/integration_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('receiver lifecycle events never create VOC notifications', () {
    final text = IntegrationViewModel.notificationTextForEvent(
      _event(type: 'receiver.start', status: 'running'),
      ownAppName: '본사 VOC',
    );

    expect(text, isNull);
  });

  test('events without a real peer source never create notifications', () {
    final text = IntegrationViewModel.notificationTextForEvent(
      _event(type: 'voc.created', status: 'created'),
      ownAppName: '본사 VOC',
    );

    expect(text, isNull);
  });

  test('events originating from the same app are ignored', () {
    final text = IntegrationViewModel.notificationTextForEvent(
      _event(
        type: 'voc.created',
        status: 'created',
        source: '본사 VOC',
      ),
      ownAppName: '본사 VOC',
    );

    expect(text, isNull);
  });

  test('a created VOC from a real peer produces one notification', () {
    final text = IntegrationViewModel.notificationTextForEvent(
      _event(
        type: 'voc.created',
        status: 'created',
        source: '지점 VOC',
      ),
      ownAppName: '본사 VOC',
    );

    expect(text, '지점 VOC에서 단건 VOC 동기화 수신');
  });

  test('an applied full sync reports received counts', () {
    final text = IntegrationViewModel.notificationTextForEvent(
      _event(
        type: 'sync.full',
        status: 'applied',
        source: '지점 VOC',
        counts: const {'vocs': 4, 'manuals': 12},
      ),
      ownAppName: '본사 VOC',
    );

    expect(text, '지점 VOC에서 전체 동기화 수신 (VOC 4건, 매뉴얼 12건)');
  });
}

InboundSyncEvent _event({
  required String type,
  required String status,
  String? source,
  Map<String, int> counts = const {},
}) {
  return InboundSyncEvent(
    seq: 1,
    eventType: type,
    sourceApp: source,
    status: status,
    message: null,
    counts: counts,
    createdAt: DateTime(2026, 9, 21),
  );
}
