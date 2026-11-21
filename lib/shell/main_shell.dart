import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/widgets/app_logo.dart';
import 'package:counseling_is/features/auth/application/auth_controller.dart';
import 'package:counseling_is/features/auth/presentation/change_password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class NavItem {
  const NavItem(this.route, this.label, this.icon);
  final String route;
  final String label;
  final IconData icon;
}

const kNavItems = [
  NavItem('/dashboard', 'Dashboard', Icons.dashboard_outlined),
  NavItem('/clients', 'Students', Icons.people_outline),
  NavItem('/appointments', 'Appointments', Icons.event_note_outlined),
  NavItem('/calendar', 'Guidance Calendar', Icons.calendar_month_outlined),
  NavItem('/sessions', 'Counseling Sessions', Icons.history_edu_outlined),
  NavItem('/interventions', 'Interventions', Icons.volunteer_activism_outlined),
  NavItem('/forms', 'Student Forms', Icons.description_outlined),
  NavItem('/forms/batch', 'Batch Fill Forms', Icons.layers_outlined),
  NavItem(
    '/forms/child_protection_intake',
    'Child Protection Intake',
    Icons.health_and_safety_outlined,
  ),
  NavItem('/reports', 'Reports', Icons.bar_chart_outlined),
  NavItem('/audit-log', 'Audit Log', Icons.fact_check_outlined),
  NavItem('/users', 'User Management', Icons.manage_accounts_outlined),
  NavItem('/backup', 'Backup and Restore', Icons.save_alt_outlined),
  NavItem('/settings', 'Settings', Icons.settings_outlined),
];

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final FocusNode _focusNode = FocusNode();
  bool? _sidebarExpanded;
  bool _sidebarHeaderHovered = false;

  void _noteActivity() {
    context.read<AuthController>().noteActivity();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final narrow = screenWidth < 900;
    final sidebarExpanded = _sidebarExpanded ?? !narrow;

    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _noteActivity(),
        onPointerUp: (_) => _noteActivity(),
        child: KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (_) => _noteActivity(),
          child: Row(
            children: [
              AnimatedContainer(
                key: const ValueKey('sidebar-width-transition'),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                width: sidebarExpanded
                    ? (screenWidth * .4 < 240 ? screenWidth * .4 : 240)
                    : 72,
                child: LayoutBuilder(
                  builder: (context, constraints) => ClipRect(
                    child: _Sidebar(
                      compact: constraints.maxWidth < 200,
                      headerHovered: _sidebarHeaderHovered,
                      location: location,
                      onHeaderHover: (hovered) =>
                          setState(() => _sidebarHeaderHovered = hovered),
                      onToggleExpanded: () =>
                          setState(() => _sidebarExpanded = !sidebarExpanded),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(color: AppColors.surface, child: widget.child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.compact,
    required this.headerHovered,
    required this.location,
    required this.onHeaderHover,
    required this.onToggleExpanded,
  });

  final bool compact;
  final bool headerHovered;
  final String location;
  final ValueChanged<bool> onHeaderHover;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AuthController>().admin;

    return Container(
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
            child: Row(
              children: [
                MouseRegion(
                  onEnter: (_) => onHeaderHover(true),
                  onExit: (_) => onHeaderHover(false),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: headerHovered
                          ? IconButton(
                              tooltip: compact
                                  ? 'Expand sidebar'
                                  : 'Collapse sidebar',
                              onPressed: onToggleExpanded,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 40,
                                height: 40,
                              ),
                              padding: EdgeInsets.zero,
                              color: Colors.white,
                              icon: Icon(
                                compact
                                    ? Icons.keyboard_double_arrow_right
                                    : Icons.keyboard_double_arrow_left,
                                size: 22,
                              ),
                            )
                          : const AppLogo(size: 36),
                    ),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Counseling IS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
                for (final item in kNavItems)
                  _NavTile(
                    item: item,
                    selected:
                        location == item.route ||
                        (item.route == '/forms' &&
                            location.startsWith('/forms/') &&
                            location != '/forms/child_protection_intake' &&
                            location != '/forms/batch'),
                    compact: compact,
                    onTap: () {
                      context.read<AuthController>().noteActivity();
                      context.go(item.route);
                    },
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          if (!compact && admin != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Text(
                admin.fullName,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          _NavTile(
            item: const NavItem('_lock', 'Lock now', Icons.lock_outline),
            selected: false,
            compact: compact,
            onTap: () => context.read<AuthController>().session.lock(),
          ),
          _NavTile(
            item: const NavItem(
              '_password',
              'Change password',
              Icons.password_outlined,
            ),
            selected: false,
            compact: compact,
            onTap: () => ChangePasswordDialog.show(context),
          ),
          _NavTile(
            item: const NavItem('_logout', 'Logout', Icons.logout),
            selected: false,
            compact: compact,
            onTap: () => _confirmLogout(context),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthController>().logout();
    }
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _HoverNavTile(
      item: item,
      selected: selected,
      compact: compact,
      onTap: onTap,
    );
  }
}

class _HoverNavTile extends StatefulWidget {
  const _HoverNavTile({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_HoverNavTile> createState() => _HoverNavTileState();
}

class _HoverNavTileState extends State<_HoverNavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = selected || _hovered ? Colors.white : Colors.white70;
    final background = selected
        ? AppColors.sidebarSelected
        : _hovered
        ? Colors.white.withValues(alpha: .14)
        : Colors.transparent;

    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        hoverColor: Colors.transparent,
        splashColor: Colors.white.withValues(alpha: .16),
        highlightColor: Colors.white.withValues(alpha: .10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: background,
            border: Border(
              left: BorderSide(
                color: selected
                    ? AppColors.gold
                    : _hovered
                    ? Colors.white70
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(widget.item.icon, color: color, size: 20),
              if (!widget.compact) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    widget.item.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: selected || _hovered
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return widget.compact
        ? Tooltip(message: widget.item.label, child: tile)
        : tile;
  }
}
