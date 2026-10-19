import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/core/widgets/scaneliq_logo.dart';
import 'package:scaneliq/features/security/data/app_lock_service.dart';

enum AppLockMode { unlock, setPin, verifyCurrent }

class AppLockDialog extends StatefulWidget {
  final AppLockMode mode;
  final bool dismissible;

  const AppLockDialog({
    super.key,
    this.mode = AppLockMode.unlock,
    this.dismissible = false,
  });

  static Future<bool> showUnlockBarrier(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AppLockDialog(mode: AppLockMode.unlock, dismissible: false),
      ),
    );
    return result == true;
  }

  static Future<bool> showSetPin(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) =>
          const AppLockDialog(mode: AppLockMode.setPin, dismissible: true),
    );
    return result == true;
  }

  static Future<bool> showVerifyCurrent(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const AppLockDialog(
        mode: AppLockMode.verifyCurrent,
        dismissible: true,
      ),
    );
    return result == true;
  }

  @override
  State<AppLockDialog> createState() => _AppLockDialogState();
}

class _AppLockDialogState extends State<AppLockDialog> {
  final AppLockService _lockService = AppLockService.instance;
  String _enteredPin = '';
  String _firstPinForSetup = '';
  bool _isConfirmingSetup = false;
  String? _errorMessage;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  bool _isCheckingBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkInitialLockout();
    if (widget.mode == AppLockMode.unlock && _lockService.isBiometricsEnabled) {
      // Trigger biometrics automatically after widget builds
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptBiometrics();
      });
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _checkInitialLockout() {
    final cd = _lockService.getRemainingCooldownSeconds();
    if (cd > 0) {
      _startCooldownTimer(cd);
    }
  }

  void _startCooldownTimer(int seconds) {
    setState(() {
      _cooldownSeconds = seconds;
      _errorMessage = 'Too many failed attempts. Wait $_cooldownSeconds s';
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _cooldownSeconds = 0;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _cooldownSeconds--;
          _errorMessage = 'Too many failed attempts. Wait $_cooldownSeconds s';
        });
      }
    });
  }

  Future<void> _promptBiometrics() async {
    if (_isCheckingBiometrics || _cooldownSeconds > 0) return;
    setState(() => _isCheckingBiometrics = true);
    final authenticated = await _lockService.authenticateWithBiometrics();
    setState(() => _isCheckingBiometrics = false);

    if (authenticated && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _onDigitPressed(String digit) {
    if (_cooldownSeconds > 0) return;
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });

      if (_enteredPin.length == 4) {
        _handleCompletePin(_enteredPin);
      }
    }
  }

  void _onBackspacePressed() {
    if (_cooldownSeconds > 0) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleCompletePin(String pin) async {
    switch (widget.mode) {
      case AppLockMode.unlock:
      case AppLockMode.verifyCurrent:
        final res = await _lockService.verifyPin(pin);
        if (!mounted) return;
        if (res.success) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _enteredPin = '';
            if (res.isLockedOut) {
              _startCooldownTimer(res.remainingCooldownSeconds);
            } else {
              _errorMessage =
                  'Incorrect PIN (${res.remainingAttempts} attempts remaining)';
            }
          });
        }
        break;

      case AppLockMode.setPin:
        if (!_isConfirmingSetup) {
          setState(() {
            _firstPinForSetup = pin;
            _enteredPin = '';
            _isConfirmingSetup = true;
          });
        } else {
          if (pin == _firstPinForSetup) {
            await _lockService.setPin(pin);
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          } else {
            setState(() {
              _enteredPin = '';
              _firstPinForSetup = '';
              _isConfirmingSetup = false;
              _errorMessage = 'PINs do not match. Start over.';
            });
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String titleText = 'Enter PIN';
    String subtitleText = 'Unlock Scaneliq to access documents';

    if (widget.mode == AppLockMode.setPin) {
      if (_isConfirmingSetup) {
        titleText = 'Confirm PIN';
        subtitleText = 'Re-enter your 4-digit security PIN';
      } else {
        titleText = 'Set Security PIN';
        subtitleText = 'Choose a 4-digit PIN to lock your documents';
      }
    } else if (widget.mode == AppLockMode.verifyCurrent) {
      titleText = 'Verify Current PIN';
      subtitleText = 'Enter your current PIN to modify security settings';
    }

    return Dialog(
      backgroundColor: isDark ? AppColors.surface1Dark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.dismissible)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
            const ScaneliqLogo(size: 48, borderRadius: 12),
            const SizedBox(height: 14),
            Text(
              titleText,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              subtitleText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),

            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? AppColors.brandPrimary
                        : (isDark
                              ? AppColors.surface2Dark
                              : const Color(0xFFE2E8F0)),
                    border: Border.all(
                      color: isFilled
                          ? AppColors.brandPrimary
                          : (isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight),
                      width: 1.5,
                    ),
                  ),
                );
              }),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Numeric Keypad
            _buildKeypad(isDark),

            if (widget.mode == AppLockMode.unlock &&
                _lockService.isBiometricsEnabled) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _cooldownSeconds > 0 ? null : _promptBiometrics,
                icon: const Icon(Icons.fingerprint_rounded, size: 24),
                label: const Text('Unlock with Biometrics'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad(bool isDark) {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((digit) => _buildKey(digit, isDark)).toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 64, height: 64),
              _buildKey('0', isDark),
              SizedBox(
                width: 64,
                height: 64,
                child: IconButton(
                  icon: const Icon(Icons.backspace_outlined),
                  onPressed: _onBackspacePressed,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKey(String label, bool isDark) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: isDark ? AppColors.surface2Dark : const Color(0xFFF1F5F9),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _onDigitPressed(label),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
