import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/field_format.dart';

import '../../../core/widgets/error_widget.dart' as buildwise;
import '../../../core/widgets/widgets.dart' hide ErrorWidget;
import '../services/operations_service.dart';

/// Role-aware dashboard, mirroring the web app's DashboardPage.
///
/// The same three metric keys are chosen per role from the backend's
/// `/dashboard` response, so mobile and web show the same headline numbers.
///
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.roles = const [],
    this.service,
    this.onNavigate,
  });

  final List<String> roles;
  final OperationsService? service;
  final ValueChanged<String>? onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  final _service = OperationsService();
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _load(background: true);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(background: true);
  }

  Future<void> _load({bool background = false}) async {
    if (!background) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await (widget.service ?? _service).getDashboard();
      if (mounted) setState(() => _dashboard = data);
    } catch (e) {
      if (mounted && !background) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && !background) setState(() => _loading = false);
    }
  }

  /// Headline metrics per role, copied from the web page so both clients agree.
  List<String> _metricKeys(String role) => switch (role) {
    'SiteEngineer' => const ['activeRequests', 'awaitingProcurement'],
    'SiteOfficer' => const [
      'deliveriesExpectedToday',
      'deliveriesReconciled',
      'discrepanciesLogged',
    ],
    'ProcurementOfficer' => const [
      'awaitingProcurement',
      'activeRfqs',
      'quotationsToday',
    ],
    'ProcurementManager' => const [
      'proposalsAwaitingApproval',
      'confirmedPurchaseOrders',
      'monthlySpend',
    ],
    'QualityInspector' => const [
      'deliveriesAwaitingQuality',
      'qualityPassRate',
      'activeNcrs',
    ],
    'SiteManager' => const [
      'proposalsAwaitingApproval',
      'confirmedPurchaseOrders',
      'activeNcrs',
    ],
    'Administrator' => const [
      'activeRequests',
      'activeNcrs',
      'proposalsAwaitingApproval',
    ],
    _ => const [
      'activeRequests',
      'awaitingProcurement',
      'proposalsAwaitingApproval',
    ],
  };

  static String _title(String role) => switch (role) {
    'SiteEngineer' => 'Site Engineer Dashboard',
    'SiteOfficer' => 'Site Officer Dashboard',
    'ProcurementOfficer' => 'Procurement Officer Dashboard',
    'ProcurementManager' => 'Procurement Manager Dashboard',
    'QualityInspector' => 'Quality Inspector Dashboard',
    'SiteManager' => 'Site Manager Dashboard',
    'Administrator' => 'Administrator Dashboard',
    _ => 'BuildWise Dashboard',
  };

  static String _description(String role) => switch (role) {
    'SiteEngineer' =>
      'Track your site material demand and request approval progress.',
    'SiteOfficer' =>
      "Reconcile today's arrivals and record delivery evidence at the site.",
    'ProcurementOfficer' =>
      'Move approved requests through RFQ, quotation and agent evaluation.',
    'ProcurementManager' => 'Review recommendations at the human approval boundary and oversee purchasing.',
    'QualityInspector' =>
      'Inspect received materials and manage corrective actions for open NCRs.',
    'SiteManager' => 'Monitor procurement approvals, site delivery and operational exceptions.',
    'Administrator' => 'Monitor system-wide operational activity and access the administration workspace.',
    _ => 'Your role-aware operations overview.',
  };

  String get _primaryRole =>
      (_dashboard?['primaryRole'] as String?) ??
      (widget.roles.isNotEmpty ? widget.roles.first : 'TeamMember');

  @override
  Widget build(BuildContext context) {
    final role = _primaryRole;
    final metrics = (_dashboard?['metrics'] as List<dynamic>?) ?? const [];
    final tasks = (_dashboard?['tasks'] as List<dynamic>?) ?? const [];
    final alerts = (_dashboard?['alerts'] as List<dynamic>?) ?? const [];
    final activity = (_dashboard?['activity'] as List<dynamic>?) ?? const [];
    final metricMap = <String, Map<String, dynamic>>{
      for (final metric in metrics.cast<Map<String, dynamic>>())
        metric['key'].toString(): metric,
    };

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: buildwise.ErrorWidget(message: _error!, onRetry: _load),
      );
    }

    final children = <Widget>[
      Text(_description(role), style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 16),
      // A metric key the backend did not return still renders (as zero) so the
      // layout stays stable and a missing key is visible rather than silent.
      GridView(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.sizeOf(context).width <= 560
              ? 1
              : MediaQuery.sizeOf(context).width <= 900
              ? 2
              : 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisExtent: 184,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: _metricKeys(role).asMap().entries.map((entry) {
          final key = entry.value;
          final tones = [
            AppColors.primary,
            AppColors.warning,
            AppColors.success,
            AppColors.purple,
          ];
          final fills = [
            AppColors.primaryLight,
            const Color(0xFFFFF6E5),
            const Color(0xFFECFAF4),
            AppColors.purpleLight,
          ];
          final tone = tones[entry.key % tones.length];
          final metric = metricMap[key];
          final suffix = metric?['suffix'];
          return AppCard(
            color: fills[entry.key % fills.length],
            padding: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: tone, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    metric?['label']?.toString() ?? FieldFormat.humanize(key),
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_formatNumber(metric?['value'])}'
                      '${suffix != null && suffix != '' ? ' $suffix' : ''}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: tone, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Live from the authenticated API',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 10),
      Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
    ];

    if (tasks.isEmpty) {
      children.add(
        const AppCard(child: Text('No actions available for this role.')),
      );
    } else {
      for (final task in tasks.cast<Map<String, dynamic>>()) {
        children.add(
          _InfoCard(
            title: task['title']?.toString() ?? '',
            detail: task['description']?.toString() ?? '',
            onTap: widget.onNavigate == null || task['route'] == null
                ? null
                : () => widget.onNavigate!(task['route'].toString()),
          ),
        );
      }
    }

    children
      ..add(const SizedBox(height: 12))
      ..add(
        Text(
          'Attention required',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      )
      ..add(const SizedBox(height: 8));

    if (alerts.isEmpty) {
      children.add(
        const AppCard(child: Text('No active alerts for this role.')),
      );
    } else {
      for (final alert in alerts.cast<Map<String, dynamic>>()) {
        children.add(
          _InfoCard(
            title: alert['title']?.toString() ?? '',
            detail: alert['detail']?.toString() ?? '',
            onTap: widget.onNavigate == null || alert['route'] == null
                ? null
                : () => widget.onNavigate!(alert['route'].toString()),
          ),
        );
      }
    }

    children
      ..add(const SizedBox(height: 12))
      ..add(
        Text('Recent activity', style: Theme.of(context).textTheme.titleMedium),
      )
      ..add(const SizedBox(height: 8));

    if (activity.isEmpty) {
      children.add(const AppCard(child: Text('No recent activity recorded.')));
    } else {
      for (final item in activity.cast<Map<String, dynamic>>()) {
        children.add(
          _InfoCard(
            title: item['title']?.toString() ?? '',
            detail: [
              item['reference'],
              ...((item['relatedRecords'] as List<dynamic>?) ?? const []),
            ].whereType<String>().join(' · '),
            footer: _formatTimestamp(item['occurredAtUtc']),
            outcome: item['outcome']?.toString(),
            statusCode: (item['statusCode'] as num?)?.toInt(),
            endpoint: item['endpoint']?.toString(),
          ),
        );
      }
    }

    final sectionTitles = [
      'Quick actions',
      'Attention required',
      'Recent activity',
    ];
    final starts = sectionTitles
        .map(
          (title) => children.indexWhere(
            (child) => child is Text && child.data == title,
          ),
        )
        .toList();
    final groupedChildren = children.take(starts.first).toList();
    for (var section = 0; section < sectionTitles.length; section++) {
      final end = section + 1 < starts.length
          ? starts[section + 1]
          : children.length;
      final rows = children
          .sublist(starts[section] + 1, end)
          .where((child) => child is! SizedBox)
          .toList();
      groupedChildren.add(
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sectionTitles[section],
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                section == 0
                    ? 'Actions available to $role'
                    : section == 1
                    ? 'Alerts generated from current workflow state'
                    : 'Your activity, mapped to the business records it touched',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < rows.length; index++) ...[
                if (rows[index] is _InfoCard)
                  _groupedInfo(
                    context,
                    rows[index] as _InfoCard,
                    section == 1 ? 'Review' : 'Open',
                  )
                else if (rows[index] is AppCard)
                  (rows[index] as AppCard).child
                else
                  rows[index],
                if (index + 1 < rows.length) const Divider(height: 24),
              ],
            ],
          ),
        ),
      );
      groupedChildren.add(const SizedBox(height: 20));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(role)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: groupedChildren,
        ),
      ),
    );
  }

  Widget _groupedInfo(
    BuildContext context,
    _InfoCard info,
    String actionLabel,
  ) => InkWell(
    onTap: info.onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(info.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          info.detail,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textMuted),
        ),
        if (info.outcome != null)
          StatusChip(
            label: info.outcome!,
            tone:
                info.statusCode != null &&
                    info.statusCode! >= 200 &&
                    info.statusCode! < 300
                ? StatusTone.success
                : info.statusCode == 401 || info.statusCode == 403
                ? StatusTone.warning
                : StatusTone.danger,
          ),
        if (info.footer != null)
          Text(
            info.footer!,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        if (info.endpoint != null)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Technical details'),
            children: [
              SelectableText(
                '${info.endpoint} → HTTP ${info.statusCode ?? ''}',
              ),
            ],
          ),
        if (info.onTap != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: info.onTap,
              child: Text(actionLabel),
            ),
          ),
      ],
    ),
  );

  static String? _formatTimestamp(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year} | $hour:${date.minute.toString().padLeft(2, '0')}${date.hour >= 12 ? ' PM' : ' AM'}';
  }

  /// Thousands-separated integer, matching the web's `toLocaleString()`.
  static String _formatNumber(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;
    final isWhole = number == number.roundToDouble();
    final digits = isWhole ? number.toInt().toString() : number.toString();
    final parts = digits.split('.');
    final buffer = StringBuffer();
    for (var i = 0; i < parts[0].length; i++) {
      if (i > 0 && (parts[0].length - i) % 3 == 0) buffer.write(',');
      buffer.write(parts[0][i]);
    }
    return parts.length > 1 ? '$buffer.${parts[1]}' : buffer.toString();
  }
}

/// A title/detail block, used for quick actions, alerts and activity.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.detail,
    this.footer,
    this.onTap,
    this.outcome,
    this.statusCode,
    this.endpoint,
  });

  final String title;
  final String detail;
  final String? footer;
  final VoidCallback? onTap;
  final String? outcome;
  final int? statusCode;
  final String? endpoint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
          if (outcome != null)
            StatusChip(
              label: outcome!,
              tone:
                  statusCode != null && statusCode! >= 200 && statusCode! < 300
                  ? StatusTone.success
                  : statusCode == 401 || statusCode == 403
                  ? StatusTone.warning
                  : StatusTone.danger,
            ),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Open'), Icon(Icons.chevron_right, size: 18)],
              ),
            ),
          if (footer != null) ...[
            const SizedBox(height: 4),
            Text(footer!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    ),
  );
}
