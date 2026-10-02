import 'dart:async';

import 'package:flutter/material.dart';

import 'core/auth/buildwise_roles.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/web_only_notice_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/operations/screens/agent_workflows_screen.dart';
import 'features/operations/screens/delivery_receiving_screen.dart';
import 'features/operations/screens/field_workspace_screen.dart';
import 'features/operations/screens/material_requests_screen.dart';
import 'features/operations/screens/quality_inspection_screen.dart';
import 'features/operations/services/operations_service.dart';
import 'features/procurement/screens/procurement_home_screen.dart';
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
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  late Future<bool> _signedInFuture;

  @override
  void initState() {
    super.initState();
    _signedInFuture = _authService.isSignedIn();
  }

  void _handleSignedIn() => setState(() => _signedInFuture = Future.value(true));
  void _handleSignedOut() => setState(() => _signedInFuture = Future.value(false));

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _signedInFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.data == true) {
        return MainAppShell(onSignOut: _handleSignedOut);
      }
      return LoginScreen(onSignedIn: _handleSignedIn, authService: _authService);
    },
  );
}

class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key, required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell>
    implements WorkspaceNavigator {
  int selectedIndex = 0;
  List<String> _roles = const [];
  final _authService = AuthService();
  final _operationsService = OperationsService();
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
    // The notifications API is internal-staff only, and a web-only procurement
    // role has no mobile surface to surface a notification on.
    if (!BuildWiseRoles.canUseMobileApp(_roles)) return;
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
    if (!BuildWiseRoles.canUseMobileApp(_roles)) {
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

  /// Human-readable name for a role, used by the web-only notice.
  static String _roleLabel(String role) => switch (role) {
        BuildWiseRoles.procurementOfficer => 'Procurement Officer',
        BuildWiseRoles.procurementManager => 'Procurement Manager',
        BuildWiseRoles.siteManager => 'Site Manager',
        BuildWiseRoles.siteEngineer => 'Site Engineer',
        BuildWiseRoles.siteOfficer => 'Site Officer',
        BuildWiseRoles.qualityInspector => 'Quality Inspector',
        _ => 'Administrator',
      };

  /// The mobile app is a field operations tool. These roles do desk, approval
  /// or governance work on the web application, so they get an explainer here
  /// instead of a half-built set of screens.
  String get _primaryWebOnlyRole {
    for (final role in _roles) {
      if (BuildWiseRoles.webOnly.contains(role)) return _roleLabel(role);
    }
    return 'Your';
  }

  /// The single field role this session represents.
  ///
  /// Only the three field roles reach the mobile shell (see
  /// `core/auth/buildwise_roles.dart`), so this always resolves to one of them.
  /// An account holding more than one field role uses its first, matching the
  /// precedence already applied when building the navigation.
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

  /// The destination label holding this role's work, used by the workspace home
  /// to hand off to the right tab.
  String get _workspaceLabel {
    if (_has({BuildWiseRoles.siteEngineer})) return 'Requests';
    if (_has({BuildWiseRoles.siteOfficer})) return 'Deliveries';
    return 'Inspections';
  }

  /// Role sets live in `core/auth/buildwise_roles.dart` so this shell and the
  /// backend policy grants cannot disagree about who sees which screen.
  ///
  /// There is no supplier branch, because a supplier is not a BuildWise user.
  /// Suppliers are external parties contacted by email; the procurement officer
  /// emails them an RFQ and keys in the quotations they send back. None of that
  /// is a mobile surface, so there is nothing here for a supplier to reach.
  List<_MobileDestination> get _destinations {
    // Not an internal role (or a web-only one): show the explainer, not the app.
    if (!BuildWiseRoles.canUseMobileApp(_roles)) {
      return [
        _MobileDestination(
          label: 'Web App',
          icon: Icons.laptop_mac_outlined,
          selectedIcon: Icons.laptop_mac,
          builder: (_) => WebOnlyNoticeScreen(roleLabel: _primaryWebOnlyRole),
        ),
      ];
    }

    final destinations = <_MobileDestination>[
      _MobileDestination(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        // The field workspace, not the React dashboard: it answers "what do I
        // need to do now?" for whichever of the three field roles signed in.
        builder: (_) => FieldWorkspaceScreen(role: _fieldRole),
      ),
    ];

    // Site Engineer raises material requests. Approval is a Site Manager job on
    // the web app, so the engineer only ever creates and tracks.
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

    // Site Officer receives the delivery against a confirmed purchase order.
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

    // Read-only procurement progress, so the engineer can answer "what happened
    // to my request?" without ever seeing supplier names or prices.
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

    // Quality Inspector: the five-point checklist and the NCR register.
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

    // Agent workflow history: which agents ran and what they recommended.
    // Read-only for every field role — it starts no workflow.
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

  void openRoute(String route) {
    final label = switch (route) {
      '/material-requests' => 'Requests',
      '/deliveries' => 'Deliveries',
      '/quality-inspections' => 'Inspections',
      '/procurement' || '/quotations' || '/purchase-orders' => 'Status',
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
          title: const Text('BuildWise'),
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

