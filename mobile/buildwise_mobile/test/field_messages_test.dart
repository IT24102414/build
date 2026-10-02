import 'package:buildwise_mobile/core/widgets/field_format.dart';
import 'package:buildwise_mobile/core/widgets/field_messages.dart';
import 'package:buildwise_mobile/core/widgets/status_chip.dart';
import 'package:flutter_test/flutter_test.dart';

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
}