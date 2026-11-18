import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/widgets/scaneliq_buttons.dart';
import 'package:scaneliq/core/widgets/scaneliq_content_widgets.dart';
import 'package:scaneliq/core/widgets/scaneliq_logo.dart';
import 'package:scaneliq/features/security/data/app_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLockMode { unlock, setPin, verifyCurrent }

/// Full-screen Concept A security PIN and biometric authentication barrier.
class AppLockScreen extends StatefulWidget {
  final AppLockMode mode;
  final bool dismissible;
  final AppLockService? lockServiceOverride;

  const AppLockScreen({
    super.key,
    this.mode = AppLockMode.unlock,
    this.dismissible = false,
    this.lockServiceOverride,
  });

  static Future<bool> showUnlockBarrier(BuildContext context) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            const AppLockScreen(mode: AppLockMode.unlock, dismissible: false),
      ),
    );
    return result == true;
  }

  static Future<bool> showSetPin(BuildContext context) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            const AppLockScreen(mode: AppLockMode.setPin, dismissible: true),
      ),
    );
    return result == true;
  }

  static Future<bool> showVerifyCurrent(BuildContext context) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AppLockScreen(
          mode: AppLockMode.verifyCurrent,
          dismissible: true,
        ),
      ),
    );
    return result == true;
  }

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  static const String _prefPinUiLength = 'app_lock_ui_pin_length';

  late final AppLockService _lockService;
  String _enteredPin = '';
  String _firstPinForSetup = '';
  bool _isConfirmingSetup = false;
  int _pinLength = 4;
  String? _errorMessage;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  bool _isCheckingBiometrics = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _lockService = widget.lockServiceOverride ?? AppLockService.instance;
    _initSecurityUiState();
  }

  Future<void> _initSecurityUiState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLen = prefs.getInt(_prefPinUiLength);
      if (mounted && (savedLen == 4 || savedLen == 6)) {
        setState(() => _pinLength = savedLen!);
      }
    } catch (_) {
      // Keep safe 4-digit default when preferences are unavailable.
    }

    if (!mounted) return;
    _checkInitialLockout();
    if (widget.mode == AppLockMode.unlock && _lockService.isBiometricsEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _promptBiometrics();
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
      if (!mounted) {
        timer.cancel();
        return;
      }
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
    if (_isCheckingBiometrics || _isVerifying || _cooldownSeconds > 0) return;
    setState(() => _isCheckingBiometrics = true);
    final authenticated = await _lockService.authenticateWithBiometrics();
    if (!mounted) return;
    setState(() => _isCheckingBiometrics = false);

    if (authenticated) {
      Navigator.of(context).pop(true);
    }
  }

  void _onDigitPressed(String digit) {
    if (_cooldownSeconds > 0 || _isVerifying) return;
    if (_enteredPin.length < _pinLength) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });

      if (_enteredPin.length == _pinLength) {
        _handleCompletePin(_enteredPin);
      }
    }
  }

  void _onBackspacePressed() {
    if (_cooldownSeconds > 0 || _isVerifying) return;
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
        setState(() => _isVerifying = true);
        final res = await _lockService.verifyPin(pin);
        if (!mounted) return;
        setState(() => _isVerifying = false);
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
            setState(() => _isVerifying = true);
            await _lockService.setPin(pin);
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt(_prefPinUiLength, _pinLength);
            } catch (_) {}
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
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final horizontalPad = ScaneliqSpacing.adaptiveHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );

    String titleText = 'Vault Locked';
    String subtitleText = 'Enter your $_pinLength-digit security PIN to unlock';

    if (widget.mode == AppLockMode.setPin) {
      if (_isConfirmingSetup) {
        titleText = 'Confirm PIN';
        subtitleText = 'Re-enter your $_pinLength-digit security PIN';
      } else {
        titleText = 'Set Security PIN';
        subtitleText =
            'Choose a $_pinLength-digit PIN to protect your local vault';
      }
    } else if (widget.mode == AppLockMode.verifyCurrent) {
      titleText = 'Verify Current PIN';
      subtitleText = 'Enter your current PIN to modify security settings';
    }

    final showBioButton =
        widget.mode == AppLockMode.unlock && _lockService.isBiometricsEnabled;

    return PopScope(
      canPop: widget.dismissible,
      child: Scaffold(
        backgroundColor: tokens.bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                16,
                horizontalPad,
                28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 44).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top status bar with optional cancel/back when dismissible
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (widget.dismissible)
                          ScaneliqTextButton(
                            label: '← Cancel',
                            onPressed: () => Navigator.of(context).pop(false),
                          )
                        else
                          const ScaneliqStatusLabel(
                            text: 'LOCKED',
                            tone: ScaneliqStatusTone.neutral,
                          ),
                        const ScaneliqStatusLabel(text: 'PBKDF2 · 100K ITERS'),
                      ],
                    ),

                    // Center Brand & PIN Dots
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          const ScaneliqLogo(size: 48, borderRadius: 12),
                          const SizedBox(height: 16),
                          Text(titleText, style: textTheme.headlineLarge),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Text(
                              subtitleText,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium,
                            ),
                          ),
                          if (widget.mode == AppLockMode.setPin &&
                              !_isConfirmingSetup) ...[
                            const SizedBox(height: 14),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PinLengthChip(
                                  label: '4 Digits',
                                  selected: _pinLength == 4,
                                  onTap: () => setState(() {
                                    _pinLength = 4;
                                    _enteredPin = '';
                                  }),
                                ),
                                const SizedBox(width: 8),
                                _PinLengthChip(
                                  label: '6 Digits',
                                  selected: _pinLength == 6,
                                  onTap: () => setState(() {
                                    _pinLength = 6;
                                    _enteredPin = '';
                                  }),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 22),
                          // Tactile PIN Indicator Dots
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_pinLength, (index) {
                              final filled = index < _enteredPin.length;
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: filled
                                      ? tokens.accent
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: filled
                                        ? tokens.accent
                                        : tokens.textPrimary,
                                    width: 1.5,
                                  ),
                                ),
                              );
                            }),
                          ),
                          if (_isVerifying) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  tokens.accent,
                                ),
                              ),
                            ),
                          ] else if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: tokens.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Tactile Concept A 3x4 Keypad
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Column(
                        children: [
                          for (final row in const [
                            ['1', '2', '3'],
                            ['4', '5', '6'],
                            ['7', '8', '9'],
                          ]) ...[
                            Row(
                              children: [
                                for (var i = 0; i < row.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  Expanded(
                                    child: _KeypadDigitButton(
                                      label: row[i],
                                      onPressed: () => _onDigitPressed(row[i]),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: showBioButton
                                    ? _KeypadActionButton(
                                        tooltip: 'Unlock with Biometrics',
                                        isAccent: true,
                                        onPressed: _cooldownSeconds > 0
                                            ? null
                                            : _promptBiometrics,
                                        child: Icon(
                                          Icons.fingerprint_rounded,
                                          color: tokens.accent,
                                          size: 24,
                                        ),
                                      )
                                    : const SizedBox(height: 56),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _KeypadDigitButton(
                                  label: '0',
                                  onPressed: () => _onDigitPressed('0'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _KeypadActionButton(
                                  tooltip: 'Backspace',
                                  onPressed: _onBackspacePressed,
                                  child: Icon(
                                    Icons.backspace_outlined,
                                    color: tokens.textSecondary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class _PinLengthChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PinLengthChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoft : tokens.surface,
          borderRadius: ScaneliqRadius.pillBorderRadius,
          border: Border.all(
            color: selected ? tokens.accent : tokens.hairline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? tokens.accent : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _KeypadDigitButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _KeypadDigitButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: ScaneliqRadius.buttonBorderRadius,
        side: BorderSide(color: tokens.hairline, width: 1),
      ),
      child: InkWell(
        borderRadius: ScaneliqRadius.buttonBorderRadius,
        onTap: onPressed,
        child: SizedBox(
          height: 56,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontSize: 21, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadActionButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool isAccent;

  const _KeypadActionButton({
    required this.child,
    required this.onPressed,
    required this.tooltip,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isAccent ? tokens.accentSoft : tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: ScaneliqRadius.buttonBorderRadius,
          side: BorderSide(
            color: isAccent ? tokens.accent : tokens.hairline,
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: ScaneliqRadius.buttonBorderRadius,
          onTap: onPressed,
          child: SizedBox(height: 56, child: Center(child: child)),
        ),
      ),
    );
  }
}
