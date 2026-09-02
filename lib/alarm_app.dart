import 'package:flutter/material.dart';

enum AlarmType { sound, vibration, flash }

class AlarmItem {
  const AlarmItem({
    required this.id,
    required this.hour,
    required this.minute,
    required this.label,
    required this.enabled,
    required this.repeatDays,
    required this.type,
    required this.soundIndex,
    required this.vibrationIndex,
    required this.snoozeMinutes,
    required this.fadeIn,
  });

  final String id;
  final int hour;
  final int minute;
  final String label;
  final bool enabled;
  final Set<int> repeatDays;
  final AlarmType type;
  final int soundIndex;
  final int vibrationIndex;
  final int snoozeMinutes;
  final bool fadeIn;

  AlarmItem copyWith({
    int? hour,
    int? minute,
    String? label,
    bool? enabled,
    Set<int>? repeatDays,
    AlarmType? type,
    int? soundIndex,
    int? vibrationIndex,
    int? snoozeMinutes,
    bool? fadeIn,
  }) {
    return AlarmItem(
      id: id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      repeatDays: repeatDays ?? this.repeatDays,
      type: type ?? this.type,
      soundIndex: soundIndex ?? this.soundIndex,
      vibrationIndex: vibrationIndex ?? this.vibrationIndex,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      fadeIn: fadeIn ?? this.fadeIn,
    );
  }
}

class AlarmController extends ChangeNotifier {
  final List<AlarmItem> _alarms = [
    const AlarmItem(
      id: 'wake',
      hour: 7,
      minute: 30,
      label: '기상',
      enabled: true,
      repeatDays: {1, 2, 3, 4, 5},
      type: AlarmType.sound,
      soundIndex: 0,
      vibrationIndex: 2,
      snoozeMinutes: 5,
      fadeIn: true,
    ),
    const AlarmItem(
      id: 'stretch',
      hour: 9,
      minute: 0,
      label: '스트레칭',
      enabled: true,
      repeatDays: {1, 2, 3, 4, 5},
      type: AlarmType.vibration,
      soundIndex: 1,
      vibrationIndex: 5,
      snoozeMinutes: 10,
      fadeIn: false,
    ),
    const AlarmItem(
      id: 'water',
      hour: 14,
      minute: 20,
      label: '물 마시기',
      enabled: false,
      repeatDays: {},
      type: AlarmType.flash,
      soundIndex: 3,
      vibrationIndex: 0,
      snoozeMinutes: 5,
      fadeIn: false,
    ),
  ];

  ThemeMode themeMode = ThemeMode.system;
  String language = '한국어';
  bool use24Hour = true;
  bool flashEnabled = true;
  bool fadeInDefault = true;
  int defaultSnooze = 5;

  List<AlarmItem> get alarms {
    final list = [..._alarms];
    list.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    return list;
  }

  AlarmItem? get nextAlarm {
    final list = _alarms.where((e) => e.enabled).toList();
    if (list.isEmpty) return null;
    final now = DateTime.now();
    int distance(AlarmItem a) {
      final nowMinutes = now.hour * 60 + now.minute;
      final alarmMinutes = a.hour * 60 + a.minute;
      return (alarmMinutes - nowMinutes + 1440) % 1440;
    }
    list.sort((a, b) => distance(a).compareTo(distance(b)));
    return list.first;
  }

  void add(AlarmItem alarm) {
    _alarms.add(alarm);
    notifyListeners();
  }

  void update(AlarmItem alarm) {
    final index = _alarms.indexWhere((e) => e.id == alarm.id);
    if (index >= 0) _alarms[index] = alarm;
    notifyListeners();
  }

  void delete(String id) {
    _alarms.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void toggle(String id, bool enabled) {
    final index = _alarms.indexWhere((e) => e.id == id);
    if (index >= 0) _alarms[index] = _alarms[index].copyWith(enabled: enabled);
    notifyListeners();
  }
}

class AlarmApp extends StatefulWidget {
  const AlarmApp({super.key});

