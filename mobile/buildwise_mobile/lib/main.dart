import 'dart:async';

import 'package:flutter/material.dart';

import 'core/auth/buildwise_roles.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/react_app_shell.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/web_only_notice_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/operations/screens/administration_screen.dart';
import 'features/operations/screens/agent_workflows_screen.dart';
import 'features/operations/screens/approvals_screen.dart';
import 'features/operations/screens/delivery_receiving_screen.dart';
import 'features/operations/screens/dashboard_screen.dart';
import 'features/operations/screens/field_workspace_screen.dart';
import 'features/operations/screens/material_requests_screen.dart';
import 'features/operations/screens/quality_inspection_screen.dart';
import 'features/operations/services/operations_service.dart';
import 'features/procurement/screens/procurement_home_screen.dart';
import 'features/procurement/screens/purchase_orders_screen.dart';
import 'features/procurement/screens/quotation_comparison_screen.dart';
import 'features/procurement/screens/quotation_entry_screen.dart';
import 'features/procurement/screens/rfq_screen.dart';
import 'features/procurement/screens/suppliers_screen.dart';
import 'features/procurement/services/notification_service.dart';

void main() => runApp(const BuildWiseApp());

class BuildWiseApp extends StatelessWidget {
  const BuildWiseApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BuildWise',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const AuthGate(),
  );
}

/// Shows the sign-in screen until a JWT is present in secure storage, then
/// hands off to the main app shell (spec section 8: "protected screens").
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authService, this.operationsService});
  @override
  State<AuthGate> createState() => _AuthGateState();

  /// Injectable only so the sign-in / sign-out transition can be covered by
  /// tests. Production code omits it and gets the default service.
  final AuthService? authService;
  final OperationsService? operationsService;
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService = widget.authService ?? AuthService();
  late Future<bool> _signedInFuture;

  @override
  void initState() {
    super.initState();
    _signedInFuture = _authService.isSignedIn();
  }

  // These must use a block body, not `() => _signedInFuture = ...`.
  // An arrow function whose body is an assignment expression evaluates to the
  // *assigned value*, so `setState` would receive a `Future` as the result of
  // its `VoidCallback` and throw "setState() callback argument returned a
  // Future". A block body returns void, which is what setState requires.
  // These must use a block body, not `() => _signedInFuture = ...`.
  // An arrow function whose body is an assignment expression evaluates to the
  // *assigned value*, so `setState` would receive a `Future` as the result of
  // its `VoidCallback` and throw "setState() callback argument returned a
  // Future". A block body returns void, which is what setState requires.
  void _handleSignedIn() {
    setState(() {
      _signedInFuture = Future.value(true);
    });
  }

  void _handleSignedOut() {
    setState(() {
      _signedInFuture = Future.value(false);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _signedInFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.data == true) {
        return MainAppShell(
          onSignOut: _handleSignedOut,
          authService: _authService,
          operationsService: widget.operationsService,
        );
      }
      return LoginScreen(
        onSignedIn: _handleSignedIn,
        authService: _authService,
      );
    },
  );
}

class MainAppShell extends StatefulWidget {
  const MainAppShell({
    super.key,
    required this.onSignOut,
    this.authService,
    this.operationsService,
  });
  final VoidCallback onSignOut;

  /// Injectable only so session-dependent chrome can be tested. Production
  /// code omits it and gets the default service.
  final AuthService? authService;
  final OperationsService? operationsService;

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell>
    implements WorkspaceNavigator {
  int selectedIndex = 0;
  List<String> _roles = const [];
  String _displayName = 'BuildWise user';
  late final AuthService _authService = widget.authService ?? AuthService();
  late final OperationsService _operationsService =
      widget.operationsService ?? OperationsService();
  Timer? _notificationTimer;
  int _unreadNotifications = 0;
  final Set<int> _notifiedNotificationIds = <int>{};
  late Future<void> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _loadSession();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _pollNotifications(showDeviceNotification: true),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final user = await _authService.currentUser();
    if (mounted) {
      setState(() {
        // Legacy role names are folded into their canonical equivalent and any
        // unrecognised claim (e.g. a stray `Supplier`) is dropped, so every
        // capability check below sees one of the seven internal roles.
        _displayName = user?['fullName']?.toString() ?? 'BuildWise user';
        _roles = BuildWiseRoles.normalize(
          ((user?['roles'] as List<dynamic>?) ?? const []).cast<String>(),
        ).toList();
      });
      await _pollNotifications(showDeviceNotification: false);
    }
  }

