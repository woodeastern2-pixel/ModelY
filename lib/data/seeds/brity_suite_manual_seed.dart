import 'brity_manual_seed.dart';
import 'brity_messenger_manual_seed.dart';
import 'brity_suite_topic_seed.dart';

class BritySuiteManualSeed {
  BritySuiteManualSeed._();

  static final List<Map<String, String>> entries = [
    ...BrityManualSeed.entries.map(
      (entry) => {
        ...entry,
        'sourceName': BrityManualSeed.sourceName,
        'sourceUrl': BrityManualSeed.sourceUrl,
        'platform': 'Web/Mobile',
        'project': BrityManualSeed.project,
      },
    ),
    ...BrityMessengerManualSeed.entries,
    ...BritySuiteTopicSeed.entries,
  ];

  static Set<String> get projects =>
      entries.map((entry) => entry['project']!).toSet();
}
