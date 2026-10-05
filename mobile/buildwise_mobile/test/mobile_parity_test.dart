import 'dart:convert';

import 'package:buildwise_mobile/core/api/api_client.dart';
import 'package:buildwise_mobile/features/auth/services/auth_service.dart';
import 'package:buildwise_mobile/features/operations/screens/agent_workflows_screen.dart';
import 'package:buildwise_mobile/features/operations/screens/dashboard_screen.dart';
import 'package:buildwise_mobile/features/operations/screens/delivery_receiving_screen.dart';
import 'package:buildwise_mobile/features/operations/screens/material_requests_screen.dart';
import 'package:buildwise_mobile/features/operations/services/operations_service.dart';
import 'package:buildwise_mobile/features/procurement/screens/quotation_comparison_screen.dart';
import 'package:buildwise_mobile/features/procurement/services/procurement_service.dart';
import 'package:buildwise_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class RejectedProcurementClient extends ApiClient {
  @override
  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async => http.Response(
    jsonEncode({
      'errors': {
        'SupplierIds': ['Select at least one supplier.'],
      },
    }),
    400,
  );
}

class ContractClient extends ApiClient {
  final calls = <Map<String, dynamic>>[];
  final responses = <String, Object>{};

  http.Response respond(
    String method,
    String path,
    Map<String, dynamic>? body,
    Duration? timeout,
  ) {
    calls.add({
      'method': method,
      'path': path,
      'body': body,
      'timeout': timeout,
    });
    return http.Response(
      jsonEncode(responses[path] ?? <String, dynamic>{}),
      200,
    );
  }

