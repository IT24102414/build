import 'package:flutter/material.dart';

import '../../../core/widgets/error_widget.dart' as buildwise;
import '../../../core/widgets/field_format.dart';
import '../../../core/widgets/field_messages.dart';
import '../../../core/widgets/widgets.dart' hide ErrorWidget;
import '../services/procurement_service.dart';

/// Purchase order register — mirrors the web app's Purchase Orders page.
///
/// A purchase order here is the *end* of the procurement chain, never a
/// shortcut: the quotation agent recommends a supplier, a manager accepts or
/// overrides at the approval gate, and only an approved workflow can become an
/// order. This screen reports and filters; it never creates one, which is what
/// keeps the human gate meaningful.
class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key, this.service});

  final ProcurementService? service;

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final _service = ProcurementService();

  /// Same status vocabulary the web filter offers.
  static const List<String?> _statuses = [
    null,
    'Created',
    'Confirmed',
    'InProgress',
    'Completed',
    'Cancelled',
  ];

  List<Map<String, dynamic>> _orders = const [];
  String? _status;
  bool _loading = true;
  String? _error;

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
      final rows = await _api.listPurchaseOrders(status: _status);
      if (mounted) setState(() => _orders = rows);
    } catch (e) {
      if (mounted) setState(() => _error = FieldMessages.friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Purchase Orders'),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? buildwise.ErrorWidget(message: _error!, onRetry: _load)
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: AppDropdown(
                          label: 'Status',
                          value: _status,
                          items: _statuses.map((s) => s ?? 'all').toList(),
                          itemLabels: _statuses
                              .map((s) => s ?? 'All statuses')
                              .toList(),
                          onChanged: (value) {
                            setState(
                              () => _status = value == 'all' ? null : value,
                            );
                            _load();
                          },
                        ),
                      ),
                      Expanded(
                        child: _orders.isEmpty
                            ? const EmptyStateWidget(
                                title: 'No purchase orders yet',
                                message:
                                    'A purchase order appears here once a manager '
                                    'approves a procurement recommendation.',
                              )
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _orders.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, index) =>
                                      _orderCard(_orders[index]),
                                ),
                              ),
                      ),
                    ],
                  ),
      );

  Widget _orderCard(Map<String, dynamic> order) {
    final id = (order['id'] as num?)?.toInt();
    final status = order['status']?.toString();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PO${id == null ? '' : '#$id'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              StatusChip(
                label: FieldFormat.humanize(status),
                tone: FieldFormat.statusTone(status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order['supplierName'] ?? 'Supplier'} · '
            '${order['projectName'] ?? ''}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (order['totalAmount'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Total ${order['totalAmount']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}