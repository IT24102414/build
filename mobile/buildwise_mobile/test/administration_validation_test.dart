import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buildwise_mobile/core/theme/app_theme.dart';
import 'package:buildwise_mobile/features/operations/screens/administration_screen.dart';
import 'package:buildwise_mobile/features/operations/services/operations_service.dart';

class AdminService extends OperationsService {
  Map<String, dynamic>? created;
  @override
  Future<List<dynamic>> listUsers({String? search}) async => [];
  @override
  Future<List<dynamic>> listAuditLogs({int pageSize = 25}) async => [];
  @override
  Future<Map<String, dynamic>> getSystemHealth() async => {};
  @override
  Future<Map<String, dynamic>> createUser(Map<String, dynamic> payload) async {
    created = payload;
    return {'id': 10, ...payload};
  }
}

void main() {
  testWidgets('invalid email blocks creation and corrected email submits', (
    tester,
  ) async {
    final service = AdminService();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdministrationScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add user'));
    await tester.pumpAndSettle();
    Finder field(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    await tester.enterText(field('Full name'), ' nirmal ');
    await tester.enterText(field('Email'), 'vnsjna@gmailcom');
    await tester.enterText(field('Temporary password'), 'Passw0rd!');
    await tester.ensureVisible(find.text('Create user'));
    await tester.tap(find.text('Create user'));
    await tester.pumpAndSettle();
    expect(service.created, isNull);
    expect(
      find.text('Enter a valid email, e.g. name@gmail.com.'),
      findsOneWidget,
    );
    await tester.enterText(field('Email'), ' vnsjna@gmail.com ');
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid email, e.g. name@gmail.com.'),
      findsNothing,
    );
    await tester.ensureVisible(find.text('Create user'));
    await tester.tap(find.text('Create user'));
    await tester.pumpAndSettle();
    expect(service.created?['email'], 'vnsjna@gmail.com');
    expect(service.created?['fullName'], 'nirmal');
    expect(tester.takeException(), isNull);
  });
}
