import 'dart:async';

import 'package:buildwise_mobile/features/operations/screens/field_workspace_screen.dart';
import 'package:buildwise_mobile/features/operations/services/operations_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves canned field data so each workspace can be asserted without a backend.
class MockFieldService extends OperationsService {
  List<Map<String, dynamic>> requests = const [];
  List<Map<String, dynamic>> orders = const [];
  List<Map<String, dynamic>> deliveries = const [];
  List<Map<String, dynamic>> inspections = const [];
  List<Map<String, dynamic>> ncrs = const [];

  /// When set, every call throws this instead of returning data.
  String? failWith;

  @override
  Future<List<Map<String, dynamic>>> listMyRequests() async {
    if (failWith != null) throw Exception(failWith!);
    return requests;
  }

  @override
  Future<List<Map<String, dynamic>>> listConfirmedOrders() async {
    if (failWith != null) throw Exception(failWith!);
    return orders;
  }

  @override
  Future<List<Map<String, dynamic>>> listDeliveries() async {
    if (failWith != null) throw Exception(failWith!);
    return deliveries;
  }

  @override
  Future<List<Map<String, dynamic>>> listInspections({String? status}) async {
    if (failWith != null) throw Exception(failWith!);
    return inspections;
  }

  @override
  Future<List<Map<String, dynamic>>> listNonConformances() async {
    if (failWith != null) throw Exception(failWith!);
    return ncrs;
  }
}

/// Holds the engineer's request open so the loading frame can be asserted.
class _GatedFieldService extends OperationsService {
  _GatedFieldService(this._gate);

  final Completer<List<Map<String, dynamic>>> _gate;

  @override
  Future<List<Map<String, dynamic>>> listMyRequests() => _gate.future;

  @override
  Future<List<Map<String, dynamic>>> listConfirmedOrders() async => const [];

  @override
  Future<List<Map<String, dynamic>>> listDeliveries() async => const [];

  @override
  Future<List<Map<String, dynamic>>> listInspections({String? status}) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> listNonConformances() async => const [];
}

