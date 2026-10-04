import 'package:buildwise_mobile/core/widgets/app_button.dart';
import 'package:buildwise_mobile/features/procurement/screens/quotation_entry_screen.dart';
import 'package:buildwise_mobile/features/procurement/services/procurement_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what a supplier returned, in the browser's pockets and on a phone.
///
/// The mobile form must produce the same `CreateQuotationDto` the web form posts
/// to the same endpoint, so these tests pin the request shape rather than the
/// layout. The process is unchanged: BuildWise emails the RFQ, the supplier
/// replies by email, and the officer keys the numbers in either client.
class FakeProcurementService extends ProcurementService {
  Map<String, dynamic>? postedQuotation;

  @override
  Future<List<Map<String, dynamic>>> listApprovedMaterialRequests() async => [
        {
          'id': 77,
          'projectName': 'Kandy Heights - Tower A',
          'items': [
            {
              'id': 7701,
              'materialName': 'Concrete Blocks',
              'unit': 'units',
              'requestedQuantity': 500,
            },
          ],
        },
      ];

  @override
  Future<Map<String, dynamic>> listSuppliers({int pageSize = 100}) async => {
        'items': [
          {'id': 1, 'name': 'Cement Co'},
          {'id': 2, 'name': 'BuildMart'},
        ],
      };

  @override
  Future<Map<String, dynamic>> createQuotation(
    int requestId, {
    required int supplierId,
    required String quotationDate,
    required String validUntil,
    required List<Map<String, dynamic>> items,
    String? promisedDeliveryDate,
    int? rfqId,
    double transportCharge = 0,
    String? paymentTerms,
  }) async {
    postedQuotation = {
      'requestId': requestId,
      'supplierId': supplierId,
      'quotationDate': quotationDate,
      'validUntil': validUntil,
      'promisedDeliveryDate': promisedDeliveryDate,
      'items': items,
    };
    return {'id': 1};
  }
}

Future<void> _pumpForm(
  WidgetTester tester,
  FakeProcurementService service,
) async {
  await tester.pumpWidget(
    MaterialApp(home: QuotationEntryScreen(service: service)),
  );
  // Bounded pumps: there is no live API behind a widget test.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Scrolls the form to the bottom so the save button is on-screen.
///
/// The default widget-test viewport is 800x600, which is shorter than the form,
/// so the save button is off-screen and `tap` cannot reach it.
Future<void> _tapSave(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.widgetWithText(AppButton, 'Save quotation'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.widgetWithText(AppButton, 'Save quotation'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Opens the supplier dropdown and picks [name].
Future<void> _pickSupplier(WidgetTester tester, String name) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text(name).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('Quotation entry mirrors the web form', () {
    testWidgets('loads approved requests and their lines', (tester) async {
      await _pumpForm(tester, FakeProcurementService());

      expect(find.text('Record quotation'), findsOneWidget);
      // The request's single line is rendered with its requested quantity.
      expect(find.text('Concrete Blocks'), findsOneWidget);
      expect(find.text('Requested 500 units'), findsOneWidget);
      expect(find.text('Quotation total'), findsOneWidget);
    });

    testWidgets('refuses to save without a supplier', (tester) async {
      final service = FakeProcurementService();
      await _pumpForm(tester, service);

      await _tapSave(tester);

      expect(find.text('Select a supplier.'), findsOneWidget);
      expect(service.postedQuotation, isNull);
    });

    testWidgets('refuses to save when no line is priced', (tester) async {
      final service = FakeProcurementService();
      await _pumpForm(tester, service);
      await _pickSupplier(tester, 'Cement Co');

      await _tapSave(tester);

      expect(
        find.text('Enter quantity and unit price for at least one item.'),
        findsOneWidget,
      );
      expect(service.postedQuotation, isNull);
    });

    testWidgets('posts the same payload shape the web form posts',
        (tester) async {
      final service = FakeProcurementService();
      await _pumpForm(tester, service);
      await _pickSupplier(tester, 'BuildMart');

      // Price the one line.
      await tester.enterText(
        find.widgetWithText(TextField, 'Quantity').first,
        '450',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Unit price').first,
        '2.50',
      );
      await tester.pump();

      await _tapSave(tester);

      final posted = service.postedQuotation;
      expect(posted, isNotNull);
      expect(posted!['requestId'], 77);
      expect(posted['supplierId'], 2);
      expect(posted['items'], hasLength(1));
      // materialRequestItemId is the request *line* id, not the request id.
      expect(posted['items'].first['materialRequestItemId'], 7701);
      expect(posted['items'].first['quantity'], 450.0);
      expect(posted['items'].first['unitPrice'], 2.5);
    });
  });
}
