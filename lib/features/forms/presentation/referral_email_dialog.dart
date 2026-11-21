import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/features/forms/domain/referral_recipients.dart';
import 'package:counseling_is/features/settings/data/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lets the counselor choose who a referral goes to (principal, police,
/// DSWD / LGU, ...) and opens a ready-to-send e-mail in the default mail app.
/// Addresses are remembered, so each only has to be typed once.
class ReferralEmailDialog extends StatefulWidget {
  const ReferralEmailDialog({
    super.key,
    required this.subject,
    required this.body,
  });

  final String subject;
  final String body;

  @override
  State<ReferralEmailDialog> createState() => _ReferralEmailDialogState();
}

class _ReferralEmailDialogState extends State<ReferralEmailDialog> {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static const _maxBodyLength = 1500;

  final _email = TextEditingController();
  Map<String, String> _saved = {};
  String _recipientId = referralRecipients.first.id;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    try {
      final saved = await context.read<SettingsRepository>().getReferralEmails();
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _email.text = _saved[_recipientId] ?? '';
      });
    } catch (_) {
      // Addresses can still be typed in by hand.
    }
  }

  void _selectRecipient(String? id) {
    if (id == null) return;
    setState(() {
      _recipientId = id;
      _email.text = _saved[id] ?? '';
      _error = null;
    });
  }

  Future<void> _send() async {
    final address = _email.text.trim();
    if (!_emailPattern.hasMatch(address)) {
      setState(() => _error = 'Enter a valid e-mail address.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      try {
        await context.read<SettingsRepository>().setReferralEmail(
          _recipientId,
          address,
        );
      } catch (_) {
        // Not being able to remember the address must not block sending.
      }
      final body = widget.body.length > _maxBodyLength
          ? '${widget.body.substring(0, _maxBodyLength)}…'
          : widget.body;
      final uri = Uri(
        scheme: 'mailto',
        path: address,
        query:
            'subject=${Uri.encodeComponent(widget.subject)}'
            '&body=${Uri.encodeComponent(body)}',
      );
      final opened = await launchUrl(uri);
      if (!mounted) return;
      if (opened) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _sending = false;
          _error =
              'No e-mail app could be opened. Set a default mail app and '
              'try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Could not open the e-mail app.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send referral by e-mail'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppDropdownFormField<String>(
              initialValue: _recipientId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Send to'),
              items: [
                for (final recipient in referralRecipients)
                  DropdownMenuItem(
                    value: recipient.id,
                    child: Text(recipient.label),
                  ),
              ],
              onChanged: _sending ? null : _selectRecipient,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _email,
              enabled: !_sending,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail address',
                helperText: 'Saved for the next referral to this recipient.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Your mail app opens with the referral details filled in. '
              'Use the print icon to save the form as a PDF and attach it '
              'before sending. The message contains confidential learner '
              'information.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: const Icon(Icons.forward_to_inbox_outlined),
          label: const Text('Open e-mail'),
        ),
      ],
    );
  }
}
