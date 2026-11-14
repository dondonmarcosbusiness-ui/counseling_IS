import 'package:counseling_is/core/database/migrations.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/features/auth/application/auth_controller.dart';
import 'package:counseling_is/features/settings/data/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Application preferences (auto-lock timeout) and about information.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _presets = [5, 10, 15, 30, 60];

  int _minutes = SettingsRepository.idleTimeoutDefault;
  bool _loaded = false;
  String? _confirmation;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final minutes =
        await context.read<SettingsRepository>().getIdleTimeoutMinutes();
    if (!mounted) return;
    setState(() {
      _minutes = minutes;
      _loaded = true;
    });
  }

  Future<void> _changed(int? value) async {
    if (value == null || value == _minutes) return;
    setState(() {
      _minutes = value;
      _confirmation = null;
    });
    final auth = context.read<AuthController>();
    await context
        .read<SettingsRepository>()
        .setIdleTimeoutMinutes(value);
    auth.session.updateTimeout(Duration(minutes: value));
    if (!mounted) return;
    setState(() => _confirmation = 'Auto-lock set to $value minutes.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dbPath = context.watch<String>();
    final items = <int>{..._presets, _minutes}.toList()..sort();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Application preferences and information.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lock_clock_outlined,
                                    color: scheme.primary),
                                const SizedBox(width: AppSpacing.sm),
                                Text('Auto-lock',
                                    style:
                                        Theme.of(context).textTheme.titleMedium),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Lock the application after this much time '
                              'without activity. Locked sessions require '
                              'the password to unlock.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: 240,
                              child: AppDropdownFormField<int>(
                                initialValue: _loaded ? _minutes : null,
                                isExpanded: true,
                                menuMaxHeight:
                                    AppDropdownDefaults.menuMaxHeight,
                                decoration: const InputDecoration(
                                  labelText: 'Lock after inactivity',
                                ),
                                items: [
                                  for (final minutes in items)
                                    DropdownMenuItem(
                                      value: minutes,
                                      child: Text('$minutes minutes'),
                                    ),
                                ],
                                onChanged: _loaded ? _changed : null,
                              ),
                            ),
                            if (_confirmation != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      size: 18,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        _confirmation!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onPrimaryContainer,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: scheme.primary),
                                const SizedBox(width: AppSpacing.sm),
                                Text('About',
                                    style:
                                        Theme.of(context).textTheme.titleMedium),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _AboutRow(
                              label: 'Application',
                              value: 'Counseling IS',
                            ),
                            _AboutRow(
                              label: 'Database schema',
                              value: 'Version $schemaVersion',
                            ),
                            _AboutRow(
                              label: 'Database file',
                              value: dbPath.isEmpty
                                  ? 'Not available'
                                  : dbPath,
                              mono: true,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'All data is stored locally on this computer. '
                              'Backups are not encrypted — store them '
                              'securely.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final valueStyle = mono
        ? Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(fontFamily: 'monospace')
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Tooltip(
              message: value,
              child: Text(
                value,
                style: valueStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
