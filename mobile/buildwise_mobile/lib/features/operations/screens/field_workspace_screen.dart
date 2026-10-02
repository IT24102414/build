import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/field_format.dart';
import '../../../core/widgets/field_messages.dart';
import '../../../core/widgets/error_widget.dart' as buildwise;
import '../../../core/widgets/widgets.dart' hide ErrorWidget;
import '../services/operations_service.dart';

/// The field workspace home.
///
/// This deliberately does **not** mirror the React dashboard. A site phone is not
/// a smaller web app: the only question worth answering on the home screen is
/// **"what do I need to do right now?"**
///
/// Each of the three field roles gets its own workspace, built from the same API
/// calls their own screens already use:
///
/// | Role      | Workspace answers                     |
/// |-----------|---------------------------------------|
/// | Engineer  | How many of my requests need chasing? |
/// | Officer   | What has arrived that I must receive? |
/// | Inspector | What is sitting un-inspected?         |
///
/// Nothing is fabricated: every count comes from a live response, and a failed
/// call shows an error with a retry rather than an empty workspace.
class FieldWorkspaceScreen extends StatefulWidget {
  const FieldWorkspaceScreen({super.key, required this.role, this.service});

  /// One of `SiteEngineer`, `SiteOfficer`, `QualityInspector`.
  final String role;

  final OperationsService? service;

  @override
  State<FieldWorkspaceScreen> createState() => _FieldWorkspaceScreenState();
}

class _FieldWorkspaceScreenState extends State<FieldWorkspaceScreen> {
  late final OperationsService _service = widget.service ?? OperationsService();
  bool _loading = true;
  String? _error;

  // Site Engineer
  List<Map<String, dynamic>> _requests = const [];

  // Site Officer
  List<Map<String, dynamic>> _orders = const [];

  // Quality Inspector. Deliveries pending inspection are derived in `_load`;
  // only the NCR list needs to survive the call.
  List<Map<String, dynamic>> _ncrs = const [];

