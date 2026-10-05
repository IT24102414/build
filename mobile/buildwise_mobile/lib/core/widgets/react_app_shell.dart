import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Responsive application chrome with the shared workspace navigation.
class ReactAppShell extends StatelessWidget {
  const ReactAppShell({
    super.key,
    required this.labels,
    required this.selectedLabel,
    required this.onNavigate,
    required this.displayName,
    required this.role,
    required this.unreadNotifications,
    required this.onNotifications,
    required this.onSignOut,
    required this.child,
  });

  final List<String> labels;
  final String selectedLabel, displayName, role;
  final ValueChanged<String> onNavigate;
  final int unreadNotifications;
  final VoidCallback onNotifications, onSignOut;
  final Widget child;

  Widget _menu(BuildContext context, bool phone) {
    final buttons = labels
        .map(
          (label) => Padding(
            padding: const EdgeInsets.all(2),
            child: TextButton(
              onPressed: () => onNavigate(label),
              style: TextButton.styleFrom(
                foregroundColor: label == selectedLabel
                    ? AppColors.primary
                    : AppColors.textMuted,
                backgroundColor: label == selectedLabel
                    ? AppColors.primaryLight
                    : Colors.transparent,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(label),
            ),
          ),
        )
        .toList();
    return Container(
      width: phone ? null : 268,
      padding: EdgeInsets.all(phone ? 12 : 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: phone
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: buttons),
            )
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'BW',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BuildWise',
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Project operations',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'WORKSPACE',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ...buttons,
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final phone = constraints.maxWidth <= 820;
      final iconStyle = IconButton.styleFrom(
        fixedSize: const Size(38, 38),
        minimumSize: const Size(38, 38),
        padding: const EdgeInsets.all(8),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
      final initials = displayName
          .split(' ')
          .where((part) => part.isNotEmpty)
          .take(2)
          .map((part) => part[0].toUpperCase())
          .join();
      final main = Expanded(
        child: Column(
          children: [
            Container(
              height: 68,
              padding: EdgeInsets.symmetric(horizontal: phone ? 16 : 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      phone ? 'BuildWise' : 'Workspace / $selectedLabel',
                      style: TextStyle(
                        fontSize: phone ? 16 : 14,
                        fontWeight: phone ? FontWeight.w800 : FontWeight.w600,
                        color: phone ? AppColors.text : AppColors.textMuted,
                      ),
                    ),
                  ),
                  Badge(
                    isLabelVisible: unreadNotifications > 0,
                    label: Text('$unreadNotifications'),
                    child: IconButton.outlined(
                      style: iconStyle,
                      tooltip: 'Notifications',
                      onPressed: onNotifications,
                      icon: const Icon(Icons.notifications_none, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!phone) ...[
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          role,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(width: 12),
                  IconButton.outlined(
                    style: iconStyle,
                    tooltip: 'Sign out',
                    onPressed: onSignOut,
                    icon: const Icon(Icons.power_settings_new, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      );
      return Scaffold(
        body: SafeArea(
          child: phone
              ? Column(children: [_menu(context, true), main])
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [_menu(context, false), main],
                ),
        ),
      );
    },
  );
}