/// Pumps a workspace for [role] against [service] and settles the first frame.
Future<void> pumpWorkspace(
  WidgetTester tester,
  String role,
  MockFieldService service,
) async {
  await tester.pumpWidget(
    MaterialApp(home: FieldWorkspaceScreen(role: role, service: service)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Site Engineer field workspace', () {
    testWidgets('answers "what do I need to chase?"', (tester) async {
      final service = MockFieldService()
        ..requests = const [
          {
            'id': 58,
            'reason': 'Cement for Block C',
            'status': 'PendingApproval',
            'requiredDate': '2026-10-08',
          },
          {
            'id': 52,
            'reason': 'Blocks for Block A',
            'status': 'Approved',
            'requiredDate': '2026-09-30',
          },
        ];

      await pumpWorkspace(tester, 'SiteEngineer', service);

      expect(find.text('My Requests'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      // "Approved" appears both as a count tile and as MR-52's status chip, so
      // assert both are present rather than expecting a single match.
      expect(find.text('Approved'), findsNWidgets(2));
      expect(find.text('MR-52'), findsOneWidget);
      expect(find.text('MR-58'), findsOneWidget);
      expect(find.text('Pending Approval'), findsOneWidget);
      expect(find.text('+  New Material Request'), findsOneWidget);
    });

    testWidgets('explains the empty state instead of a blank screen',
        (tester) async {
      await pumpWorkspace(tester, 'SiteEngineer', MockFieldService());

      expect(
          find.textContaining('not raised any material requests'), findsOneWidget);
      expect(find.text('+  New Material Request'), findsOneWidget);
    });
  });
  group('Site Officer field workspace', () {
    testWidgets('answers "what has arrived that I must receive?"',
        (tester) async {
      final service = MockFieldService()
        ..orders = const [
          {
            'id': 32,
            'status': 'Confirmed',
            'supplierName': 'Supplier B',
            'expectedDeliveryDate': '2026-10-08',
            'items': [
              {
                'materialName': 'Cement',
                'orderedQuantity': 500,
                'materialUnit': 'bags'
              }
            ],
          }
        ];

      await pumpWorkspace(tester, 'SiteOfficer', service);

      expect(find.text('Delivery Workspace'), findsOneWidget);
      expect(find.text('Orders awaiting receipt'), findsOneWidget);
      expect(find.text('Receive Delivery'), findsOneWidget);
      expect(find.text('PO-32'), findsOneWidget);
      expect(find.text('500 bags ordered'), findsOneWidget);
    });

    testWidgets('disables receiving when nothing has arrived', (tester) async {
      await pumpWorkspace(tester, 'SiteOfficer', MockFieldService());

      expect(find.textContaining('No confirmed purchase orders'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Receive Delivery'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('Quality Inspector field workspace', () {
    testWidgets('answers "what is sitting un-inspected?"', (tester) async {
      final service = MockFieldService()
        ..deliveries = const [
          {'id': 34, 'status': 'Received', 'supplierName': 'Supplier B'},
          // Already inspected, so it must not appear as pending.
          {'id': 29, 'status': 'Received', 'supplierName': 'Supplier A'},
          // Still with the supplier, so nothing to inspect yet.
          {'id': 40, 'status': 'Scheduled', 'supplierName': 'Supplier C'},
        ]
        ..inspections = const [
          {'id': 35, 'deliveryId': 29}
        ]
        ..ncrs = const [
          {'id': 1, 'status': 'Open'},
          {'id': 2, 'status': 'Closed'},
        ];

      await pumpWorkspace(tester, 'QualityInspector', service);

      expect(find.text('Inspection Workspace'), findsOneWidget);
      // The label appears as the count tile and the section header.
      expect(find.text('Awaiting inspection'), findsNWidgets(2));
      expect(find.text('Start Inspection'), findsOneWidget);
      // DEL-34 only: DEL-29 is inspected and DEL-40 has not arrived.
      expect(find.text('DEL-34'), findsOneWidget);
      expect(find.text('DEL-29'), findsNothing);
      expect(find.text('DEL-40'), findsNothing);
      // Only the Open NCR counts; the Closed one does not.
      expect(find.text('Open NCRs'), findsOneWidget);
    });

    testWidgets('flags a delivery that arrived with a discrepancy',
        (tester) async {
      final service = MockFieldService()
        ..deliveries = const [
          {'id': 30, 'status': 'DiscrepancyReported', 'supplierName': 'Supplier B'},
        ];

      await pumpWorkspace(tester, 'QualityInspector', service);

      expect(find.text('DEL-30'), findsOneWidget);
      expect(find.text('Discrepancy Reported'), findsOneWidget);
    });
  });

  group('Network and error handling', () {
    testWidgets('shows a friendly offline message, never a SocketException',
        (tester) async {
      final service = MockFieldService()
        ..failWith = 'SocketException: Connection failed (OS Error: failed)';

      await pumpWorkspace(tester, 'SiteOfficer', service);

      expect(find.text('Cannot load workspace'), findsOneWidget);
      expect(find.textContaining('No internet connection'), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('does not flash workspace content before the load completes',
        (tester) async {
      // Hold the request open so the first frame can be observed deterministically.
      final gate = Completer<List<Map<String, dynamic>>>();
      final service = _GatedFieldService(gate);

      await tester.pumpWidget(
        MaterialApp(
            home: FieldWorkspaceScreen(role: 'SiteEngineer', service: service)),
      );
      await tester.pump();

      // While loading, the workspace must not yet claim the engineer has no
      // pending work: a "0 Pending" tile rendered before the data arrives reads
      // as "you are all clear" when the truth is "not loaded yet".
      expect(find.text('My Requests'), findsNothing);
      expect(find.text('Loading your work…'), findsOneWidget);

      gate.complete(const [
        {
          'id': 1,
          'reason': 'Cement',
          'status': 'PendingApproval',
          'requiredDate': '2026-10-08'
        }
      ]);
      await tester.pumpAndSettle();

      expect(find.text('My Requests'), findsOneWidget);
      expect(find.text('Loading your work…'), findsNothing);
      expect(find.text('Pending Approval'), findsOneWidget);
    });
  });
}