  bool get _isEngineer => widget.role == 'SiteEngineer';
  bool get _isOfficer => widget.role == 'SiteOfficer';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isEngineer) {
        _requests = await _service.listMyRequests();
      } else if (_isOfficer) {
        _orders = await _service.listConfirmedOrders();
      } else {
        // Awaiting inspection == a delivery that has physically arrived and has
        // no inspection recorded against it yet. Derived from the deliveries the
        // API already returns rather than a new endpoint.
        final results = await Future.wait([
          _service.listDeliveries(),
          _service.listInspections(),
          _service.listNonConformances(),
        ]);
        _ncrs = results[2];
        _orders = results[0]
            .where((d) => _awaitingInspection(d, results[1]))
            .toList();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = FieldMessages.friendly(error.toString()));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// A delivery needs inspection when it has arrived and no inspection exists.
  bool _awaitingInspection(
    Map<String, dynamic> delivery,
    List<Map<String, dynamic>> inspections,
  ) {
    final status = delivery['status']?.toString();
    if (status != 'Received' && status != 'DiscrepancyReported') return false;
    final deliveryId = (delivery['id'] as num?)?.toInt();
    return !inspections.any(
      (i) => (i['deliveryId'] as num?)?.toInt() == deliveryId,
    );
  }
  // ------------------------------------------------------------- workspace

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Loading your work…'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('BuildWise')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: buildwise.ErrorWidget(
            title: 'Cannot load workspace',
            message: _error!,
            onRetry: _load,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('BuildWise')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: _isEngineer
              ? _engineerWorkspace()
              : _isOfficer
                  ? _officerWorkspace()
                  : _inspectorWorkspace(),
        ),
      ),
    );
  }

  /// Hands the user to the workspace tab for their role. The shell resolves the
  /// destination, so this screen never needs to know the tab layout.
  void _goToWorkspace() {
    // The navigator is a mixin on the shell's State, not a State subclass, so
    // walk the ancestors and ask each StatefulElement's state for one.
    context.visitAncestorElements((element) {
      if (element is StatefulElement) {
        final state = element.state;
        // `state` is typed State<StatefulWidget>, so test and call separately
        // rather than relying on promotion through the interface check.
        if (state is WorkspaceNavigator) {
          final navigator = state as WorkspaceNavigator;
          navigator.openWorkspace();
          return false; // stop walking
        }
      }
      return true; // keep walking
    });
  }

  // ---------------------------------------------------- Site Engineer

  int _countRequests(Set<String> statuses) =>
      _requests.where((r) => statuses.contains(r['status']?.toString())).length;

  List<Widget> _engineerWorkspace() {
    final pending = _countRequests({
      'PendingApproval',
      'RfqInProgress',
      'AwaitingProcurementApproval',
    });
    final approved = _countRequests({'Approved', 'PurchaseOrderCreated'});
    final revision = _countRequests({'RevisionRequested', 'Draft'});

    // Soonest required date first: that is what the site is waiting on.
    final recent = [..._requests]..sort(
          (a, b) => (a['requiredDate']?.toString() ?? '')
              .compareTo(b['requiredDate']?.toString() ?? ''),
        );

    return [
      const SectionHeader(title: 'My Requests'),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _CountTile(
              value: pending,
              label: 'Pending',
              tone: pending == 0 ? StatusTone.success : StatusTone.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CountTile(
              value: approved,
              label: 'Approved',
              tone: StatusTone.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CountTile(
              value: revision,
              label: 'Revision',
              tone: revision == 0 ? StatusTone.success : StatusTone.danger,
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      AppButton(
        label: '+  New Material Request',
        expand: true,
        onPressed: _goToWorkspace,
      ),
      const SizedBox(height: 22),
      const SectionHeader(title: 'Upcoming required dates'),
      const SizedBox(height: 8),
      if (recent.isEmpty)
        const AppCard(
          child: Text(
            'You have not raised any material requests yet. Create one and the '
            'Site Manager will review it on the web app.',
          ),
        )
      else
        ...recent.take(5).map(_requestCard),
    ];
  }

  Widget _requestCard(Map<String, dynamic> request) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          onTap: _goToWorkspace,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MR-${request['id'] ?? '—'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request['reason']?.toString() ?? 'Material request',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Required ${FieldFormat.date(request['requiredDate'])}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusChip(
                label: FieldFormat.humanize(request['status']?.toString()),
                tone: FieldFormat.statusTone(request['status']?.toString()),
              ),
            ],
          ),
        ),
      );
  // ---------------------------------------------------- Site Officer

  List<Widget> _officerWorkspace() => [
        const SectionHeader(title: 'Delivery Workspace'),
        const SizedBox(height: 8),
        _CountTile(
          value: _orders.length,
          label: 'Orders awaiting receipt',
          tone: _orders.isEmpty ? StatusTone.success : StatusTone.warning,
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Receive Delivery',
          expand: true,
          onPressed: _orders.isEmpty ? null : _goToWorkspace,
        ),
        const SizedBox(height: 22),
        const SectionHeader(title: 'Confirmed orders'),
        const SizedBox(height: 8),
        if (_orders.isEmpty)
          const AppCard(
            child: Text(
              'No confirmed purchase orders are waiting. An order appears here '
              'once procurement and the Procurement Manager complete it.',
            ),
          )
        else
          ..._orders.take(8).map(_orderCard),
      ];

  Widget _orderCard(Map<String, dynamic> order) {
    final items = (order['items'] as List<dynamic>?) ?? const [];
    final first = items.isEmpty ? null : items.first as Map<String, dynamic>;
    final material = first?['materialName']?.toString();
    final ordered = first?['orderedQuantity'];
    final unit =
        first?['materialUnit']?.toString() ?? first?['unit']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: _goToWorkspace,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'PO-${order['id'] ?? '—'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                StatusChip(
                  label: FieldFormat.humanize(order['status']?.toString()),
                  tone: StatusTone.success,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (material != null)
              Text(
                material,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            if (ordered != null) ...[
              const SizedBox(height: 2),
              Text('$ordered $unit ordered'),
            ],
            const SizedBox(height: 4),
            Text(
              order['expectedDeliveryDate'] == null
                  ? (order['supplierName']?.toString() ?? '')
                  : 'Expected ${FieldFormat.date(order['expectedDeliveryDate'])}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------- Quality Inspector

  int get _openNcrs =>
      _ncrs.where((ncr) => ncr['status']?.toString() != 'Closed').length;

  List<Widget> _inspectorWorkspace() => [
        const SectionHeader(title: 'Inspection Workspace'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _CountTile(
                value: _orders.length,
                label: 'Awaiting inspection',
                tone: _orders.isEmpty ? StatusTone.success : StatusTone.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CountTile(
                value: _openNcrs,
                label: 'Open NCRs',
                tone: _openNcrs == 0 ? StatusTone.success : StatusTone.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Start Inspection',
          expand: true,
          onPressed: _goToWorkspace,
        ),
        const SizedBox(height: 22),
        const SectionHeader(title: 'Awaiting inspection'),
        const SizedBox(height: 8),
        if (_orders.isEmpty)
          const AppCard(
            child: Text(
              'Nothing is waiting for inspection. A delivery appears here once the '
              'Site Officer has recorded it as received.',
            ),
          )
        else
          ..._orders.take(8).map(_pendingInspectionCard),
      ];

  Widget _pendingInspectionCard(Map<String, dynamic> delivery) {
    final status = delivery['status']?.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: _goToWorkspace,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DEL-${delivery['id'] ?? '—'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    delivery['supplierName']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            StatusChip(
              label: FieldFormat.humanize(status),
              tone: status == 'DiscrepancyReported'
                  ? StatusTone.danger
                  : StatusTone.warning,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the workspace home hand the user to the tab holding their work,
/// without this screen needing to know the shell's tab layout.
abstract class WorkspaceNavigator {
  void openWorkspace();
}

/// One headline number, e.g. "3 Pending".
class _CountTile extends StatelessWidget {
  const _CountTile({required this.value, required this.label, required this.tone});

  final int value;
  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _toneColor(tone),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  static Color _toneColor(StatusTone tone) => switch (tone) {
        StatusTone.success => AppColors.success,
        StatusTone.warning => AppColors.warning,
        StatusTone.danger => AppColors.danger,
        StatusTone.info => AppColors.primary,
        StatusTone.neutral => AppColors.textMuted,
      };
}