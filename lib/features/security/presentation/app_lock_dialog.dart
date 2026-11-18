import 'package:flutter/material.dart';
import 'package:scaneliq/features/security/presentation/app_lock_screen.dart';

export 'package:scaneliq/features/security/presentation/app_lock_screen.dart'
    show AppLockMode, AppLockScreen;

/// Backward-compatible wrapper delegating dialog entry points to the full-screen
/// Concept A [AppLockScreen] barrier.
class AppLockDialog extends StatelessWidget {
  final AppLockMode mode;
  final bool dismissible;

  const AppLockDialog({
    super.key,
    this.mode = AppLockMode.unlock,
    this.dismissible = false,
  });

  static Future<bool> showUnlockBarrier(BuildContext context) =>
      AppLockScreen.showUnlockBarrier(context);

  static Future<bool> showSetPin(BuildContext context) =>
      AppLockScreen.showSetPin(context);

  static Future<bool> showVerifyCurrent(BuildContext context) =>
      AppLockScreen.showVerifyCurrent(context);

  @override
  Widget build(BuildContext context) {
    return AppLockScreen(mode: mode, dismissible: dismissible);
  }
}
