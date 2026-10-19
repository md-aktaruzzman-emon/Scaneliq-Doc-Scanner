import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/documents/presentation/documents_library_screen.dart';
import 'package:scaneliq/features/documents/presentation/home_screen.dart';
import 'package:scaneliq/features/editor/presentation/review_pages_screen.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:scaneliq/features/settings/presentation/settings_screen.dart';
import 'package:scaneliq/features/settings/presentation/tools_screen.dart';

/// Modern 4-Tab Navigation Shell anchored by an elevated central camera shutter action
class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;
  bool _isLaunchingScanner = false;

  final List<Widget> _screens = const [
    HomeScreen(),
    DocumentsLibraryScreen(),
    ToolsScreen(),
    SettingsScreen(),
  ];

  Future<void> _startCentralScanner() async {
    if (_isLaunchingScanner) return;
    setState(() {
      _isLaunchingScanner = true;
    });

    try {
      ref.read(scanSessionProvider.notifier).resetSession();
      final success = await ref
          .read(scanSessionProvider.notifier)
          .startScannerCapture();

      if (success && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReviewPagesScreen()),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLaunchingScanner = false;
        });
      }
    }
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.surface1Dark
        : AppColors.surface1Light;
    final borderColor = isDark
        ? AppColors.borderSubtleDark
        : AppColors.borderSubtleLight;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(top: BorderSide(color: borderColor, width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Tab 0: Home
              Expanded(
                child: _NavBarItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Home',
                  isSelected: _currentIndex == 0,
                  onTap: () => _onTabSelected(0),
                ),
              ),
              // Tab 1: Documents
              Expanded(
                child: _NavBarItem(
                  icon: Icons.folder_outlined,
                  selectedIcon: Icons.folder_rounded,
                  label: 'Documents',
                  isSelected: _currentIndex == 1,
                  onTap: () => _onTabSelected(1),
                ),
              ),
              // Prominent Central Shutter Action
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Semantics(
                  button: true,
                  label: 'Start Document Scanner',
                  child: Tooltip(
                    message: 'Scan document',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLaunchingScanner
                            ? null
                            : _startCentralScanner,
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF3B82F6),
                                AppColors.brandPrimary,
                                AppColors.brandDeep,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brandPrimary.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLaunchingScanner
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.document_scanner,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Tab 2: Tools
              Expanded(
                child: _NavBarItem(
                  icon: Icons.build_outlined,
                  selectedIcon: Icons.build,
                  label: 'Tools',
                  isSelected: _currentIndex == 2,
                  onTap: () => _onTabSelected(2),
                ),
              ),
              // Tab 3: Settings
              Expanded(
                child: _NavBarItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: 'Settings',
                  isSelected: _currentIndex == 3,
                  onTap: () => _onTabSelected(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.brandAccent : AppColors.brandPrimary;
    final inactiveColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Semantics(
      selected: isSelected,
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.surface2Dark : AppColors.brandLight)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