  @override
  Future<http.Response> get(String path, {Duration? timeout}) async =>
      respond('GET', path, null, timeout);
  @override
  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async => respond('POST', path, body, timeout);
  @override
  Future<http.Response> put(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async => respond('PUT', path, body, timeout);
  @override
  Future<http.Response> patch(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async => respond('PATCH', path, body, timeout);
}

class ParityOperations extends OperationsService {
  ParityOperations({this.role = 'SiteEngineer'});
  final String role;
  int dashboardReads = 0;
  final workflowQueries = <String>[];
  @override
  Future<Map<String, dynamic>> getDashboard() async {
    dashboardReads++;
    return {
      'primaryRole': role,
      'metrics': [
        {'key': 'activeRequests', 'label': 'Live requests', 'value': 12},
        {'key': 'activeNcrs', 'label': 'Live NCRs', 'value': 3},
      ],
      'tasks': [
        {
          'title': 'Open orders',
          'description': 'Track fulfilment',
          'route': '/purchase-orders',
        },
      ],
      'alerts': [
        {
          'title': 'Check quality',
          'detail': 'Defect reported',
          'route': '/non-conformances',
        },
      ],
      'activity': [
        {
          'title': 'Request submitted',
          'reference': 'MR-77',
          'relatedRecords': ['PO-9'],
          'outcome': 'Refused',
          'statusCode': 403,
          'occurredAtUtc': '2026-10-05T02:00:00Z',
        },
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> listNotifications({
    bool unreadOnly = false,
  }) async => [];
  @override
  Future<List<Map<String, dynamic>>> listMyRequests() async => [
    {
      'id': 77,
      'status': 'PendingApproval',
      'materialNames': ['Cement'],
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> listConfirmedOrders() async => [];
  @override
  Future<List<Map<String, dynamic>>> listDeliveries() async => [
    {'id': 9, 'deliveryReference': 'INV-9', 'status': 'Received', 'items': []},
  ];
  @override
  Future<Map<String, dynamic>> listAgentWorkflows({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    workflowQueries.add('$page:$pageSize:$status');
    return {
      'items': [
        {
          'id': page,
          'objective': 'Run $page',
          'status': 'Completed',
          'stepCount': 1,
        },
      ],
      'total': 11,
      'page': page,
    };
  }

  @override
  Future<Map<String, dynamic>> getAgentWorkflow(int id) async => {
    'workflow': {'id': id, 'finalOutcome': 'Verified result'},
    'steps': [
      {
        'agentRole': 'QualityRiskAnalysisAgent',
        'stepName': 'Analyze quality',
        'stepOrder': 1,
        'status': 'Completed',
        'structuredResult': '{"riskLevel":"High"}',
        'validationResult': '{"valid":true}',
      },
    ],
    'approvals': [
      {'decision': 'Approved', 'comment': 'Replacement verified'},
    ],
  };
}

class ParityAuth extends AuthService {
  ParityAuth(this.role);
  final String role;
  @override
  Future<Map<String, dynamic>?> currentUser() async => {
    'roles': [role],
    'fullName': 'Tester',
  };
}

class ComparisonService extends ProcurementService {
  @override
  Future<Map<String, dynamic>> getMaterialRequest(int id) async => {
    'id': id,
    'projectName': 'Riverside Apartments',
    'reason': 'Ground floor',
    'requiredDate': '2026-10-08',
    'items': [],
  };
  @override
  Future<Map<String, dynamic>?> getLatestWorkflow(int requestId) async =>
      getWorkflow(8);
  Map<String, dynamic>? decision;
  @override
  Future<List<Map<String, dynamic>>> listApprovedMaterialRequests() async => [
    {
      'id': 77,
      'materialNames': ['Cement'],
    },
  ];
  @override
  Future<Map<String, dynamic>> compareQuotations(int requestId) async => {
    'rows': [],
  };
  @override
  Future<Map<String, dynamic>> startWorkflow(int requestId) async => {
    'workflowId': 8,
  };
  @override
  Future<Map<String, dynamic>> getWorkflow(int id) async => {
    'id': id,
    'status': 'AwaitingApproval',
    'approvalStatus': 'Pending',
    'recommendation': {
      'recommendedSupplierName': 'Supplier A',
      'rationale': 'Lowest eligible offer',
    },
    'validation': {'isValid': true},
    'steps': [],
  };
  @override
  Future<Map<String, dynamic>> recordWorkflowDecision(
    int workflowId, {
    required String decision,
    String comment = '',
  }) async {
    this.decision = {'decision': decision, 'comment': comment};
    return {};
  }
}

void main() {
  group('Backend contracts shared with React', () {
    test(
      'procurement displays backend field validation instead of a generic 400',
      () async {
        await expectLater(
          ProcurementService(apiClient: RejectedProcurementClient())
              .sendRfqEmail(17, recipientEmail: 'supplier@example.test'),
          throwsA(
            predicate(
              (error) =>
                  error.toString().contains('Select at least one supplier.'),
            ),
          ),
        );
      },
    );
    test(
      'purchase-order envelopes produce visible rows and escape search',
      () async {
        final client = ContractClient();
        const path = '/purchase-orders?page=1&pageSize=20&search=A%26B';
        client.responses[path] = {
          'items': [
            {'id': 9},
          ],
          'total': 1,
        };
        final rows = await ProcurementService(apiClient: client)
            .listPurchaseOrders(search: 'A&B');
        expect(rows.single['id'], 9);
        expect(client.calls.single['path'], path);
      },
    );

    test('all supplier pages are reachable, including records after the first page', () async {
      final client = ContractClient();
      client.responses['/suppliers?page=1&pageSize=100'] = {
        'items': [
          {'id': 1},
        ],
        'total': 2,
        'pageSize': 1,
      };
      client.responses['/suppliers?page=2&pageSize=1'] = {
        'items': [
          {'id': 2},
        ],
        'total': 2,
        'pageSize': 1,
      };
      final result = await ProcurementService(apiClient: client)
          .listSuppliers();
      expect((result['items'] as List).map((row) => row['id']), [1, 2]);
    });

    test(
      'RFQ email uses the backend recipientEmail and customMessage contract',
      () async {
        final client = ContractClient();
        await ProcurementService(apiClient: client).sendRfqEmail(
          9,
          recipientEmail: 'supplier@example.test',
          customMessage: 'Please quote',
        );
        expect(client.calls.single['body'], {
          'recipientEmail': 'supplier@example.test',
          'customMessage': 'Please quote',
        });
      },
    );

    test('account activation uses PATCH and roles use PUT', () async {
      final client = ContractClient();
      final service = OperationsService(apiClient: client);
      await service.setUserActive(8, false);
      await service.setUserRoles(8, ['SiteManager']);
      expect(client.calls[0], containsPair('method', 'PATCH'));
      expect(client.calls[0]['body'], {'isActive': false});
      expect(client.calls[1], containsPair('method', 'PUT'));
      expect(client.calls[1]['body'], {
        'roles': ['SiteManager'],
      });
    });

    test('all four domain AI actions call the same backend routes with longer timeouts', () async {
      final client = ContractClient();
      final service = OperationsService(apiClient: client);
      await service.analyzeRequest(77);
      await service.analyzeDeliveryDiscrepancy(9);
      await service.analyzeQualityRisk(12);
      await ProcurementService(apiClient: client).startWorkflow(77);
      expect(client.calls.map((call) => call['path']), [
        '/agent/analyze-request/77',
        '/deliveries/9/discrepancy-analysis',
        '/quality-inspections/12/risk-analysis',
        '/material-requests/77/procurement-workflow',
      ]);
      expect(
        client.calls.every(
          (call) => call['timeout'] == const Duration(seconds: 90),
        ),
        isTrue,
      );
    });
  });

  testWidgets(
    'dashboard opens the correct routes and displays actual activity fields',
    (tester) async {
      final routes = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            service: ParityOperations(),
            onNavigate: routes.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Live requests'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Open orders'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Open orders'));
      await tester.ensureVisible(find.text('Check quality'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check quality'));
      await tester.scrollUntilVisible(
        find.textContaining('MR-77'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(routes, ['/purchase-orders', '/non-conformances']);
      expect(find.textContaining('PO-9'), findsOneWidget);
      expect(find.text('Refused'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final role in [
    'SiteEngineer',
    'SiteOfficer',
    'QualityInspector',
    'SiteManager',
    'ProcurementOfficer',
    'ProcurementManager',
    'Administrator',
  ]) {
    testWidgets(
      '$role lands on its role dashboard without loading hidden workspaces',
      (tester) async {
        final service = ParityOperations(role: role);
        await tester.pumpWidget(
          MaterialApp(
            home: MainAppShell(
              onSignOut: () {},
              authService: ParityAuth(role),
              operationsService: service,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(service.dashboardReads, 1);
        await tester.scrollUntilVisible(
          find.text('Open orders'),
          150,
          scrollable: find
              .descendant(
                of: find.byType(DashboardScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Open orders'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'site request authors have no manager-only AI or approval actions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MaterialRequestsScreen(
            service: ParityOperations(),
            autoRefresh: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cement'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Run AI Analysis'), findsNothing);
    },
  );

  testWidgets(
    'delivery history stays visible when there are no confirmed orders',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryReceivingScreen(
            autoRefresh: false,
            service: ParityOperations(),
            readOnly: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('DEL-9'), findsOneWidget);
      expect(find.text('Confirmed Purchase Order'), findsNothing);
    },
  );

  testWidgets(
    'agent history supports pagination and public structured results',
    (tester) async {
      final service = ParityOperations();
      await tester.pumpWidget(
        MaterialApp(home: AgentWorkflowsScreen(service: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(service.workflowQueries, ['1:10:all', '2:10:all']);
      await tester.tap(find.text('Workflow #2'));
      await tester.pumpAndSettle();
      expect(find.text('Structured result'), findsOneWidget);
      expect(find.text('Validation'), findsOneWidget);
      expect(find.text('Analyze quality'), findsOneWidget);
      expect(find.text('Human approval: Approved'), findsOneWidget);
    },
  );

  testWidgets(
    'an officer can run supplier analysis while the manager decision stays hidden',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuotationComparisonScreen(
            autoRefresh: false,
            service: ComparisonService(),
            canApprove: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comparison & AI Recommendation'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Re-run AI Analysis'));
      await tester.tap(find.text('Comparison & AI Recommendation'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Re-run AI Analysis'));
      await tester.tap(find.text('Re-run AI Analysis'));
      await tester.pumpAndSettle();
      expect(find.text('Recommended supplier: Supplier A'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
    },
  );

  testWidgets('procurement revision requires a real comment', (tester) async {
    final service = ComparisonService();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: QuotationComparisonScreen(autoRefresh: false, service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comparison & AI Recommendation'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Re-run AI Analysis'));
    await tester.tap(find.text('Re-run AI Analysis'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Request Revision'));
    await tester.tap(find.text('Request Revision'));
    await tester.pumpAndSettle();
    expect(service.decision, isNull);
    expect(
      find.text('Add a comment explaining what needs revision.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'manager approves the persisted officer recommendation without running analysis',
    (tester) async {
      final service = ComparisonService();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: QuotationComparisonScreen(
            autoRefresh: false,
            service: service,
            canRunAgent: false,
            canApprove: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comparison & AI Recommendation'));
      await tester.pumpAndSettle();
      expect(find.text('Re-run AI Analysis'), findsNothing);
      expect(find.text('Recommended supplier: Supplier A'), findsOneWidget);
      await tester.ensureVisible(find.text('Approve'));
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(service.decision?['decision'], 'Approve');
    },
  );
}
