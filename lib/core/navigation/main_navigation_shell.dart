import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scaneliq/core/widgets/scaneliq_bottom_nav.dart';
import 'package:scaneliq/features/documents/presentation/documents_library_screen.dart';
import 'package:scaneliq/features/documents/presentation/home_screen.dart';
import 'package:scaneliq/features/security/data/app_lock_service.dart';
import 'package:scaneliq/features/security/presentation/app_lock_dialog.dart';
import 'package:scaneliq/features/settings/presentation/tools_screen.dart';

/// Inherited coordinator allowing any child screen inside the shell to switch
/// top-level tabs cleanly whether running under `go_router` or standalone.
class ScaneliqShellScope extends InheritedWidget {
  final int currentIndex;
  final ValueChanged<int> goToTab;

  const ScaneliqShellScope({
    super.key,
    required this.currentIndex,
    required this.goToTab,
    required super.child,
  });

  static ScaneliqShellScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ScaneliqShellScope>();
  }

  @override
  bool updateShouldNotify(ScaneliqShellScope oldWidget) =>
      currentIndex != oldWidget.currentIndex;
}

/// Concept A 3-Tab Application Shell (`Scans`, `Folders`, `PDF Suite`).
///
/// Works seamlessly both with `StatefulNavigationShell` from `go_router` and
/// standalone when mounted directly in widget test harnesses.
class MainNavigationShell extends StatefulWidget {
  final StatefulNavigationShell? navigationShell;
  final int initialIndex;

  const MainNavigationShell({
    super.key,
    this.navigationShell,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell>
    with WidgetsBindingObserver {
  late int _standaloneIndex;
  bool _isPromptingLock = false;

  static const List<Widget> _standaloneBranches = [
    HomeScreen(),
    DocumentsLibraryScreen(),
    ToolsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _standaloneIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLockRequirements();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      AppLockService.instance.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _checkLockRequirements();
    }
  }

  Future<void> _checkLockRequirements() async {
    if (_isPromptingLock || !mounted) return;
    if (AppLockService.instance.shouldRequireUnlockOnResume()) {
      _isPromptingLock = true;
      await AppLockDialog.showUnlockBarrier(context);
      _isPromptingLock = false;
    }
  }

  int get _activeIndex =>
      widget.navigationShell?.currentIndex ?? _standaloneIndex;

  void _onDestinationSelected(int index) {
    final navShell = widget.navigationShell;
    if (navShell != null) {
      navShell.goBranch(index, initialLocation: index == navShell.currentIndex);
      return;
    }
    if (_standaloneIndex == index) return;
    setState(() {
      _standaloneIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _activeIndex;

    return ScaneliqShellScope(
      currentIndex: activeIndex,
      goToTab: _onDestinationSelected,
      child: Scaffold(
        body:
            widget.navigationShell ??
            IndexedStack(
              index: _standaloneIndex,
              children: _standaloneBranches,
            ),
        bottomNavigationBar: ScaneliqBottomNavBar(
          selectedIndex: activeIndex,
          onDestinationSelected: _onDestinationSelected,
        ),
      ),
    );
  }
}
