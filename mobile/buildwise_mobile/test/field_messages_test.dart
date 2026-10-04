import 'package:buildwise_mobile/core/widgets/app_button.dart';
import 'package:buildwise_mobile/core/widgets/field_format.dart';
import 'package:buildwise_mobile/core/widgets/field_messages.dart';
import 'package:buildwise_mobile/core/widgets/status_chip.dart';
import 'package:buildwise_mobile/features/operations/screens/material_request_review_screen.dart';
import 'package:buildwise_mobile/features/operations/services/operations_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the decision the review screen hands to the service, so a test can
/// assert the exact wire values instead of guessing at them.
class RecordingOperationsService extends OperationsService {
  RecordingOperationsService(this.onDecide);

  /// Receives `(decision, comments)` exactly as the review screen sends them.
  final Map<String, dynamic> Function(String decision, String? comments) onDecide;

  Map<String, dynamic>? lastDetail;

  @override
  Future<Map<String, dynamic>> getMaterialRequestDetail(int id) async =>
      lastDetail ?? <String, dynamic>{'id': id};

  @override
  Future<Map<String, dynamic>> decideMaterialRequest(
    int id, {
    required String decision,
    String? comments,
  }) async =>
      onDecide(decision, comments);

  @override
  Future<Map<String, dynamic>> analyzeRequest(int materialRequestId) async =>
      <String, dynamic>{
        'requestId': materialRequestId,
        'flags': <String>[],
        'status': 'Analyzed',
      };
}

