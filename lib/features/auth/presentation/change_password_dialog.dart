import 'package:counseling_is/core/validation/validators.dart' as validators;
import 'package:counseling_is/core/widgets/app_field.dart';
import 'package:counseling_is/core/widgets/error_banner.dart';
import 'package:counseling_is/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    final error = await auth.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
      confirmPassword: _confirmController.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Password updated')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 16),
              ],
              AppField(
                label: 'Current password',
                child: TextFormField(
                  controller: _currentController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter current password',
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Current password is required'
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              AppField(
                label: 'New password',
                child: TextFormField(
                  controller: _newController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Create a new password',
                    helperText: '10+ chars: upper, lower, digit',
                  ),
                  validator: validators.passwordStrength,
                ),
              ),
              const SizedBox(height: 16),
              AppField(
                label: 'Confirm new password',
                child: TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Re-enter new password',
                  ),
                  validator: (v) => v != _newController.text
                      ? 'Passwords do not match'
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update password'),
        ),
      ],
    );
  }
}
