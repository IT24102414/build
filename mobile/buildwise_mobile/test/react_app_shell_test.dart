import 'package:buildwise_mobile/core/theme/app_theme.dart';
import 'package:buildwise_mobile/core/widgets/react_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('React navigation remains reachable at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final actions = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ReactAppShell(
            labels: const [
              'Dashboard',
              'Material Requests',
              'Quality Inspections',
              'Non-Conformance Reports',
            ],
            selectedLabel: 'Dashboard',
            displayName: 'Site Engineer',
            role: 'SiteEngineer',
            unreadNotifications: 2,
            onNavigate: actions.add,
            onNotifications: () => actions.add('notifications'),
            onSignOut: () => actions.add('sign out'),
            child: const Center(child: Text('Workspace content')),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Non-Conformance Reports'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Non-Conformance Reports'));
      await tester.tap(find.byTooltip('Notifications'));
      await tester.tap(find.byTooltip('Sign out'));
      expect(actions, ['Non-Conformance Reports', 'notifications', 'sign out']);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(Drawer), findsNothing);
      expect(find.text('Workspace content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
