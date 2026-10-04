import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buildwise_mobile/features/operations/screens/material_requests_screen.dart';
import 'package:buildwise_mobile/features/operations/services/operations_service.dart';

class MockOperationsService extends OperationsService {
  List<Map<String, dynamic>> mockRequests = [
    {
      'id': 74,
      'projectName': 'Riverside Apartments — Block C',
      'itemCount': 1,
      // Mirrors the summary DTO: the list labels each row with the material.
      'materialNames': ['Cement (50kg bag)'],
      'status': 'Approved',
    },
    {
      'id': 75,
      'projectName': 'Riverside Apartments — Block C',
      'itemCount': 1,
      'materialNames': ['Concrete Blocks'],
      'status': 'PendingApproval',
    }
  ];

  @override
  Future<List<Map<String, dynamic>>> listMyRequests() async => mockRequests;

  @override
  Future<List<Map<String, dynamic>>> listRequests({String? status}) async => mockRequests;

  /// The create-request form now resolves the project and material from the
  /// API instead of submitting hard-coded ids, so the mock serves the same
  /// reference data the real `/projects` and `/materials` endpoints return.
  @override
  Future<List<Map<String, dynamic>>> listProjects() async => [
        {'id': 1, 'name': 'Riverside Apartments — Block C'},
        {'id': 2, 'name': 'Kandy Heights — Tower A'},
      ];

  @override
  Future<List<Map<String, dynamic>>> listMaterials() async => [
        {'id': 1, 'name': 'Cement (50kg bag)', 'unit': 'bags'},
        {'id': 2, 'name': 'Concrete Blocks', 'unit': 'units'},
      ];

  /// Captures the last submitted request so a test can assert on what the form
  /// actually sent, rather than only on what the screen displayed.
  Map<String, dynamic>? lastSubmitted;

  @override
  Future<Map<String, dynamic>> createRequest({
    required int projectId,
    required String requiredDate,
    required int materialId,
    required double quantity,
    required String reason,
    String priority = 'Normal',
    String? siteNotes,
    String? description,
    String? unit,
    String? itemRequiredDate,
  }) async {
    lastSubmitted = {
      'projectId': projectId,
      'requiredDate': requiredDate,
      'materialId': materialId,
      'quantity': quantity,
      'reason': reason,
      'unit': unit,
    };
    final newReq = {
      'id': 76,
      'projectName': 'Riverside Apartments — Block C',
      'itemCount': 1,
      'status': 'Draft',
    };
    mockRequests.add(newReq);
    return newReq;
  }
}