  @override
  State<AlarmApp> createState() => _AlarmAppState();
}

class _AlarmAppState extends State<AlarmApp> {
  final controller = AlarmController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3976FF),
      brightness: brightness,
      surface: dark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FC),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: dark ? const Color(0xFF080D19) : const Color(0xFFF5F7FB),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF11182A) : Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: dark ? const Color(0xFF0D1424) : Colors.white,
        indicatorColor: scheme.primary.withValues(alpha: .14),
        height: 72,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF151E32) : const Color(0xFFF0F3F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => MaterialApp(
        title: 'Alarm',
        debugShowCheckedModeBanner: false,
        themeMode: controller.themeMode,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        home: AlarmShell(controller: controller),
      ),
    );
  }
}

class AlarmShell extends StatefulWidget {
  const AlarmShell({super.key, required this.controller});
  final AlarmController controller;

  @override
  State<AlarmShell> createState() => _AlarmShellState();
}

class _AlarmShellState extends State<AlarmShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (_, __) => Scaffold(
        body: IndexedStack(
          index: tab,
          children: [
            HomeScreen(controller: widget.controller),
            SettingsScreen(controller: widget.controller),
          ],
        ),
        floatingActionButton: tab == 0
            ? FloatingActionButton.extended(
                onPressed: () => openEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('알람 추가'),
              )
            : null,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tab == 0) const AdPlaceholder(),
            NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (value) => setState(() => tab = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.alarm_outlined),
                  selectedIcon: Icon(Icons.alarm_rounded),
                  label: '홈',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune_rounded),
                  label: '설정',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> openEditor(BuildContext context, [AlarmItem? current]) async {
    final result = await showModalBottomSheet<AlarmItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlarmEditorSheet(
        current: current,
        defaultSnooze: widget.controller.defaultSnooze,
        defaultFadeIn: widget.controller.fadeInDefault,
      ),
    );
    if (result == null) return;
    current == null ? widget.controller.add(result) : widget.controller.update(result);
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});
  final AlarmController controller;

  @override
  Widget build(BuildContext context) {
    final alarms = controller.alarms;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          Text(
            'ALARM',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.8,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            '좋은 아침입니다.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          NextAlarmCard(alarm: controller.nextAlarm),
          const SizedBox(height: 28),
          Row(
            children: [
              Text('내 알람', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('${alarms.length}개'),
            ],
          ),
          const SizedBox(height: 12),
          ...alarms.map((alarm) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AlarmCard(
                  alarm: alarm,
                  use24Hour: controller.use24Hour,
                  onToggle: (value) => controller.toggle(alarm.id, value),
                  onDelete: () => controller.delete(alarm.id),
                  onTap: () async {
                    final result = await showModalBottomSheet<AlarmItem>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => AlarmEditorSheet(
                        current: alarm,
                        defaultSnooze: controller.defaultSnooze,
                        defaultFadeIn: controller.fadeInDefault,
                      ),
                    );
                    if (result != null) controller.update(result);
                  },
                ),
              )),
        ],
      ),
    );
  }
}

class NextAlarmCard extends StatelessWidget {
  const NextAlarmCard({super.key, required this.alarm});
  final AlarmItem? alarm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4EFF), Color(0xFF7A3CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: alarm == null
          ? const Text('예정된 알람이 없습니다.', style: TextStyle(color: Colors.white, fontSize: 18))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NEXT ALARM', style: TextStyle(color: Color(0xFFCCD7FF), fontWeight: FontWeight.w900, letterSpacing: 2.3)),
                const SizedBox(height: 12),
                Text(
                  '${alarm!.hour.toString().padLeft(2, '0')}:${alarm!.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white, fontSize: 52, height: 1, fontWeight: FontWeight.w900, letterSpacing: -2.2),
                ),
                const SizedBox(height: 13),
                Text(alarm!.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
    );
  }
}

