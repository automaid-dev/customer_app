import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shows a standard yes/no confirmation dialog and returns true only if
/// the person tapped the confirm button. Used for logout and any other
/// action that shouldn't happen from a single accidental tap.
///
/// Returns false (not null) if the dialog is dismissed by tapping
/// outside it or pressing back, so callers can just check `if (confirmed)`
/// without an extra null check.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool isDestructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: isDestructive ? AppColors.red : AppColors.blue,
          ),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Convenience wrapper specifically for the logout confirmation, since
/// it's used identically from three different screens (merchant home,
/// rider home, and the pending-approval screen) — keeps the copy
/// consistent everywhere instead of three separately-worded dialogs.
Future<bool> showLogoutConfirmDialog(BuildContext context) {
  return showConfirmDialog(
    context,
    title: 'Log out?',
    message: 'You\'ll need to sign in again to continue.',
    confirmText: 'Log out',
    isDestructive: true,
  );
}