void main() {
  group('FieldMessages — a field user never sees a raw exception', () {
    test('turns a socket failure into an actionable message', () {
      final message = FieldMessages.friendly(
          'Exception: SocketException: Connection failed (OS Error: No route to host)');
      expect(message, contains('No internet connection'));
      expect(message.toLowerCase(), isNot(contains('socket')));
      expect(message.toLowerCase(), isNot(contains('os error')));
    });

    test('turns a client failure into an actionable message', () {
      expect(
        FieldMessages.friendly('Exception: ClientException: Connection closed'),
        contains('No internet connection'),
      );
    });

    test('explains a timeout instead of showing it', () {
      final message = FieldMessages.friendly('TimeoutException: Future not completed');
      expect(message, contains('slow'));
      expect(message.toLowerCase(), isNot(contains('future')));
    });

    test('tells the user to sign in again on 401', () {
      expect(
        FieldMessages.friendly('Exception: (401) Unauthenticated'),
        contains('sign in again'),
      );
    });

    test('explains a permission refusal on 403', () {
      expect(
        FieldMessages.friendly('Exception: (403) Forbidden'),
        contains('permission'),
      );
    });

    test('flags an already-submitted 409 rather than retrying blindly', () {
      final message = FieldMessages.friendly('Exception: (409) Conflict');
      expect(message, contains('already submitted'));
    });

    test('passes a real server message through unchanged', () {
      // The backend's own validation text is more useful than anything we could
      // invent, so it must survive.
      expect(
        FieldMessages.friendly(
            'Exception: Received and damaged quantities cannot be negative.'),
        'Received and damaged quantities cannot be negative.',
      );
    });

    test('never returns an empty message', () {
      expect(FieldMessages.friendly(''), isNotEmpty);
      expect(FieldMessages.friendly('Exception: '), isNotEmpty);
    });

    test('names the action while submitting', () {
      expect(FieldMessages.submitting('request'), 'Submitting request…');
      expect(FieldMessages.submitting('delivery'), 'Submitting delivery…');
    });
  });

  group('FieldFormat — consistent field display', () {
    test('formats an ISO date for a site screen', () {
      expect(FieldFormat.date('2026-10-08'), '08/10/2026');
    });

    test('renders a missing date as a dash rather than throwing', () {
      expect(FieldFormat.date(null), '—');
      expect(FieldFormat.date(''), '—');
    });

    test('passes an unparseable date through instead of hiding it', () {
      expect(FieldFormat.date('sometime'), 'sometime');
    });

    test('humanizes a backend status name', () {
      expect(FieldFormat.humanize('PendingApproval'), 'Pending Approval');
      expect(FieldFormat.humanize('DiscrepancyReported'), 'Discrepancy Reported');
    });

    test('humanizes a missing status safely', () {
      expect(FieldFormat.humanize(null), 'Unknown');
      expect(FieldFormat.humanize(''), 'Unknown');
    });

    test('maps statuses to the same tones the web client uses', () {
      expect(FieldFormat.statusTone('Approved'), StatusTone.success);
      expect(FieldFormat.statusTone('Rejected'), StatusTone.danger);
      expect(FieldFormat.statusTone('DiscrepancyReported'), StatusTone.danger);
      expect(FieldFormat.statusTone('PendingApproval'), StatusTone.warning);
      expect(FieldFormat.statusTone('SomethingNew'), StatusTone.neutral);
    });
  });

  // The material is what a request row is about. Before `materialNames` reached
  // the summary DTO the list could only render "Request #77 · 1 item(s)", which
  // gives a site user nothing to act on.
  group('FieldFormat.materialRequestLabel names the material', () {
    test('leads with the material name from the API', () {
      expect(
        FieldFormat.materialRequestLabel({
          'id': 77,
          'itemCount': 1,
          'materialNames': ['Concrete Blocks'],
        }),
        'Concrete Blocks',
      );
    });

    test('joins several lines in order', () {
      expect(
        FieldFormat.materialRequestLabel({
          'itemCount': 3,
          'materialNames': ['Cement (50kg bag)', 'Steel Rods', 'Bricks'],
        }),
        'Cement (50kg bag) · Steel Rods · Bricks',
      );
    });

    test('ignores blank names rather than printing an empty row', () {
      expect(
        FieldFormat.materialRequestLabel({
          'itemCount': 2,
          'materialNames': ['Cement (50kg bag)', '   '],
        }),
        'Cement (50kg bag)',
      );
    });

    test('falls back to the reason when the server sent no names', () {
      // An older API, or a build served before the field existed.
      expect(
        FieldFormat.materialRequestLabel({
          'id': 12,
          'itemCount': 1,
          'reason': 'Urgent top-up',
        }),
        'Urgent top-up',
      );
    });

    test('falls back to a count, then to a generic label', () {
      expect(
        FieldFormat.materialRequestLabel({'id': 3, 'itemCount': 1}),
        '1 material',
      );
      expect(
        FieldFormat.materialRequestLabel({'id': 4, 'itemCount': 5}),
        '5 materials',
      );
      expect(FieldFormat.materialRequestLabel({'id': 5}), 'Material request');
    });

    test('never returns an empty string', () {
      for (final request in <Map<String, dynamic>>[
        {'id': 1},
        {'id': 2, 'itemCount': 0},
        {'id': 3, 'materialNames': <String>[]},
        {'id': 4, 'reason': '   '},
        {'id': 5, 'itemCount': 0, 'reason': null, 'materialNames': null},
      ]) {
        expect(FieldFormat.materialRequestLabel(request).trim(), isNotEmpty);
      }
    });
  });

  // The mobile decision call once posted to `/material-requests/{id}/decision`,
  // which does not exist and returned 404 — every Approve/Reject tap failed
  // silently while the web app used `/approval`. These drive the real review
  // screen and capture what it hands the service.
  group('Approval decisions match the web app contract', () {
    /// Reset per test: `captured` is written by the fake service, and leaking a
    // value across tests would make a blocked decision look like it posted.
    Map<String, dynamic>? captured;

    setUp(() => captured = null);

    final detail = {
      'id': 41,
      'projectName': 'Riverside Apartments — Block C',
      'status': 'PendingApproval',
      'priority': 'High',
      'requiredDate': '2026-11-10',
      'reason': 'Structural pour',
      'items': [
        {
          'id': 4101,
          'materialName': 'Cement (50kg bag)',
          'requestedQuantity': 250,
          'unit': 'bags',
        },
      ],
    };

    /// Posts to `/material-requests/{id}/approval` and records the arguments.
    Future<Map<String, dynamic>> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final service = RecordingOperationsService((decision, comments) {
        captured = {'decision': decision, 'comments': comments};
        return {'id': 1};
      });

      await tester.pumpWidget(
        MaterialApp(home: MaterialRequestReviewScreen(detail: detail, service: service)),
      );
      await tester.pumpAndSettle();
      return service.lastDetail ?? detail;
    }

    /// Scrolls to [label] and taps it. The form is taller than the test viewport.
    Future<void> tapDecision(WidgetTester tester, String label) async {
      final button = find.widgetWithText(AppButton, label);
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('approve posts "Approved" with no comment', (tester) async {
      await pump(tester);

      await tapDecision(tester, 'Approve');

      expect(captured, isNotNull);
      expect(captured!['decision'], 'Approved');
      // The web sends `comments || null`, not an empty string.
      expect(captured!['comments'], isNull);
    });

    testWidgets('reject is blocked until a comment is written', (tester) async {
      await pump(tester);

      await tapDecision(tester, 'Reject');

      // The server hard-blocks a commentless rejection, so the screen must too.
      expect(
        find.text('A comment is required when rejecting a request.'),
        findsOneWidget,
      );
      expect(captured, isNull);
    });

    testWidgets('revision is blocked until a comment is written', (tester) async {
      await pump(tester);

      await tapDecision(tester, 'Request revision');

      expect(
        find.text('Add a comment explaining what needs to be revised.'),
        findsOneWidget,
      );
      expect(captured, isNull);
    });

    testWidgets('a commented reject posts "Rejected" with the comment',
        (tester) async {
      await pump(tester);

      final comment = find.widgetWithText(TextField, 'Comment');
      await tester.scrollUntilVisible(
        comment,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(comment, 'Wrong material grade.');
      await tester.pump();

      await tapDecision(tester, 'Reject');

      expect(captured!['decision'], 'Rejected');
      expect(captured!['comments'], 'Wrong material grade.');
    });

    testWidgets('shows what the site asked for before deciding',
        (tester) async {
      await pump(tester);

      expect(find.text('Material Request #41'), findsOneWidget);
      expect(find.text('Cement (50kg bag)'), findsOneWidget);
      expect(find.text('250 bags'), findsOneWidget);
      expect(find.text('Structural pour'), findsOneWidget);
    });
  });

  // The approver register once fetched only `PendingApproval` + `Approved`, so a
  // Cancelled or RevisionRequested row was invisible. The web loads `status=all`
  // and filters client-side, and these pin that the mobile register matches.
  group('The approver register holds every request, not just pending ones', () {
    final register = <Map<String, dynamic>>[
      {
        'id': 41,
        'projectName': 'Riverside Apartments — Block C',
        'status': 'PendingApproval',
        'priority': 'High',
        'itemCount': 1,
        'materialNames': ['Cement (50kg bag)'],
        'requestedByName': 'Sam SiteEngineer',
      },
      {
        'id': 42,
        'projectName': 'Kandy Heights — Tower A',
        'status': 'Approved',
        'priority': 'Normal',
        'itemCount': 2,
        'materialNames': ['Concrete Blocks'],
        'requestedByName': 'Nimal SiteOfficer',
      },
      {
        'id': 43,
        'projectName': 'Riverside Apartments — Block C',
        'status': 'Cancelled',
        'priority': 'Low',
        'itemCount': 1,
        'materialNames': ['Steel Rods'],
        'requestedByName': 'Sam SiteEngineer',
      },
      {
        'id': 44,
        'projectName': 'Kandy Heights — Tower A',
        'status': 'RevisionRequested',
        'priority': 'Urgent',
        'itemCount': 3,
        'materialNames': ['Bricks', 'Cement (50kg bag)'],
        'requestedByName': 'Nimal SiteOfficer',
      },
    ];

    test('every status the backend can return is present in the register', () {
      final statuses = register.map((r) => r['status']).toSet();
      // Cancelled and RevisionRequested are exactly the rows the old
      // pending+approved fetch could never show an approver.
      expect(statuses.contains('Cancelled'), isTrue);
      expect(statuses.contains('RevisionRequested'), isTrue);
      expect(statuses.length, 4);
    });

    test('each row can name the requester, project and material', () {
      for (final request in register) {
        expect(request['requestedByName'], isNotNull, reason: '${request['id']}');
        expect(request['projectName'], isNotNull);
        expect(
          FieldFormat.materialRequestLabel(request),
          isNot(contains('Request #')),
          reason: '${request['id']}',
        );
      }
    });

    test('a request with no requester still renders', () {
      // An older row, or one whose user was removed. The row must not break.
      final row = <String, dynamic>{
        'id': 45,
        'projectName': 'Project',
        'status': 'Approved',
        'itemCount': 1,
        'materialNames': ['Cement (50kg bag)'],
        'requestedByName': null,
      };
      expect(FieldFormat.materialRequestLabel(row), 'Cement (50kg bag)');
      expect(row['requestedByName']?.toString() ?? '', isEmpty);
    });
  });
}