import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../chat/ai_chat_screen.dart';
import '../voc/voc_list_screen.dart';
import '../knowledge_base/knowledge_base_screen.dart';
import '../jira/jira_screen.dart';
import '../settings/settings_screen_ax.dart';
import '../privacy/privacy_trust_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final Set<int> _visitedIndexes = {0};

  final _screens = const [
    DashboardScreen(),
    VocListScreen(),
    AiChatScreen(),
    KnowledgeBaseScreen(),
    JiraScreen(),
    SettingsScreenAx(),
  ];

  final _destinations = const [
    _NavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: '대시보드',
      hint: 'KPI / 추이 / 운영 인사이트',
    ),
    _NavItem(
      icon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox,
      label: 'VOC 관리',
      hint: '등록 / 검색 / 처리흐름',
    ),
    _NavItem(
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      label: 'AI Chat',
      hint: 'AI 질의 / 답변 초안 생성',
    ),
    _NavItem(
      icon: Icons.book_outlined,
      selectedIcon: Icons.book,
      label: '지식베이스',
      hint: '매뉴얼 / FAQ / 문서자산',
    ),
    _NavItem(
      icon: Icons.link_outlined,
      selectedIcon: Icons.link,
      label: '업무 협업툴',
      hint: 'JIRA/Redmine/Notion 연동',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: '설정',
      hint: '시스템 / 동기화 / 운영옵션',
    ),
  ];

  void _selectScreen(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _visitedIndexes.add(index);
    });
  }

  void _openPrivacyTrust() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyTrustScreen()),
    );
  }

  List<Widget> get _cachedScreens => List<Widget>.generate(
        _screens.length,
        (index) => _visitedIndexes.contains(index)
            ? _screens[index]
            : const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 1100;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isWide) {
      final sideNavWidth = screenWidth >= 1800
          ? 312.0
          : screenWidth >= 1500
              ? 292.0
              : 268.0;
      final shellPadding = screenWidth >= 1800
          ? const EdgeInsets.fromLTRB(18, 16, 18, 16)
          : screenWidth >= 1500
              ? const EdgeInsets.fromLTRB(16, 14, 16, 14)
              : const EdgeInsets.fromLTRB(14, 12, 16, 12);
      final topGap = screenWidth >= 1500 ? 16.0 : 10.0;
      final shellBorderColor = Theme.of(context)
          .colorScheme
          .outline
          .withValues(alpha: isDark ? 0.38 : 0.28);
      final shellShadow = isDark
          ? const [
              BoxShadow(
                color: Color(0x2A000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ]
          : const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ];

      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF0A1220),
                      Color(0xFF0B1424),
                      Color(0xFF0D1A28),
                    ]
                  : const [
                      Color(0xFFF3F8FF),
                      Color(0xFFF7FAFD),
                      Color(0xFFF2FBF9),
                    ],
            ),
          ),
          child: Row(
            children: [
              _DesktopSideNav(
                width: sideNavWidth,
                items: _destinations,
                selectedIndex: _selectedIndex,
                onSelect: _selectScreen,
              ),
              Expanded(
                child: Padding(
                  padding: shellPadding,
                  child: Column(
                    children: [
                      _DesktopTopBar(
                        currentLabel: _destinations[_selectedIndex].label,
                        currentHint: _destinations[_selectedIndex].hint,
                        compact: screenWidth < 1320,
                        onPrivacyTap: _openPrivacyTrust,
                      ),
                      SizedBox(height: topGap),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: shellBorderColor),
                            boxShadow: shellShadow,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: _cachedScreens,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI VOC Assistant'),
        actions: [
          IconButton(
            onPressed: _openPrivacyTrust,
            tooltip: '개인정보 · AI 데이터 보호',
            icon: const Icon(Icons.verified_user_outlined),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _cachedScreens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectScreen,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '대시보드',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'VOC',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: '지식베이스',
          ),
          NavigationDestination(
            icon: Icon(Icons.link_outlined),
            selectedIcon: Icon(Icons.link),
            label: '협업툴',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  final String currentLabel;
  final String currentHint;
  final bool compact;
  final VoidCallback onPrivacyTap;

  const _DesktopTopBar({
    required this.currentLabel,
    required this.currentHint,
    required this.compact,
    required this.onPrivacyTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final period = now.hour < 12 ? 'AM' : 'PM';
    final hh = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final mm = now.minute.toString().padLeft(2, '0');
    final stamp = '$period $hh:$mm';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: compact ? 74 : 84,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 22,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHigh
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.26),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currentLabel,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        fontSize: compact ? 20 : null,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.9),
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onPrivacyTap,
            tooltip: '개인정보 · AI 데이터 보호',
            icon: const Icon(Icons.verified_user_outlined),
          ),
          const SizedBox(width: 4),
          if (!compact) ...[
            const _TopPill(
              icon: Icons.sync_outlined,
              label: 'In-App Sync',
              tone: Color(0xFF0E9F6E),
            ),
            const SizedBox(width: 10),
          ],
          _TopPill(
            icon: Icons.schedule,
            label: compact ? '최근 동기화 $stamp' : stamp,
            tone: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tone;

  const _TopPill({
    required this.icon,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSideNav extends StatelessWidget {
  final double width;
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _DesktopSideNav({
    required this.width,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF0B253D),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF0EA5A5)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () => onSelect(0),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI VOC Assistant',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Enterprise Console',
                                  style: TextStyle(
                                    color: Color(0xFFDBEAFE),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'WORKSPACE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF93C5FD),
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final selected = i == selectedIndex;
                    final iconColor = selected
                        ? const Color(0xFFDBEAFE)
                        : const Color(0xFFBFDBFE);
                    return Material(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onSelect(i),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Row(
                            children: [
                              Icon(
                                selected ? item.selectedIcon : item.icon,
                                color: iconColor,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFFE2E8F0),
                                    fontSize: 13.5,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String hint;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.hint,
  });
}