void main() {
  group('MaterialRequestsScreen Widget Tests', () {
    testWidgets('Renders material requests list with status chips', (tester) async {
      final mockService = MockOperationsService();

      await tester.pumpWidget(
        MaterialApp(
          home: MaterialRequestsScreen(service: mockService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Material Requests'), findsOneWidget);
      // Rows lead with the material name, not "Request #74 · 1 item(s)". The id
      // moved to its own line below it.
      expect(find.text('Cement (50kg bag)'), findsOneWidget);
      expect(find.text('Concrete Blocks'), findsOneWidget);
      expect(find.text('Request #74'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Request #75'), findsOneWidget);
      expect(find.text('PendingApproval'), findsOneWidget);
      expect(find.text('Run AI Analysis'), findsNWidgets(2));
    });

    /// Opens the create sheet and resolves the reference-data dropdowns.
    Future<void> openCreateSheet(WidgetTester tester, MockOperationsService s) async {
      await tester.pumpWidget(MaterialApp(home: MaterialRequestsScreen(service: s)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Request'));
      await tester.pumpAndSettle();
    }

    /// Picks an option from one of the create sheet's reference-data dropdowns.
    Future<void> pickDropdown(
      WidgetTester tester,
      String label,
      String option,
    ) async {
      await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    /// Scrolls the sheet until [finder] is visible, then taps it. The submit
    /// button sits below the fold on a test-sized viewport, and a tap on an
    /// off-screen widget silently does nothing.
    ///
    /// [label] is matched against the button's own text rather than a bare
    /// `find.text`, because the list screen behind the sheet also renders a
    /// "Create Request" action and a `scrollUntilVisible` over several matches
    /// throws "Too many elements".
    Future<void> submitRequest(WidgetTester tester) async {
      // `scrollUntilVisible` requires exactly one match, and the sheet plus the
      // list screen behind it render several buttons. `ensureVisible` has no such
      // requirement, so scroll the sheet itself and then tap the button.
      final button = find.widgetWithText(FilledButton, 'Submit Request');
      await tester.ensureVisible(button.first);
      await tester.pumpAndSettle();
      await tester.tap(button.first);
      await tester.pumpAndSettle();
    }

    testWidgets('Create sheet offers real project and material dropdowns',
        (tester) async {
      final mockService = MockOperationsService();
      await openCreateSheet(tester, mockService);

      expect(find.text('Create Material Request'), findsOneWidget);
      expect(
          find.widgetWithText(DropdownButtonFormField<int>, 'Project *'), findsOneWidget);
      expect(
          find.widgetWithText(DropdownButtonFormField<int>, 'Material *'), findsOneWidget);
      expect(find.text('Quantity *'), findsOneWidget);
      expect(find.text('Justification *'), findsOneWidget);
      expect(find.text('Submit Request'), findsOneWidget);
    });

    testWidgets('Submitting with no project or material selected is refused',
        (tester) async {
      final mockService = MockOperationsService();
      await openCreateSheet(tester, mockService);

      await tester.enterText(find.widgetWithText(TextField, 'Quantity *'), '500');
      await tester.enterText(
          find.widgetWithText(TextField, 'Justification *'), 'For masonry work');
      await submitRequest(tester);

      // Nothing was sent, because the request is incomplete.
      expect(mockService.lastSubmitted, isNull);
      expect(find.text('Select a project.'), findsOneWidget);
    });
    testWidgets('A zero quantity is refused before any request is sent',
        (tester) async {
      final mockService = MockOperationsService();
      await openCreateSheet(tester, mockService);

      await pickDropdown(tester, 'Project *', 'Kandy Heights — Tower A');
      await pickDropdown(tester, 'Material *', 'Cement (50kg bag)');

      await tester.enterText(find.widgetWithText(TextField, 'Quantity *'), '0');
      await tester.enterText(
          find.widgetWithText(TextField, 'Justification *'), 'For masonry work');
      await submitRequest(tester);

      expect(mockService.lastSubmitted, isNull);
      expect(find.text('Quantity must be greater than zero.'), findsOneWidget);
    });

    testWidgets('A missing justification is refused', (tester) async {
      final mockService = MockOperationsService();
      await openCreateSheet(tester, mockService);

      await pickDropdown(tester, 'Project *', 'Riverside Apartments — Block C');
      await pickDropdown(tester, 'Material *', 'Cement (50kg bag)');

      await tester.enterText(find.widgetWithText(TextField, 'Quantity *'), '500');
      await submitRequest(tester);

      expect(mockService.lastSubmitted, isNull);
      expect(find.text('Enter a justification for this request.'), findsOneWidget);
    });

    testWidgets('A complete request submits the chosen project and material',
        (tester) async {
      final mockService = MockOperationsService();
      await openCreateSheet(tester, mockService);

      // Choose the *second* project and material, proving the form sends the
      // engineer's selection rather than a hard-coded first row.
      await pickDropdown(tester, 'Project *', 'Kandy Heights — Tower A');
      await pickDropdown(tester, 'Material *', 'Concrete Blocks');

      await tester.enterText(find.widgetWithText(TextField, 'Quantity *'), '500');
      await tester.enterText(
          find.widgetWithText(TextField, 'Justification *'), 'Required for masonry');
      await submitRequest(tester);

      expect(mockService.lastSubmitted, isNotNull);
      expect(mockService.lastSubmitted!['projectId'], 2);
      expect(mockService.lastSubmitted!['materialId'], 2);
      expect(mockService.lastSubmitted!['quantity'], 500.0);
      expect(mockService.lastSubmitted!['unit'], 'units');
    });
  });
}