  Future<void> _pollNotifications({
    required bool showDeviceNotification,
  }) async {
    // The notifications API is internal-staff only, and an account that resolved
    // to no internal role has no mobile surface to surface a notification on.
    if (!BuildWiseRoles.isInternalStaff(_roles)) return;
    try {
      final rows = await _operationsService.listNotifications(unreadOnly: true);
      if (!mounted) return;
      setState(() => _unreadNotifications = rows.length);
      if (!showDeviceNotification) return;
      for (final row in rows.take(3)) {
        final id = (row['id'] as num?)?.toInt() ?? 0;
        if (id == 0 || !_notifiedNotificationIds.add(id)) continue;
        final title = row['title']?.toString() ?? 'BuildWise update';
        final body =
            row['body']?.toString() ?? 'Your workflow has a new update.';
        if (row['type'] == 'QualityInspectionCompleted') {
          await NotificationService.instance.showQualityUpdate(
            id: id,
            title: title,
            body: body,
          );
        } else {
          await NotificationService.instance.showProcurementUpdate(
            id: id,
            title: title,
            body: body,
          );
        }
      }
    } catch (_) {
      // Notification polling is best-effort; protected API operations remain authoritative.
    }
  }

  Future<void> _openNotifications() async {
    if (!BuildWiseRoles.isInternalStaff(_roles)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are available on the BuildWise web app.',
          ),
        ),
      );
      return;
    }
    try {
      final rows = await _operationsService.listNotifications();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Notifications',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty) const Text('No notifications yet.'),
              ...rows.map(
                (row) => ListTile(
                  leading: Icon(
                    row['isRead'] == true
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: row['isRead'] == true
                        ? AppColors.textMuted
                        : AppColors.primary,
                  ),
                  title: Text('${row['title']}'),
                  subtitle: Text('${row['body']}'),
                  onTap: () async {
                    final id = (row['id'] as num?)?.toInt();
                    if (id != null && row['isRead'] != true) {
                      await _operationsService.markNotificationRead(id);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      );
      await _pollNotifications(showDeviceNotification: false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  bool _has(Set<String> roles) => roles.any(_roles.contains);

  /// The destination label holding this role's work, used by the field
  /// workspace to hand off to the right tab.
  String get _workspaceLabel {
    if (_has({BuildWiseRoles.siteEngineer})) return 'Requests';
    if (_has({BuildWiseRoles.siteOfficer})) return 'Deliveries';
    return 'Inspections';
  }

  /// The tabs this session can open, derived from its roles.
  ///
  /// Each tab is gated on a capability set in `core/auth/buildwise_roles.dart`,
  /// so the visible menu and the API's own authorization cannot disagree: a
  /// non-approver is never shown Approve, and a non-procurement role is never
  /// shown a supplier price. The API remains the authority — this only decides
  /// what is drawn.
  ///
  /// There is no supplier branch, because a supplier is not a BuildWise user.
  /// Suppliers are external parties contacted by email; the procurement officer
  /// emails them an RFQ and keys in the quotations they send back.
  List<_MobileDestination> get _destinations {
    // A claim that resolved to no internal role (a stray `Supplier`, say) has no
    // surface on either client. Show the explainer rather than an empty shell.
    if (!BuildWiseRoles.isInternalStaff(_roles)) {
      return [
        _MobileDestination(
          label: 'Web App',
          icon: Icons.laptop_mac_outlined,
          selectedIcon: Icons.laptop_mac,
          builder: (_) => WebOnlyNoticeScreen(roleLabel: 'This account'),
        ),
      ];
    }

    final destinations = <_MobileDestination>[
      _MobileDestination(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        builder: (_) => _homeScreen(),
      ),
    ];

    // --- Field execution -------------------------------------------------
    // The Site Engineer raises and tracks material requests. The Site Officer
    // receives physical deliveries against a confirmed PO. The Quality
    // Inspector runs the five-point checklist and raises NCRs.
    if (_has(BuildWiseRoles.requestReaders) &&
        !_has(BuildWiseRoles.approvers)) {
      destinations.add(
        _MobileDestination(
          label: 'Requests',
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment,
          builder: (_) => MaterialRequestsScreen(
            service: _operationsService,
            ownRequestsOnly: _has(BuildWiseRoles.siteOperations),
            readOnly: !_has({BuildWiseRoles.siteEngineer}),
            canApprove: false,
          ),
        ),
      );
    }

    if (BuildWiseRoles.isInternalStaff(_roles)) {
      destinations.add(
        _MobileDestination(
          label: 'Deliveries',
          icon: Icons.local_shipping_outlined,
          selectedIcon: Icons.local_shipping,
          builder: (_) => DeliveryReceivingScreen(
            service: _operationsService,
            readOnly: !_has(BuildWiseRoles.deliveryReceivers),
          ),
        ),
      );
    }

    // Quality Inspections & NCRs are readable by every internal role — the
    // backend `QualityReaders` policy now grants the whole procurement desk
    // the same read the web sidebar offers. The *write* controls stay gated:
    // completing an inspection is QualityControlOnly (Quality Inspector /
    // Administrator) and moving an NCR to Resolved/Closed is
    // ProcurementDecisionOnly (Procurement Manager / Site Manager /
    // Administrator), so a reader is never shown a button that would 403.
    destinations.add(
      _MobileDestination(
        label: 'Inspections',
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check,
        builder: (_) => QualityInspectionScreen(
          service: _operationsService,
          readOnly: !_has({
            BuildWiseRoles.qualityInspector,
            BuildWiseRoles.administrator,
          }),
          canManageNcrs: _has(BuildWiseRoles.approvers),
        ),
      ),
    );

    destinations.add(
      _MobileDestination(
        label: 'NCRs',
        icon: Icons.report_outlined,
        selectedIcon: Icons.report,
        builder: (_) => QualityInspectionScreen(
          service: _operationsService,
          readOnly: true,
          ncrOnly: true,
          canManageNcrs: _has(BuildWiseRoles.approvers),
        ),
      ),
    );

    // --- Approval gate ---------------------------------------------------
    // The human decision a manager makes on someone else's request. The same
    // screen the web app uses, so the gate behaves identically on both clients.
    if (_has(BuildWiseRoles.approvers)) {
      destinations.add(
        _MobileDestination(
          label: 'Approvals',
          icon: Icons.how_to_reg_outlined,
          selectedIcon: Icons.how_to_reg,
          builder: (_) => ApprovalsScreen(service: _operationsService),
        ),
      );
    }

    // --- Procurement desk ------------------------------------------------
    // RFQs go out by email to supplier contact records; quotations come back
    // by email and are keyed in here, then ranked by the quotation agent
    // (:8001) and approved by a human before any purchase order exists.
    if (_has(BuildWiseRoles.procurementDesk)) {
      // The supplier directory: the contact records the desk emails RFQs to.
      // Field rules are identical to the web Add Supplier form.
      destinations.add(
        _MobileDestination(
          label: 'Suppliers',
          icon: Icons.storefront_outlined,
          selectedIcon: Icons.storefront,
          builder: (_) =>
              SuppliersScreen(canEdit: _has(BuildWiseRoles.supplierEditors)),
        ),
      );
      destinations.add(
        _MobileDestination(
          label: 'RFQs',
          icon: Icons.mark_email_read_outlined,
          selectedIcon: Icons.mark_email_read,
          builder: (_) => RfqScreen(
            canIssue: _has(BuildWiseRoles.supplierEditors),
            canClose: _has(BuildWiseRoles.procurementWriters),
          ),
        ),
      );
      destinations.add(
        _MobileDestination(
          label: 'Quotations',
          icon: Icons.compare_arrows_outlined,
          selectedIcon: Icons.compare_arrows,
          builder: (_) => QuotationComparisonScreen(
            // Running the agent and recording the accept/override decision is a
            // manager action; an officer gets the read-only comparison.
            canApprove: _has(BuildWiseRoles.approvers),
            canRunAgent: _has({
              BuildWiseRoles.procurementOfficer,
              BuildWiseRoles.administrator,
            }),
          ),
        ),
      );
      // Keying in what a supplier returned by email — the mobile counterpart of
      // the web app's QuotationEntryForm, on the same endpoint.
      if (_has(BuildWiseRoles.supplierEditors)) {
        destinations.add(
          _MobileDestination(
            label: 'Record',
            icon: Icons.post_add_outlined,
            selectedIcon: Icons.post_add,
            builder: (_) => const QuotationEntryScreen(),
          ),
        );
      }
    }

    // The purchase order register. Reporting only: an order exists because a
    // manager approved a workflow, never because this screen was used.
    destinations.add(
      _MobileDestination(
        label: 'Orders',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        // Read-only by design: a purchase order only ever comes from an
        // approved workflow, never from this register.
        builder: (_) => PurchaseOrdersScreen(
          canManage: _has(BuildWiseRoles.procurementWriters),
        ),
      ),
    );

    // Read-only procurement progress for the site roles, so the engineer can
    // answer "what happened to my request?" without ever seeing supplier names
    // or prices.
    if (_has({BuildWiseRoles.siteEngineer, BuildWiseRoles.siteOfficer})) {
      destinations.add(
        _MobileDestination(
          label: 'Status',
          icon: Icons.route_outlined,
          selectedIcon: Icons.route,
          builder: (_) => const ProcurementHomeScreen(siteScoped: true),
        ),
      );
    }

    // --- Governance ------------------------------------------------------
    if (_has(BuildWiseRoles.governance)) {
      destinations.add(
        _MobileDestination(
          label: 'Admin',
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
          builder: (_) => AdministrationScreen(service: _operationsService),
        ),
      );
    }

    // Agent workflow history: which agents ran and what they recommended.
    // Read-only for every role — it starts no workflow.
    destinations.add(
      _MobileDestination(
        label: 'Agents',
        icon: Icons.hub_outlined,
        selectedIcon: Icons.hub,
        builder: (_) => AgentWorkflowsScreen(service: _operationsService),
      ),
    );

    return destinations;
  }

  /// The home tab. Field roles get the "what do I do now?" workspace; desk roles
  /// get the procurement overview, which is the equivalent question for them.
  /// The home tab. Every role lands on its own role dashboard
  /// (`DashboardScreen`), which picks its metrics, quick actions and alerts from
  /// the signed-in role — the Site Engineer's is material-request work, the
  /// Procurement Officer's is RFQ and quotation work. `mobile_parity_test` pins
  /// this: one dashboard, fetched once, showing that role's own cases.
  Widget _homeScreen() => DashboardScreen(
    roles: _roles,
    service: _operationsService,
    onNavigate: openRoute,
  );

  /// Maps a web application route onto the mobile tab that carries the same
  /// work, so a deep link from the web app lands somewhere equivalent.
  @override
  void openRoute(String route) {
    final label = switch (route) {
      '/material-requests' =>
        _has(BuildWiseRoles.approvers) ? 'Approvals' : 'Requests',
      '/deliveries' => 'Deliveries',
      '/quality-inspections' => 'Inspections',
      '/non-conformances' => 'NCRs',
      '/admin' => 'Admin',
      '/rfqs' => 'RFQs',
      '/quotations' => 'Quotations',
      '/suppliers' => 'Suppliers',
      '/purchase-orders' => 'Orders',
      '/procurement' =>
        _has(BuildWiseRoles.procurementDesk) ? 'Home' : 'Status',
      '/agent-workflows' => 'Agents',
      _ => 'Home',
    };
    final index = _destinations.indexWhere(
      (destination) => destination.label == label,
    );
    if (index >= 0) setState(() => selectedIndex = index);
  }

  void openDestination(int index) {
    if (index < 0 || index >= _destinations.length) return;
    setState(() => selectedIndex = index);
  }

  /// [WorkspaceNavigator] — the field workspace home calls this so its primary
  /// action lands the user on the tab holding their actual work.
  @override
  void openWorkspace() {
    final label = _workspaceLabel;
    final index = _destinations.indexWhere((d) => d.label == label);
    if (index >= 0) openDestination(index);
  }

  Future<void> _signOut() async {
    await _authService.logout();
    widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _sessionFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final destinations = _destinations;
      final safeIndex = selectedIndex.clamp(0, destinations.length - 1);
      final menu = <String, String>{
        'Home': 'Dashboard',
        if (_has(BuildWiseRoles.approvers))
          'Approvals': 'Material Requests'
        else
          'Requests': 'Material Requests',
        if (_has({
          BuildWiseRoles.procurementOfficer,
          BuildWiseRoles.procurementManager,
          BuildWiseRoles.administrator,
        })) ...{
          'Suppliers': 'Suppliers',
          'Quotations': 'Quotations',
          'RFQs': 'RFQs',
        },
        'Agents': 'Agent Workflows',
        'Orders': 'Purchase Orders',
        'Deliveries': 'Deliveries',
        'Inspections': 'Quality Inspections',
        'NCRs': 'Non-Conformance Reports',
        if (_has(BuildWiseRoles.governance)) 'Admin': 'User Management',
      };
      final visible = menu.entries
          .where((entry) => destinations.any((d) => d.label == entry.key))
          .toList();
      return ReactAppShell(
        labels: visible.map((entry) => entry.value).toList(),
        selectedLabel:
            menu[destinations[safeIndex].label] ??
            destinations[safeIndex].label,
        onNavigate: (label) {
          final entry = visible.firstWhere((entry) => entry.value == label);
          openDestination(destinations.indexWhere((d) => d.label == entry.key));
        },
        displayName: _displayName,
        role: _roles.isEmpty ? 'Team member' : _roles.first,
        unreadNotifications: _unreadNotifications,
        onNotifications: _openNotifications,
        onSignOut: _signOut,
        child: KeyedSubtree(
          key: ValueKey(destinations[safeIndex].label),
          child: destinations[safeIndex].builder(context),
        ),
      );
    },
  );
}

class _MobileDestination {
  const _MobileDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}
