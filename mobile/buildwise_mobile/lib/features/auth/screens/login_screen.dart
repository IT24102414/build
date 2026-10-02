import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../services/auth_service.dart';

class _DemoAccount {
  const _DemoAccount(this.label, this.email);
  final String label;
  final String email;
}

/// Seeded accounts for the three roles that use the mobile field app.
///
/// The Site Manager, Procurement Officer, Procurement Manager and Administrator
/// are deliberately absent: their work runs on the web application. Signing in
/// as one of them on mobile shows the web-only notice. See
/// `core/auth/buildwise_roles.dart` (`mobileCapable`).
///
/// There is no supplier account. Suppliers are external parties contacted by
/// email and never sign in to BuildWise.
const _demoAccounts = [
  _DemoAccount('Site Engineer', 'site.engineer@buildwise.demo'),
  _DemoAccount('Site Officer', 'site.officer@buildwise.demo'),
  _DemoAccount('Quality Inspector', 'quality.inspector@buildwise.demo'),
];
const _demoPassword = 'Passw0rd!';

/// Shared BuildWise sign-in screen (spec §8's "Registration, login, logout,
/// secure token storage and protected screens" requirement).
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onSignedIn,
    this.authService,
  });

  final VoidCallback onSignedIn;
  final AuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _authService.login(_emailController.text.trim(), _passwordController.text);
      widget.onSignedIn();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _demoLogin(_DemoAccount account) async {
    _emailController.text = account.email;
    _passwordController.text = _demoPassword;
    await _submit();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: const Text('BW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              const Text('BuildWise', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sign in', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                AppTextField(label: 'Email', controller: _emailController, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                AppTextField(label: 'Password', controller: _passwordController, obscureText: true),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 16),
                AppButton(
                  label: _submitting ? 'Signing in…' : 'Sign in',
                  expand: true,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick demo login', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                const Text('Seeded accounts for evaluation.', style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 12),
                ..._demoAccounts.map(
                  (account) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => _demoLogin(account),
                      style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                      child: Text('${account.label} — ${account.email}'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
