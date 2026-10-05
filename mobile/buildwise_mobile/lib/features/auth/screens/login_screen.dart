import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../services/auth_service.dart';

class _DemoAccount {
  const _DemoAccount(this.label, this.email);
  final String label;
  final String email;
}

/// Seeded accounts, one per internal role.
///
/// This list mirrors the web app's quick demo login **exactly** — same seven
/// roles, same labels, same order — so an evaluator can walk either client with
/// the same credentials and reach the same screens. The earlier three-account
/// list was a leftover from when the mobile app only served field roles; now
/// that all seven roles work on mobile, a shorter list would misrepresent the
/// system.
///
/// There is no supplier account. Suppliers are external parties contacted by
/// email and never sign in to BuildWise.
const _demoAccounts = [
  _DemoAccount('Procurement Officer', 'procurement.officer@buildwise.demo'),
  _DemoAccount('Procurement Manager', 'procurement.manager@buildwise.demo'),
  _DemoAccount('Site Engineer', 'site.engineer@buildwise.demo'),
  _DemoAccount('Site Officer', 'site.officer@buildwise.demo'),
  _DemoAccount('Site Manager', 'site.manager@buildwise.demo'),
  _DemoAccount('Quality Inspector', 'quality.inspector@buildwise.demo'),
  _DemoAccount('Administrator', 'admin@buildwise.demo'),
];
const _demoPassword = 'Passw0rd!';

/// Shared BuildWise sign-in screen (spec §8's "Registration, login, logout,
/// secure token storage and protected screens" requirement).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn, this.authService});

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
    if (_submitting) return;
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Password is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) widget.onSignedIn();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
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
      child: Center(
        child: SizedBox(
          width: 440,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Text(
                      'BW',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BuildWise',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          'Construction Procurement & Quality Management',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign in',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text(
                      'Use your BuildWise account to continue.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Password',
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
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
                    Text(
                      'Quick demo login',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    // Same wording as the web app, so the two login screens read
                    // identically during a walkthrough.
                    const Text(
                      'Seeded accounts for evaluation — one per role.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = MediaQuery.sizeOf(context).width > 480
                            ? 2
                            : 1;
                        final width =
                            (constraints.maxWidth - (columns - 1) * 12) /
                            columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final account in _demoAccounts)
                              SizedBox(
                                width: width,
                                child: Semantics(
                                  label: '${account.label} - ${account.email}',
                                  button: true,
                                  child: OutlinedButton(
                                    onPressed: _submitting
                                        ? null
                                        : () => _demoLogin(account),
                                    style: OutlinedButton.styleFrom(
                                      alignment: Alignment.centerLeft,
                                      side: const BorderSide(
                                        color: AppColors.border,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          account.label,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                        Text(
                                          account.email,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Demo password for every seeded account: Passw0rd!',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
