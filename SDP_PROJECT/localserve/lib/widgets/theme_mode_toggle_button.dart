import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

/// Interactive theme mode toggle button and selector modal
class ThemeModeToggleButton extends StatelessWidget {
  final bool compact;
  const ThemeModeToggleButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    ThemeService themeService;
    try {
      themeService = Provider.of<ThemeService>(context, listen: true);
    } catch (_) {
      themeService = ThemeService();
    }
    final mode = themeService.themeMode;

    IconData icon;
    String label;
    Color iconColor;

    switch (mode) {
      case ThemeMode.dark:
        icon = Icons.dark_mode_rounded;
        label = 'Dark';
        iconColor = const Color(0xFF60A5FA); // Sky blue glow
        break;
      case ThemeMode.light:
        icon = Icons.light_mode_rounded;
        label = 'Light';
        iconColor = const Color(0xFFF59E0B); // Amber sun
        break;
      case ThemeMode.system:
        icon = Icons.brightness_auto_rounded;
        label = 'Auto';
        iconColor = const Color(0xFF10B981); // Emerald
        break;
    }

    if (compact) {
      return IconButton(
        icon: Icon(icon, color: iconColor, size: 22),
        tooltip: 'Theme: $label (Tap to switch)',
        onPressed: () => showThemeSelectorSheet(context),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showThemeSelectorSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showThemeSelectorSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _ThemeSelectorBottomSheet(),
    );
  }
}

class _ThemeSelectorBottomSheet extends StatelessWidget {
  const _ThemeSelectorBottomSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ThemeService themeService;
    try {
      themeService = Provider.of<ThemeService>(context, listen: true);
    } catch (_) {
      themeService = ThemeService();
    }
    final currentMode = themeService.themeMode;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance & Theme',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Customize the look & feel of LocalServe',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 1. Dark Mode (Default)
          _buildThemeOptionTile(
            context: context,
            title: 'Dark Mode (Default)',
            description: 'Sleek obsidian slate with royal electric indigo accents. Easy on the eyes.',
            icon: Icons.dark_mode_rounded,
            accentColor: const Color(0xFF3B82F6),
            isSelected: currentMode == ThemeMode.dark,
            badgeText: 'DEFAULT',
            onTap: () {
              themeService.setThemeMode(ThemeMode.dark);
              Navigator.pop(context);
            },
          ),

          const SizedBox(height: 12),

          // 2. Light Mode
          _buildThemeOptionTile(
            context: context,
            title: 'Light Mode',
            description: 'Crisp, high-contrast white & slate modern palette for daytime clarity.',
            icon: Icons.light_mode_rounded,
            accentColor: const Color(0xFFF59E0B),
            isSelected: currentMode == ThemeMode.light,
            onTap: () {
              themeService.setThemeMode(ThemeMode.light);
              Navigator.pop(context);
            },
          ),

          const SizedBox(height: 12),

          // 3. System Mode
          _buildThemeOptionTile(
            context: context,
            title: 'System Default',
            description: 'Automatically synchronizes with your device settings.',
            icon: Icons.brightness_auto_rounded,
            accentColor: const Color(0xFF10B981),
            isSelected: currentMode == ThemeMode.system,
            onTap: () {
              themeService.setThemeMode(ThemeMode.system);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOptionTile({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
    required bool isSelected,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.5),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF3B82F6), width: 0.8),
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF60A5FA),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
