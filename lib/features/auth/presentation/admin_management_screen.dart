import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/validation/validators.dart' as validators;
import 'package:counseling_is/core/widgets/app_data_table.dart';
import 'package:counseling_is/core/widgets/list_states.dart';
import 'package:counseling_is/core/widgets/status_chip.dart';
import 'package:counseling_is/features/auth/application/auth_controller.dart';
import 'package:counseling_is/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  late Future<List<AdminAccount>> _future;
  String? _error;
  bool _saving = false;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AdminAccount>> _load() =>
      context.read<AuthController>().listManagedAdmins();

  void _refresh() => setState(() => _future = _load());

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  Future<void> _addAccount() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _AdminAccountFormDialog(),
    );
    if (saved == true && mounted) {
      _refresh();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Administrator added.')));
    }
  }

  Future<void> _setActive(AdminAccount account, bool active) async {
    if (!active && account.id == context.read<AuthController>().admin?.id) {
      return;
    }
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Deactivate account?'),
          content: Text(
            '“${account.fullName}” will no longer be able to sign in. '
            'Existing records and audit history will be preserved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final message = await context.read<AuthController>().setManagedAdminActive(
      adminId: account.id,
      isActive: active,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
      if (message == null) _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentId = context.watch<AuthController>().admin?.id;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All accounts have the same administrator permissions.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _addAccount,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add account'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            MaterialBanner(
              content: Text(_error!),
              leading: const Icon(Icons.error_outline),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: FutureBuilder<List<AdminAccount>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return LoadErrorState(onRetry: _refresh);
                }
                final accounts = snapshot.data!;
                if (accounts.isEmpty) {
                  return const EmptyListState(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'No administrator accounts',
                    message: 'Create an administrator account to continue.',
                  );
                }
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: AppDataTable(
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Username')),
                      DataColumn(label: Text('Access')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: [
                      for (final account in accounts)
                        DataRow(
                          key: ValueKey(account.id),
                          cells: [
                            DataCell(Text(account.fullName)),
                            DataCell(Text(account.username)),
                            const DataCell(Text('Administrator')),
                            DataCell(
                              StatusChip(
                                label: account.isActive ? 'Active' : 'Inactive',
                                color: account.isActive
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFF616161),
                              ),
                            ),
                            DataCell(
                              TextButton(
                                onPressed:
                                    _saving ||
                                        (account.id == currentId &&
                                            account.isActive)
                                    ? null
                                    : () => _setActive(
                                        account,
                                        !account.isActive,
                                      ),
                                child: Text(
                                  account.isActive
                                      ? 'Deactivate'
                                      : 'Reactivate',
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAccountFormDialog extends StatefulWidget {
  const _AdminAccountFormDialog();

  @override
  State<_AdminAccountFormDialog> createState() =>
      _AdminAccountFormDialogState();
}

class _AdminAccountFormDialogState extends State<_AdminAccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await context.read<AuthController>().createManagedAdmin(
      username: _username.text,
      fullName: _name.text,
      password: _password.text,
      confirmPassword: _confirm.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add administrator'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Full name is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _username,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: validators.username,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _password,
                  enabled: !_saving,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: validators.passwordStrength,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _confirm,
                  enabled: !_saving,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                  validator: (value) =>
                      value != _password.text ? 'Passwords do not match' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create account'),
        ),
      ],
    );
  }
}
