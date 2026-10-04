import 'package:flutter/material.dart';

import '../../../core/widgets/error_widget.dart' as buildwise;
import '../../../core/widgets/field_format.dart';
import '../../../core/widgets/field_messages.dart';
import '../../../core/widgets/widgets.dart' hide ErrorWidget;
import '../services/procurement_service.dart';

/// Records a supplier's returned quotation against an approved material request.
///
/// The mobile counterpart of the web app's `QuotationEntryForm`, pointed at the
/// identical endpoint (`POST /material-requests/{id}/quotations`) and the same
/// `CreateQuotationDto` shape, so a quotation keyed in here is indistinguishable
/// from one keyed in on the web.
///
/// The process is unchanged by moving the keyboard to a phone: BuildWise still
/// emails the RFQ, the supplier still replies by email, and the officer still
/// keys in what came back. Nothing is captured automatically.
class QuotationEntryScreen extends StatefulWidget {
  const QuotationEntryScreen({super.key, this.service});

  final ProcurementService? service;

  @override
  State<QuotationEntryScreen> createState() => _QuotationEntryScreenState();
}

class _QuotationEntryScreenState extends State<QuotationEntryScreen> {
  final _service = ProcurementService();

  List<Map<String, dynamic>> _requests = const [];
  List<Map<String, dynamic>> _suppliers = const [];
  Map<String, dynamic>? _request;
  int? _supplierId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // One quantity/unit-price pair per request line, keyed by line id. Each entry
  // owns a controller so the field keeps what the officer typed; a bare `Text`
  // with an `initialValue` would be rebuilt away on every setState.
  final Map<int, TextEditingController> _quantities = {};
  final Map<int, TextEditingController> _prices = {};

  @override
  void dispose() {
    _clearLines();
    super.dispose();
  }

  TextEditingController _controllerFor(
    Map<int, TextEditingController> store,
    int id,
  ) => store.putIfAbsent(id, TextEditingController.new);

  /// Drops the typed lines when the request changes or a save succeeds.
  ///
  /// The controllers are disposed, not just dereferenced, so switching requests
  /// repeatedly does not leak a controller per line.
  void _clearLines() {
    for (final controller in [..._quantities.values, ..._prices.values]) {
      controller.dispose();
    }
    _quantities.clear();
    _prices.clear();
  }

