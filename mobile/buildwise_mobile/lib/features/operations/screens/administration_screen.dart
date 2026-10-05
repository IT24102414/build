import 'package:flutter/material.dart';

import '../../../core/widgets/error_widget.dart' as buildwise;
import '../../../core/widgets/widgets.dart' hide ErrorWidget;
import '../../../core/auth/buildwise_roles.dart';
import '../services/operations_service.dart';

/// Administrator-only screen: user register, audit trail and service health.
///
/// Reached by the Administrator (`BuildWiseRoles.governance`), using the same
/// endpoints as the React administration page.
///
/// The health section is the quickest way to confirm during a demo that all four
/// AI agents are actually reachable, rather than only that the API is up.
class AdministrationScreen extends StatefulWidget {
  const AdministrationScreen({super.key, this.service});

  final OperationsService? service;

  @override
  State<AdministrationScreen> createState() => _AdministrationScreenState();
}

class _CreateUserSheet extends StatefulWidget {
  const _CreateUserSheet({required this.service});
  final OperationsService service;
  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = BuildWiseRoles.siteEngineer;
  bool _saving = false;
  String? _error;
  String? _nameError, _emailError, _passwordError;

  void _validateFields() {
    _nameError = _name.text.trim().isEmpty ? 'Enter the full name.' : null;
    _emailError =
        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())
        ? null
        : 'Enter a valid email, e.g. name@gmail.com.';
    final password = _password.text;
    _passwordError =
        password.length >= 8 &&
            RegExp(r'[a-zA-Z]').hasMatch(password) &&
            RegExp(r'\d').hasMatch(password)
        ? null
        : 'Use at least 8 characters, including a letter and a number.';
  }

  void _fieldChanged(String _) {
    setState(() {
      _error = null;
      if (_nameError != null || _emailError != null || _passwordError != null) {
        _validateFields();
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _password.text;
    setState(() {
      _error = null;
      _validateFields();
    });
    if (_nameError != null || _emailError != null || _passwordError != null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = await widget.service.createUser({
        'fullName': _name.text.trim(),
        'email': _email.text.trim(),
        'password': password,
        'role': _role,
      });
      if (mounted) Navigator.pop(context, user);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add user', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Full name',
            controller: _name,
            errorText: _nameError,
            onChanged: _fieldChanged,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            hint: 'name@gmail.com',
            errorText: _emailError,
            onChanged: _fieldChanged,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Temporary password',
            controller: _password,
            obscureText: true,
            errorText: _passwordError,
            onChanged: _fieldChanged,
          ),
          const SizedBox(height: 16),
          AppDropdown(
            label: 'Role',
            value: _role,
            items: BuildWiseRoles.internalStaff.toList(),
            onChanged: (value) => setState(() => _role = value ?? _role),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          AppButton(
            label: _saving ? 'Creating…' : 'Create user',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    ),
  );
}

class _AdministrationScreenState extends State<AdministrationScreen>
    with SingleTickerProviderStateMixin {
  final _service = OperationsService();
  late final TabController _tabs = TabController(length: 3, vsync: this);

  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _auditLogs = const [];
  Map<String, dynamic>? _health;
  String _search = '';
  int? _updatingUser;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final service = widget.service ?? _service;
    try {
      // Surface API failures instead of displaying an empty register as success.
      final results = await Future.wait([
        service.listUsers(search: _search),
        service.listAuditLogs(),
        service.getSystemHealth(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = (results[0] as List<dynamic>).cast<Map<String, dynamic>>();
        _auditLogs = (results[1] as List<dynamic>).cast<Map<String, dynamic>>();
        _health = results[2] as Map<String, dynamic>;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Administration'),
      actions: [
        IconButton(
          onPressed: _createUser,
          tooltip: 'Add user',
          icon: const Icon(Icons.person_add),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'Users'),
          Tab(text: 'Audit'),
          Tab(text: 'Health'),
        ],
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? buildwise.ErrorWidget(message: _error!, onRetry: _load)
        : TabBarView(
            controller: _tabs,
            children: [_usersTab(), _auditTab(), _healthTab()],
          ),
  );

  OperationsService get _api => widget.service ?? _service;

  Future<void> _createUser() async {
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateUserSheet(service: _api),
    );
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created['emailSent'] == true
              ? 'Account created. Welcome email sent.'
              : 'Account created. Welcome email was not sent; share the credentials manually.',
        ),
      ),
    );
    await _load();
  }

  Future<void> _updateUser(Map<String, dynamic> user, {String? role}) async {
    final id = (user['id'] as num).toInt();
    setState(() => _updatingUser = id);
    try {
      if (role != null) {
        await _api.setUserRoles(id, [role]);
      } else {
        await _api.setUserActive(id, user['isActive'] != true);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingUser = null);
    }
  }

  Widget _usersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Search users',
                  hint: 'Name or email',
                  onChanged: (value) => _search = value,
                ),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.search)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final user = _users[index];
              final roles = (user['roles'] as List<dynamic>? ?? const [])
                  .map((r) => r.toString())
                  .toList();
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            user['fullName']?.toString() ??
                                user['email']?.toString() ??
                                'User',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        StatusChip(
                          label: user['isActive'] == true
                              ? 'Active'
                              : 'Inactive',
                          tone: user['isActive'] == true
                              ? StatusTone.success
                              : StatusTone.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user['email']?.toString() ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    AppDropdown(
                      label: 'Assigned role',
                      value: roles.isEmpty ? null : roles.first,
                      items: BuildWiseRoles.internalStaff.toList(),
                      onChanged: _updatingUser != null
                          ? null
                          : (value) {
                              if (value != null) _updateUser(user, role: value);
                            },
                    ),
                    TextButton(
                      onPressed: _updatingUser != null
                          ? null
                          : () => _updateUser(user),
                      child: Text(
                        user['isActive'] == true ? 'Deactivate' : 'Activate',
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final role in roles) StatusChip(label: role),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _auditTab() {
    if (_auditLogs.isEmpty) {
      return const EmptyStateWidget(
        title: 'No audit entries',
        message: 'Nothing has been recorded yet.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _auditLogs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final log = _auditLogs[index];
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _auditAction(log),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (log['entityType'] != null) log['entityType'].toString(),
                  if (log['entityId'] != null) '#${log['entityId']}',
                  if (log['httpMethod'] != null) log['httpMethod'].toString(),
                  if (log['statusCode'] != null)
                    '${_auditStatus((log['statusCode'] as num).toInt())} (${log['statusCode']})',
                  if (log['userId'] != null)
                    'by ${_users.where((user) => user['id'] == log['userId']).firstOrNull?['fullName'] ?? 'User #${log['userId']}'}',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (log['createdAt'] != null)
                Text(_auditTime(log['createdAt'].toString())),
              if (log['requestPath'] != null)
                SelectableText(
                  '${log['httpMethod'] ?? ''} ${log['requestPath']}',
                ),
            ],
          ),
        );
      },
    );
  }

  String _auditAction(Map<String, dynamic> log) {
    final path = log['requestPath']?.toString() ?? '';
    final normalized = path.replaceAll(RegExp(r'/\d+(?=/|$)'), '/:id');
    const actions = {
      '/api/quality-inspections/:id/risk-analysis': 'Analyze inspection risk',
      '/api/quality-inspections': 'Create quality inspection',
      '/api/deliveries/:id/discrepancy-analysis':
          'Analyze delivery discrepancies',
      '/api/deliveries': 'Record delivery',
      '/api/procurement-workflow/:id/decision': 'Record procurement decision',
      '/api/projects/:id/budget': 'Update project budget',
      '/api/material-requests/:id/procurement-workflow':
          'Run quotation analysis',
      '/api/material-requests/:id/quotations': 'Record quotation',
      '/api/rfqs/:id/send-email': 'Request RFQ email delivery',
      '/api/rfqs/:id/close': 'Close RFQ',
      '/api/rfqs': 'Create RFQ',
      '/api/suppliers': 'Create supplier',
      '/api/material-requests/:id/approval': 'Record material request decision',
      '/api/agent/analyze-request/:id': 'Analyze material request',
      '/api/material-requests': 'Create material request',
    };
    return (log['httpMethod'] == 'POST' || path.endsWith('/budget')
            ? actions[normalized]
            : null) ??
        log['action']?.toString() ??
        'API action';
  }

  String _auditTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final time = parsed.toUtc().add(const Duration(hours: 5, minutes: 30));
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${pad(time.day)}/${pad(time.month)}/${time.year} ${pad(time.hour)}:${pad(time.minute)}:${pad(time.second)} (Sri Lanka)';
  }

  String _auditStatus(int code) {
    if (code >= 500) return 'Server error';
    if (code == 400) return 'Rejected';
    if (code == 401) return 'Unauthenticated';
    if (code == 403) return 'Forbidden';
    if (code >= 400) return 'Failed';
    if (code >= 300) return 'Redirected';
    if (code >= 200) return 'Request successful';
    return 'Informational';
  }

  Widget _healthTab() {
    final health = _health ?? const <String, dynamic>{};
    // `services` is an object of name -> reachable, e.g.
    // {"quotation-agent": true, "quality-agent": true}, not a list of rows.
    final services = (health['services'] as Map<String, dynamic>?) ?? const {};
    final database = health['database'];
    final overall = health['status']?.toString() ?? 'Unknown';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Overall', style: Theme.of(context).textTheme.titleMedium),
              StatusChip(
                label: overall,
                tone: overall.toLowerCase() == 'healthy'
                    ? StatusTone.success
                    : overall.toLowerCase() == 'degraded'
                    ? StatusTone.warning
                    : StatusTone.danger,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Database'),
              StatusChip(
                label: database == true ? 'Reachable' : 'Unreachable',
                tone: database == true ? StatusTone.success : StatusTone.danger,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('AI agents', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (services.isEmpty)
          const AppCard(child: Text('No agent health reported.'))
        else
          ...services.entries.map((entry) {
            final ok = entry.value == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    StatusChip(
                      label: ok ? 'Healthy' : 'Unreachable',
                      tone: ok ? StatusTone.success : StatusTone.danger,
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 12),
        Text(
          'Checked at ${health['checkedAtUtc'] ?? '—'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
