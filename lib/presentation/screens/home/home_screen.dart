import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../chat/ai_chat_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../jira/jira_screen.dart';
import '../knowledge_base/knowledge_base_screen.dart';
import '../privacy/privacy_trust_screen.dart';
import '../settings/settings_screen_ax.dart';
import '../voc/voc_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.screenOverrides})
      : assert(screenOverrides == null || screenOverrides.length == 6);

  /// Allows the responsive shell to be exercised without production I/O.
  final List<Widget>? screenOverrides;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _privacySelection = 99;

  int _selectedIndex = 0;
  final Set<int> _visitedIndexes = {0};

  List<Widget> get _screens =>
      widget.screenOverrides ??
      const [
        DashboardScreen(),
        VocListScreen(),
        AiChatScreen(),
        KnowledgeBaseScreen(),
        JiraScreen(),
        SettingsScreenAx(),
      ];

  static const _destinations = [
    _NavItem(
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      label: '대시보드',
      mobileLabel: '홈',
    ),
    _NavItem(
      icon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox_rounded,
      label: 'VOC 관리',
      mobileLabel: 'VOC',
    ),
    _NavItem(
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      label: 'AI 코파일럿',
      mobileLabel: 'AI',
    ),
    _NavItem(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
      label: '지식베이스',
      mobileLabel: '지식',
    ),
    _NavItem(
      icon: Icons.account_tree_outlined,
      selectedIcon: Icons.account_tree_rounded,
      label: '업무 협업툴',
      mobileLabel: '협업',
    ),
    _NavItem(
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune_rounded,
      label: '설정',
      mobileLabel: '설정',
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
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const PrivacyTrustScreen()));
  }

  Future<void> _openMoreMenu() async {
    final selection = await showModalBottomSheet<int>(
      context: context,
      builder: (context) =>
          _MobileMoreSheet(selectedIndex: _selectedIndex, items: _destinations),
    );
    if (!mounted || selection == null) return;
    if (selection == _privacySelection) {
      _openPrivacyTrust();
      return;
    }
    _selectScreen(selection);
  }

  List<Widget> get _cachedScreens => List<Widget>.generate(
        _screens.length,
        (index) => _visitedIndexes.contains(index)
            ? _screens[index]
            : const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.mobile) {
          return _buildMobileShell();
        }
        return _buildDesktopShell(
          expanded: constraints.maxWidth >= AppBreakpoints.expandedNavigation,
          extraWide: constraints.maxWidth >= AppBreakpoints.wideContent,
        );
      },
    );
  }

  Widget _buildMobileShell() {
    final bottomIndex = _selectedIndex <= 3 ? _selectedIndex : 4;
    return Scaffold(
      key: const Key('app-shell-mobile'),
      backgroundColor: context.visualColors.canvas,
      body: IndexedStack(index: _selectedIndex, children: _cachedScreens),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: NavigationBar(
          key: const Key('app-shell-mobile-nav'),
          selectedIndex: bottomIndex,
          onDestinationSelected: (index) {
            if (index <= 3) {
              _selectScreen(index);
            } else {
              _openMoreMenu();
            }
          },
          destinations: [
            for (var index = 0; index < 4; index++)
              NavigationDestination(
                key: Key('mobile-nav-$index'),
                icon: Icon(_destinations[index].icon),
                selectedIcon: Icon(_destinations[index].selectedIcon),
                label: _destinations[index].mobileLabel,
              ),
            const NavigationDestination(
              key: Key('mobile-nav-more'),
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: '더보기',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopShell({required bool expanded, required bool extraWide}) {
    final colors = Theme.of(context).colorScheme;
    final padding = extraWide ? AppSpacing.lg : AppSpacing.sm;
    return Scaffold(
      key: Key(expanded ? 'app-shell-wide' : 'app-shell-rail'),
      backgroundColor: context.visualColors.canvas,
      body: Row(
        children: [
          _DesktopNavigation(
            expanded: expanded,
            selectedIndex: _selectedIndex,
            items: _destinations,
            onSelect: _selectScreen,
            onPrivacyTap: _openPrivacyTrust,
          ),
          Expanded(
            child: SafeArea(
              left: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  padding,
                  padding,
                  padding,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.visualColors.elevatedSurface,
                    borderRadius: BorderRadius.circular(AppRadii.panel),
                    border: Border.all(color: colors.outlineVariant),
                    boxShadow: Theme.of(context).brightness == Brightness.light
                        ? const [
                            BoxShadow(
                              color: Color(0x0A10131F),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.panel - 1),
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _cachedScreens,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.expanded,
    required this.selectedIndex,
    required this.items,
    required this.onSelect,
    required this.onPrivacyTap,
  });

  final bool expanded;
  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onSelect;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    final visual = context.visualColors;
    final primary = Theme.of(context).colorScheme.primary;
    final width = expanded ? 252.0 : 84.0;

    return Container(
      key: Key(expanded ? 'desktop-nav-expanded' : 'desktop-nav-compact'),
      width: width,
      color: visual.navigation,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            expanded ? 14 : 10,
            16,
            expanded ? 14 : 10,
            14,
          ),
          child: Column(
            crossAxisAlignment:
                expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              _BrandMark(expanded: expanded, onTap: () => onSelect(0)),
              const SizedBox(height: AppSpacing.xl),
              if (expanded) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'WORKSPACE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: visual.navigationMuted,
                          letterSpacing: 1.15,
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xxs),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final selected = selectedIndex == index;
                    final tile = Semantics(
                      selected: selected,
                      button: true,
                      label: item.label,
                      child: Material(
                        key: Key('desktop-nav-$index'),
                        color: selected
                            ? primary.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => onSelect(index),
                          child: SizedBox(
                            height: 48,
                            child: Row(
                              mainAxisAlignment: expanded
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                if (expanded)
                                  const SizedBox(width: AppSpacing.sm),
                                Icon(
                                  selected ? item.selectedIcon : item.icon,
                                  size: 21,
                                  color: selected
                                      ? const Color(0xFFB7B8FF)
                                      : visual.navigationMuted,
                                ),
                                if (expanded) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: selected
                                                ? visual.onNavigation
                                                : visual.navigationMuted,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    return expanded
                        ? tile
                        : Tooltip(message: item.label, child: tile);
                  },
                ),
              ),
              if (expanded)
                _WorkspaceStatus(onPrivacyTap: onPrivacyTap)
              else ...[
                IconButton(
                  key: const Key('desktop-privacy'),
                  onPressed: onPrivacyTap,
                  tooltip: '개인정보 · AI 데이터 보호',
                  color: visual.navigationMuted,
                  icon: const Icon(Icons.shield_outlined),
                ),
                const SizedBox(height: AppSpacing.xs),
                const _StatusDot(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = context.visualColors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.control),
      onTap: onTap,
      child: Row(
        mainAxisAlignment:
            expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppPalette.indigo,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          if (expanded) ...[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI VOC',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: visual.onNavigation,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                  ),
                  Text(
                    'OPERATIONS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: visual.navigationMuted,
                          letterSpacing: 1.1,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceStatus extends StatelessWidget {
  const _WorkspaceStatus({required this.onPrivacyTap});

  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    final visual = context.visualColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const _StatusDot(),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local workspace',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: visual.onNavigation),
                    ),
                    Text(
                      '동기화 준비됨',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: visual.navigationMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              key: const Key('desktop-privacy'),
              onPressed: onPrivacyTap,
              style: TextButton.styleFrom(
                foregroundColor: visual.navigationMuted,
                alignment: Alignment.centerLeft,
              ),
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: const Text('데이터 보호'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: context.visualColors.success,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: context.visualColors.success.withValues(alpha: 0.5),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

class _MobileMoreSheet extends StatelessWidget {
  const _MobileMoreSheet({required this.selectedIndex, required this.items});

  final int selectedIndex;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  child: Icon(
                    Icons.grid_view_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '더보기',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: '닫기',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              key: const Key('more-collaboration'),
              selected: selectedIndex == 4,
              selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
              leading: Icon(items[4].icon),
              title: Text(items[4].label),
              subtitle: const Text('JIRA · Redmine · Notion 연동'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, 4),
            ),
            const SizedBox(height: AppSpacing.xs),
            ListTile(
              key: const Key('more-settings'),
              selected: selectedIndex == 5,
              selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
              leading: Icon(items[5].icon),
              title: Text(items[5].label),
              subtitle: const Text('AI · 동기화 · 화면 설정'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, 5),
            ),
            const SizedBox(height: AppSpacing.xs),
            ListTile(
              key: const Key('more-privacy'),
              leading: const Icon(Icons.shield_outlined),
              title: const Text('개인정보 · AI 데이터 보호'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, 99),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.mobileLabel,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String mobileLabel;
}