  DateTime _quotationDate = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  DateTime? _promisedDelivery;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ProcurementService get _api => widget.service ?? _service;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Approved requests are the only ones a supplier can be quoted against,
      // and only an active supplier can be recorded here.
      final results = await Future.wait([
        _api.listApprovedMaterialRequests(),
        _api.listSuppliers(pageSize: 200),
      ]);
      if (!mounted) return;
      final payload = results[1];
      final suppliers = payload is Map
          ? ((payload['items'] as List<dynamic>?) ?? const [])
          : (payload as List<dynamic>? ?? const []);
      setState(() {
        _requests = results[0] as List<Map<String, dynamic>>;
        _suppliers = suppliers.cast<Map<String, dynamic>>();
        _request = _requests.isEmpty ? null : _requests.first;
      });
    } catch (e) {
      if (mounted) setState(() => _error = FieldMessages.friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  List<Map<String, dynamic>> get _items =>
      (_request?['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
      const [];

  /// The same running total the web form shows, so the officer sees the same
  /// number in both clients.
  double get _total {
    var sum = 0.0;
    for (final item in _items) {
      final id = (item['id'] as num).toInt();
      final qty = double.tryParse(_quantities[id]?.text ?? '') ?? 0;
      final price = double.tryParse(_prices[id]?.text ?? '') ?? 0;
      sum += qty * price;
    }
    return sum;
  }

  /// Only lines the officer actually priced are sent, matching the web form's
  /// `filter((line) => line.quantity > 0 || line.unitPrice > 0)`.
  List<Map<String, dynamic>> get _quoteItems {
    final lines = <Map<String, dynamic>>[];
    for (final item in _items) {
      final id = (item['id'] as num).toInt();
      final quantity = double.tryParse(_quantities[id]?.text ?? '') ?? 0;
      final unitPrice = double.tryParse(_prices[id]?.text ?? '') ?? 0;
      if (quantity > 0 || unitPrice > 0) {
        lines.add({
          'materialRequestItemId': id,
          'quantity': quantity,
          'unitPrice': unitPrice,
        });
      }
    }
    return lines;
  }

  Future<void> _save() async {
    if (_supplierId == null) {
      setState(() => _error = 'Select a supplier.');
      return;
    }
    final lines = _quoteItems;
    if (lines.isEmpty) {
      setState(() => _error = 'Enter quantity and unit price for at least one item.');
      return;
    }
    if (lines.any((l) => (l['quantity'] as double) <= 0 || (l['unitPrice'] as double) < 0)) {
      setState(() => _error = 'Quantity must be positive and unit price cannot be negative.');
      return;
    }
    final requestId = (_request!['id'] as num).toInt();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.createQuotation(
        requestId,
        supplierId: _supplierId!,
        quotationDate: _iso(_quotationDate),
        validUntil: _iso(_validUntil),
        promisedDeliveryDate: _promisedDelivery == null ? null : _iso(_promisedDelivery!),
        items: lines,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quotation recorded.')),
      );
      setState(() {
        _supplierId = null;
        _clearLines();
      });
    } catch (e) {
      if (mounted) setState(() => _error = FieldMessages.friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(
    DateTime initial,
    ValueChanged<DateTime> onPicked, {
    String? help,
  }) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: initial,
      helpText: help,
    );
    if (picked != null) onPicked(picked);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Record quotation'),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _requests.isEmpty
                ? buildwise.ErrorWidget(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SectionHeader(title: 'What the supplier quoted'),
                      const SizedBox(height: 8),
                      AppDropdown(
                        label: 'Approved material request',
                        value: _request == null
                            ? null
                            : (_request!['id'] as num).toString(),
                        items: _requests
                            .map((r) => (r['id'] as num).toString())
                            .toList(),
                        // Label each option with the material, not the bare id.
                        itemLabels:
                            _requests.map(FieldFormat.materialRequestLabel).toList(),
                        onChanged: (value) {
                          setState(() {
                            _clearLines();
                            _request = value == null
                                ? null
                                : _requests.firstWhere(
                                    (r) => (r['id'] as num).toString() == value,
                                  );
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      AppDropdown(
                        label: 'Supplier',
                        value: _supplierId?.toString(),
                        items: _suppliers
                            .map((s) => (s['id'] as num).toString())
                            .toList(),
                        itemLabels: _suppliers
                            .map((s) => s['name']?.toString() ?? 'Supplier')
                            .toList(),
                        onChanged: (value) => setState(
                          () => _supplierId =
                              value == null ? null : int.parse(value),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionHeader(title: 'Lines'),
                      const SizedBox(height: 8),
                      if (_items.isEmpty)
                        const AppCard(
                          child: Text('Select a request to see its lines.'),
                        )
                      else
                        ..._items.map(_lineCard),
                      const SizedBox(height: 16),
                      AppCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Quotation total'),
                            Text(
                              _total.toStringAsFixed(2),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionHeader(title: 'Dates'),
                      const SizedBox(height: 8),
                      _dateTile(
                        'Quotation date',
                        _quotationDate,
                        () => _pickDate(
                          _quotationDate,
                          (v) => setState(() => _quotationDate = v),
                          help: 'Quotation date',
                        ),
                      ),
                      _dateTile(
                        'Valid until',
                        _validUntil,
                        () => _pickDate(
                          _validUntil,
                          (v) => setState(() => _validUntil = v),
                          help: 'Valid until',
                        ),
                      ),
                      _dateTile(
                        'Promised delivery',
                        _promisedDelivery,
                        () => _pickDate(
                          _promisedDelivery ?? DateTime.now(),
                          (v) => setState(() => _promisedDelivery = v),
                          help: 'Promised delivery',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 16),
                      AppButton(
                        label: _saving ? 'Saving…' : 'Save quotation',
                        expand: true,
                        onPressed: _saving || _items.isEmpty ? null : _save,
                      ),
                    ],
                  ),
      );
  Widget _lineCard(Map<String, dynamic> item) {
    final id = (item['id'] as num).toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item['materialName'] ?? 'Material'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              'Requested ${item['requestedQuantity'] ?? 0} ${item['unit'] ?? ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Quantity',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    controller: _controllerFor(_quantities, id),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextField(
                    label: 'Unit price',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    controller: _controllerFor(_prices, id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTile(String label, DateTime? value, VoidCallback onTap) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: Text(
          value == null ? 'Not set' : _iso(value),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        onTap: onTap,
      );
}
