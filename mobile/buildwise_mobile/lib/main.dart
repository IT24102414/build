import 'dart:async';

import 'package:flutter/material.dart';

import 'core/auth/buildwise_roles.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/web_only_notice_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/operations/screens/administration_screen.dart';
import 'features/operations/screens/agent_workflows_screen.dart';
import 'features/operations/screens/approvals_screen.dart';
import 'features/operations/screens/delivery_receiving_screen.dart';
import 'features/operations/screens/field_workspace_screen.dart';
import 'features/operations/screens/material_requests_screen.dart';
import 'features/operations/screens/quality_inspection_screen.dart';
import 'features/operations/services/operations_service.dart';
import 'features/procurement/screens/procurement_home_screen.dart';
import 'features/procurement/screens/purchase_orders_screen.dart';
import 'features/procurement/screens/quotation_comparison_screen.dart';
import 'features/procurement/screens/quotation_entry_screen.dart';
import 'features/procurement/screens/rfq_screen.dart';
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
      return LoginScreen(onSignedIn: _handleSignedIn, authService: _authService);
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
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollNotifications(showDeviceNotification: true));
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
        _roles = BuildWiseRoles.normalize(
          ((user?['roles'] as List<dynamic>?) ?? const []).cast<String>(),
        ).toList();
      });
      await _pollNotifications(showDeviceNotification: false);
    }
  }

  Future<void> _pollNotifications({required bool showDeviceNotification}) async {
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
        final body = row['body']?.toString() ?? 'Your workflow has a new update.';
        if (row['type'] == 'QualityInspectionCompleted') {
          await NotificationService.instance.showQualityUpdate(id: id, title: title, body: body);
        } else {
          await NotificationService.instance.showProcurementUpdate(id: id, title: title, body: body);
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
          content: Text('Notifications are available on the BuildWise web app.'),
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
              Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (rows.isEmpty) const Text('No notifications yet.'),
              ...rows.map((row) => ListTile(
                leading: Icon(row['isRead'] == true ? Icons.notifications_none : Icons.notifications_active, color: row['isRead'] == true ? AppColors.textMuted : AppColors.primary),
                title: Text('${row['title']}'),
                subtitle: Text('${row['body']}'),
                onTap: () async {
                  final id = (row['id'] as num?)?.toInt();
                  if (id != null && row['isRead'] != true) await _operationsService.markNotificationRead(id);
                  if (context.mounted) Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      );
      await _pollNotifications(showDeviceNotification: false);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  bool _has(Set<String> roles) => roles.any(_roles.contains);

  /// Human-readable name for a role, shown in the app bar.
  static String _roleLabel(String role) => switch (role) {
        BuildWiseRoles.procurementOfficer => 'Procurement Officer',
        BuildWiseRoles.procurementManager => 'Procurement Manager',
        BuildWiseRoles.siteManager => 'Site Manager',
        BuildWiseRoles.siteEngineer => 'Site Engineer',
        BuildWiseRoles.siteOfficer => 'Site Officer',
        BuildWiseRoles.qualityInspector => 'Quality Inspector',
        _ => 'Administrator',
      };

  /// This session's role, for display. Null when the account holds no internal
  /// role, since there is nothing meaningful to name.
  String? get _sessionRoleLabel {
    for (final role in _roles) {
      return _roleLabel(role);
    }
    return null;
  }

  /// The single field role this session represents, used by the field workspace.
  ///
  /// A desk-only account (Procurement Officer, Administrator) has no field work
  /// and never reaches `FieldWorkspaceScreen`; this returns a safe default for
  /// the mixed case where one account holds both a desk and a field role.
  String get _fieldRole {
    for (final role in <String>[
      BuildWiseRoles.siteEngineer,
      BuildWiseRoles.siteOfficer,
      BuildWiseRoles.qualityInspector,
    ]) {
      if (_roles.contains(role)) return role;
    }
    return BuildWiseRoles.siteEngineer;
  }

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
    if (_has({BuildWiseRoles.siteEngineer})) {
      destinations.add(
        _MobileDestination(
          label: 'Requests',
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment,
          builder: (_) => const MaterialRequestsScreen(),
        ),
      );
    }

    if (_has({BuildWiseRoles.siteOfficer})) {
      destinations.add(
        _MobileDestination(
          label: 'Deliveries',
          icon: Icons.local_shipping_outlined,
          selectedIcon: Icons.local_shipping,
          builder: (_) => const DeliveryReceivingScreen(),
        ),
      );
    }

    if (_has({BuildWiseRoles.qualityInspector})) {
      destinations.add(
        _MobileDestination(
          label: 'Inspections',
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check,
          builder: (_) => const QualityInspectionScreen(),
        ),
      );
    }

    // --- Approval gate ---------------------------------------------------
    // The human decision a manager makes on someone else's request. The same
    // screen the web app uses, so the gate behaves identically on both clients.
    if (_has(BuildWiseRoles.approvers)) {
      destinations.add(
        _MobileDestination(
          label: 'Approvals',
          icon: Icons.how_to_reg_outlined,
          selectedIcon: Icons.how_to_reg,
          builder: (_) => const ApprovalsScreen(),
        ),
      );
    }

    // --- Procurement desk ------------------------------------------------
    // RFQs go out by email to supplier contact records; quotations come back
    // by email and are keyed in here, then ranked by the quotation agent
    // (:8001) and approved by a human before any purchase order exists.
    if (_has(BuildWiseRoles.procurementDesk)) {
      destinations.add(
        _MobileDestination(
          label: 'RFQs',
          icon: Icons.mark_email_read_outlined,
          selectedIcon: Icons.mark_email_read,
          builder: (_) => const RfqScreen(),
        ),
      );
      destinations.add(
        _MobileDestination(
          label: 'Quotations',
          icon: Icons.compare_arrows_outlined,
          selectedIcon: Icons.compare_arrows,
          builder: (_) => const QuotationComparisonScreen(),
        ),
      );
      // Keying in what a supplier returned by email — the mobile counterpart of
      // the web app's QuotationEntryForm, on the same endpoint.
      destinations.add(
        _MobileDestination(
          label: 'Record',
          icon: Icons.post_add_outlined,
          selectedIcon: Icons.post_add,
          builder: (_) => const QuotationEntryScreen(),
        ),
      );
      // The purchase order register. Reporting only: an order exists because a
      // manager approved a workflow, never because this screen was used.
      destinations.add(
        _MobileDestination(
          label: 'Orders',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          builder: (_) => const PurchaseOrdersScreen(),
        ),
      );
    }

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
          builder: (_) => const AdministrationScreen(),
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
        builder: (_) => const AgentWorkflowsScreen(),
      ),
    );

    return destinations;
  }

  /// The home tab. Field roles get the "what do I do now?" workspace; desk roles
  /// get the procurement overview, which is the equivalent question for them.
  Widget _homeScreen() {
    if (_has(BuildWiseRoles.procurementDesk)) {
      return ProcurementHomeScreen(siteScoped: false);
    }
    if (_has(BuildWiseRoles.approvers)) {
      return const ApprovalsScreen();
    }
    return FieldWorkspaceScreen(role: _fieldRole);
  }

  /// Maps a web application route onto the mobile tab that carries the same
  /// work, so a deep link from the web app lands somewhere equivalent.
  void openRoute(String route) {
    final label = switch (route) {
      '/material-requests' =>
        _has({BuildWiseRoles.siteEngineer}) ? 'Requests' : 'Approvals',
      '/deliveries' => 'Deliveries',
      '/quality-inspections' => 'Inspections',
      '/non-conformances' => 'Inspections',
      '/admin' => 'Admin',
      '/rfqs' => 'RFQs',
      '/quotations' => 'Quotations',
      '/suppliers' => 'RFQs',
      '/purchase-orders' => 'Quotations',
      '/procurement' => _has(BuildWiseRoles.procurementDesk) ? 'Home' : 'Status',
      '/agent-workflows' => 'Agents',
      _ => 'Home',
    };
    final index = _destinations.indexWhere((destination) => destination.label == label);
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
      return Scaffold(
        appBar: AppBar(
          // All seven roles share this shell, so the signed-in role is shown up
          // top. It explains at a glance why a given set of tabs is visible.
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('BuildWise'),
              if (_sessionRoleLabel != null)
                Text(
                  _sessionRoleLabel!,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          actions: [
            Badge(
              isLabelVisible: _unreadNotifications > 0,
              label: Text('$_unreadNotifications'),
              child: IconButton(onPressed: _openNotifications, tooltip: 'Notifications', icon: const Icon(Icons.notifications_none)),
            ),
            IconButton(onPressed: _signOut, tooltip: 'Sign out', icon: const Icon(Icons.logout)),
          ],
        ),
        body: IndexedStack(index: safeIndex, children: [for (final item in destinations) item.builder(context)]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: (index) => setState(() => selectedIndex = index),
          destinations: [
            for (final item in destinations)
              NavigationDestination(icon: Icon(item.icon), selectedIcon: Icon(item.selectedIcon), label: item.label),
          ],
        ),
      );
    },
  );
}

class _MobileDestination {
  const _MobileDestination({required this.label, required this.icon, required this.selectedIcon, required this.builder});
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}