class AlarmCard extends StatelessWidget {
  const AlarmCard({
    super.key,
    required this.alarm,
    required this.use24Hour,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  final AlarmItem alarm;
  final bool use24Hour;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String timeText() {
    if (use24Hour) return '${alarm.hour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}';
    final h = alarm.hour % 12 == 0 ? 12 : alarm.hour % 12;
    return '${alarm.hour < 12 ? '오전' : '오후'} $h:${alarm.minute.toString().padLeft(2, '0')}';
  }

  String typeText() => switch (alarm.type) {
        AlarmType.sound => '소리',
        AlarmType.vibration => '진동',
        AlarmType.flash => '플래시',
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
          child: Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: alarm.enabled ? 1 : .45,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(timeText(), style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.4)),
                      const SizedBox(height: 4),
                      Text(alarm.label.isEmpty ? '알람' : alarm.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        children: [
                          BadgeText(text: alarm.repeatDays.isEmpty ? '한 번' : '반복'),
                          BadgeText(text: typeText()),
                          if (alarm.fadeIn) const BadgeText(text: '페이드 인'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                children: [
                  Switch(value: alarm.enabled, onChanged: onToggle),
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded), tooltip: '삭제'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BadgeText extends StatelessWidget {
  const BadgeText({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800)),
    );
  }
}

class AlarmEditorSheet extends StatefulWidget {
  const AlarmEditorSheet({
    super.key,
    this.current,
    required this.defaultSnooze,
    required this.defaultFadeIn,
  });

  final AlarmItem? current;
  final int defaultSnooze;
  final bool defaultFadeIn;

  @override
  State<AlarmEditorSheet> createState() => _AlarmEditorSheetState();
}

class _AlarmEditorSheetState extends State<AlarmEditorSheet> {
  late int hour;
  late int minute;
  late TextEditingController label;
  late Set<int> repeatDays;
  late AlarmType type;
  late int soundIndex;
  late int vibrationIndex;
  late int snooze;
  late bool fadeIn;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    final soon = DateTime.now().add(const Duration(minutes: 5));
    hour = current?.hour ?? soon.hour;
    minute = current?.minute ?? soon.minute;
    label = TextEditingController(text: current?.label ?? '');
    repeatDays = {...?current?.repeatDays};
    type = current?.type ?? AlarmType.sound;
    soundIndex = current?.soundIndex ?? 0;
    vibrationIndex = current?.vibrationIndex ?? 0;
    snooze = current?.snoozeMinutes ?? widget.defaultSnooze;
    fadeIn = current?.fadeIn ?? widget.defaultFadeIn;
  }

  @override
  void dispose() {
    label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      height: MediaQuery.sizeOf(context).height * .93,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + keyboard),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(width: 42, height: 5, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              Expanded(child: Text(widget.current == null ? '새 알람' : '알람 편집', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              TextButton(onPressed: save, child: const Text('저장')),
            ],
          ),
          Expanded(
            child: ListView(
              children: [
                TimePickerWheels(
                  hour: hour,
                  minute: minute,
                  onChanged: (h, m) => setState(() {
                    hour = h;
                    minute = m;
                  }),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: '알람 이름', hintText: '예: 기상, 약 먹기', prefixIcon: Icon(Icons.edit_outlined)),
                ),
                const SizedBox(height: 18),
                const SectionTitle('반복'),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    const names = ['월', '화', '수', '목', '금', '토', '일'];
                    return ChoiceChip(
                      label: Text(names[i]),
                      selected: repeatDays.contains(day),
                      onSelected: (_) => setState(() => repeatDays.contains(day) ? repeatDays.remove(day) : repeatDays.add(day)),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                const SectionTitle('알람 방식'),
                const SizedBox(height: 9),
                SegmentedButton<AlarmType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: AlarmType.sound, icon: Icon(Icons.volume_up_outlined), label: Text('소리')),
                    ButtonSegment(value: AlarmType.vibration, icon: Icon(Icons.vibration_rounded), label: Text('진동')),
                    ButtonSegment(value: AlarmType.flash, icon: Icon(Icons.light_mode_outlined), label: Text('플래시')),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) => setState(() => type = value.first),
                ),
                const SizedBox(height: 12),
                if (type == AlarmType.sound)
                  DropdownButtonFormField<int>(
                    value: soundIndex,
                    decoration: const InputDecoration(labelText: '알람 소리 · 10종', prefixIcon: Icon(Icons.music_note_rounded)),
                    items: List.generate(10, (i) => DropdownMenuItem(value: i, child: Text('Sound ${i + 1}'))),
                    onChanged: (value) => setState(() => soundIndex = value ?? 0),
                  ),
                if (type == AlarmType.vibration)
                  DropdownButtonFormField<int>(
                    value: vibrationIndex,
                    decoration: const InputDecoration(labelText: '진동 패턴 · 10종', prefixIcon: Icon(Icons.vibration_rounded)),
                    items: List.generate(10, (i) => DropdownMenuItem(value: i, child: Text('Vibration ${i + 1}'))),
                    onChanged: (value) => setState(() => vibrationIndex = value ?? 0),
                  ),
                if (type == AlarmType.flash)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('소리와 진동 없이 화면 전체가 밝게 점멸합니다.'),
                  ),
                const SizedBox(height: 18),
                const SectionTitle('다시 알림'),
                const SizedBox(height: 9),
                DropdownButtonFormField<int>(
                  value: snooze,
                  items: const [5, 10, 15, 20, 30].map((e) => DropdownMenuItem(value: e, child: Text('$e분'))).toList(),
                  onChanged: (value) => setState(() => snooze = value ?? 5),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('페이드 인'),
                  subtitle: const Text('소리와 화면 밝기를 서서히 높입니다.'),
                  value: fadeIn,
                  onChanged: (value) => setState(() => fadeIn = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void save() {
    final current = widget.current;
    Navigator.pop(
      context,
      AlarmItem(
        id: current?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        hour: hour,
        minute: minute,
        label: label.text.trim(),
        enabled: current?.enabled ?? true,
        repeatDays: repeatDays,
        type: type,
        soundIndex: soundIndex,
        vibrationIndex: vibrationIndex,
        snoozeMinutes: snooze,
        fadeIn: fadeIn,
      ),
    );
  }
}

class TimePickerWheels extends StatefulWidget {
  const TimePickerWheels({super.key, required this.hour, required this.minute, required this.onChanged});
  final int hour;
  final int minute;
  final void Function(int hour, int minute) onChanged;

  @override
  State<TimePickerWheels> createState() => _TimePickerWheelsState();
}

class _TimePickerWheelsState extends State<TimePickerWheels> {
  late int hour;
  late int minute;
  late FixedExtentScrollController hourController;
  late FixedExtentScrollController minuteController;

  @override
  void initState() {
    super.initState();
    hour = widget.hour;
    minute = widget.minute;
    hourController = FixedExtentScrollController(initialItem: 24 * 500 + hour);
    minuteController = FixedExtentScrollController(initialItem: 60 * 500 + minute);
  }

  @override
  void dispose() {
    hourController.dispose();
    minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TimeWheel(
              label: '시',
              modulo: 24,
              controller: hourController,
              onSelected: (value) {
                setState(() => hour = value);
                widget.onChanged(hour, minute);
              },
              onEdit: () => directEdit(true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 34),
              child: Text(':', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
            ),
            TimeWheel(
              label: '분',
              modulo: 60,
              controller: minuteController,
              onSelected: (value) {
                setState(() => minute = value);
                widget.onChanged(hour, minute);
              },
              onEdit: () => directEdit(false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> directEdit(bool isHour) async {
    final current = isHour ? hour : minute;
    final max = isHour ? 23 : 59;
    final text = TextEditingController(text: current.toString().padLeft(2, '0'));
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isHour ? '시 직접 입력' : '분 직접 입력'),
        content: TextField(controller: text, autofocus: true, keyboardType: TextInputType.number, maxLength: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(text.text);
              if (value != null && value >= 0 && value <= max) Navigator.pop(dialogContext, value);
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
    text.dispose();
    if (result == null) return;
    final controller = isHour ? hourController : minuteController;
    final modulo = isHour ? 24 : 60;
    final currentIndex = controller.selectedItem;
    await controller.animateToItem(
      currentIndex - (currentIndex % modulo) + result,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }
}

class TimeWheel extends StatelessWidget {
  const TimeWheel({
    super.key,
    required this.label,
    required this.modulo,
    required this.controller,
    required this.onSelected,
    required this.onEdit,
  });

  final String label;
  final int modulo;
  final FixedExtentScrollController controller;
  final ValueChanged<int> onSelected;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: Column(
        children: [
          IconButton(onPressed: () => move(-1), icon: const Icon(Icons.keyboard_arrow_up_rounded), tooltip: '$label 올리기'),
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ListWheelScrollView.useDelegate(
                  controller: controller,
                  itemExtent: 52,
                  physics: const FixedExtentScrollPhysics(),
                  diameterRatio: 1.45,
                  onSelectedItemChanged: (index) => onSelected(index % modulo),
                  childDelegate: ListWheelChildLoopingListDelegate(
                    children: List.generate(
                      modulo,
                      (i) => Center(child: Text(i.toString().padLeft(2, '0'), style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900))),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: .20)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: () => move(1), icon: const Icon(Icons.keyboard_arrow_down_rounded), tooltip: '$label 내리기'),
          TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_rounded, size: 16), label: Text('$label 직접 입력')),
        ],
      ),
    );
  }

  void move(int delta) {
    controller.animateToItem(controller.selectedItem + delta, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final AlarmController controller;
  static const languages = ['한국어', 'English', '日本語', '中文', 'Français'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
        children: [
          Text('설정', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('알람 동작과 화면을 내 방식대로 맞춥니다.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: controller.language,
                    decoration: const InputDecoration(labelText: '언어', prefixIcon: Icon(Icons.language_rounded)),
                    items: languages.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        controller.language = value;
                        controller.notifyListeners();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const SectionTitle('테마'),
                  const SizedBox(height: 9),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('시스템')),
                      ButtonSegment(value: ThemeMode.light, label: Text('밝게')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('어둡게')),
                    ],
                    selected: {controller.themeMode},
                    onSelectionChanged: (value) {
                      controller.themeMode = value.first;
                      controller.notifyListeners();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('24시간 형식'),
                    subtitle: const Text('끄면 오전/오후 형식으로 표시합니다.'),
                    value: controller.use24Hour,
                    onChanged: (value) {
                      controller.use24Hour = value;
                      controller.notifyListeners();
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('기본 다시 알림'),
                    subtitle: Text('${controller.defaultSnooze}분'),
                    trailing: DropdownButton<int>(
                      value: controller.defaultSnooze,
                      items: const [5, 10, 15, 20, 30].map((e) => DropdownMenuItem(value: e, child: Text('$e분'))).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          controller.defaultSnooze = value;
                          controller.notifyListeners();
                        }
                      },
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('무음 플래시 허용'),
                    subtitle: const Text('화면 전체 점멸 알람을 사용할 수 있습니다.'),
                    value: controller.flashEnabled,
                    onChanged: (value) {
                      controller.flashEnabled = value;
                      controller.notifyListeners();
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('페이드 인 기본 사용'),
                    value: controller.fadeInDefault,
                    onChanged: (value) {
                      controller.fadeInDefault = value;
                      controller.notifyListeners();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.security_rounded),
                  title: Text('개인정보처리방침'),
                  subtitle: Text('공개 GitHub URL로 제공 예정'),
                  trailing: Icon(Icons.chevron_right_rounded),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.ads_click_rounded),
                  title: Text('광고'),
                  subtitle: Text('홈 배너 + 종료 전 전면 광고 구조 준비'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
    );
  }
}

class AdPlaceholder extends StatelessWidget {
  const AdPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Text('AD · 배너 광고 영역', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}
