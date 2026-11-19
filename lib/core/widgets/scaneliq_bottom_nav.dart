import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';

/// Descriptor for a top-level destination in Concept A's 3-tab bottom bar.
class ScaneliqNavDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const ScaneliqNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// Concept A frosted 3-tab bottom navigation bar (`Scans`, `Folders`, `PDF Suite`).
class ScaneliqBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<ScaneliqNavDestination> destinations;

  const ScaneliqBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.destinations = defaultDestinations,
  });

  static const List<ScaneliqNavDestination> defaultDestinations = [
    ScaneliqNavDestination(
      label: 'Scans',
      icon: Icons.description_outlined,
      selectedIcon: Icons.description_rounded,
    ),
    ScaneliqNavDestination(
      label: 'Folders',
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
    ),
    ScaneliqNavDestination(
      label: 'PDF Suite',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: ScaneliqSpacing.bottomNavHeight + bottomPadding,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: 8 + bottomPadding,
          ),
          decoration: BoxDecoration(
            color: tokens.navGlass,
            border: Border(top: BorderSide(color: tokens.hairline, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _ScaneliqNavItem(
                    destination: destinations[i],
                    isSelected: i == selectedIndex,
                    tokens: tokens,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScaneliqNavItem extends StatelessWidget {
  final ScaneliqNavDestination destination;
  final bool isSelected;
  final ScaneliqTokens tokens;
  final VoidCallback onTap;

  const _ScaneliqNavItem({
    required this.destination,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? tokens.textPrimary : tokens.textTertiary;

    return Semantics(
      selected: isSelected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? destination.selectedIcon : destination.icon,
                size: 21,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Right-thumb floating capture cluster (`[Gallery Import]` + `[📷 Scan]`).
class ScaneliqFloatingCaptureCluster extends StatelessWidget {
  final VoidCallback onScanPressed;
  final VoidCallback onImportPressed;
  final bool isBusy;

  const ScaneliqFloatingCaptureCluster({
    super.key,
    required this.onScanPressed,
    required this.onImportPressed,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Import',
          child: Tooltip(
            message: 'Import from Gallery',
            child: Material(
              color: tokens.surface,
              shape: CircleBorder(
                side: BorderSide(color: tokens.hairline, width: 1),
              ),
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.16),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: isBusy ? null : onImportPressed,
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(
                    Icons.photo_library_outlined,
                    size: 19,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Scan document',
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: ScaneliqRadius.pillBorderRadius,
              boxShadow: tokens.floatingShadow,
            ),
            child: ElevatedButton.icon(
              onPressed: isBusy ? null : onScanPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: ScaneliqRadius.pillBorderRadius,
                ),
              ),
              icon: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.camera_alt_outlined, size: 18),
              label: Text(
                'Scan',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: Colors.white, fontSize: 14.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
