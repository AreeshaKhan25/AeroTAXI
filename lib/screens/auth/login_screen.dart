import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/saved_accounts_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();
  final _authService = AuthService();

  bool _obscure = true;
  bool _loading = false;
  String? _error;
  List<SavedAccount> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAccounts() async {
    final accounts = await SavedAccountsService.getAccounts();
    if (mounted) setState(() => _savedAccounts = accounts);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final err = await _authService.signIn(_emailCtrl.text, _passCtrl.text);

    if (err == null) {
      // Save account + password on successful login (fire-and-forget)
      unawaited(SavedAccountsService.saveAccount(
        _emailCtrl.text.trim(),
        FirebaseAuth.instance.currentUser?.displayName ?? '',
      ));
      unawaited(SavedAccountsService.savePassword(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      ));
    }

    if (!mounted) return;
    if (err != null) {
      setState(() {
        _error = err;
        _loading = false;
      });
    }
    // GoRouter redirect handles navigation on success
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await _authService.resetPassword(_emailCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password reset email sent. Check your inbox.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _loginWithSavedAccount(String email) async {
    final password = await SavedAccountsService.getPassword(email);
    if (password == null || password.isEmpty) {
      // No stored password yet — fill email and let user type password
      _emailCtrl.text = email;
      setState(() => _error = null);
      _passFocus.requestFocus();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final err = await _authService.signIn(email, password);

    if (!mounted) return;
    if (err != null) {
      // Password probably changed — clear it and fall back to manual entry
      unawaited(SavedAccountsService.deletePassword(email));
      _emailCtrl.text = email;
      setState(() {
        _loading = false;
        _error = err;
      });
      _passFocus.requestFocus();
    }
    // On success GoRouter redirect handles navigation
  }

  void _showSavedAccountsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SavedAccountsSheet(
        accounts: _savedAccounts,
        onSelect: (email) {
          Navigator.of(context).pop();
          _loginWithSavedAccount(email);
        },
        onRemove: (email) async {
          await SavedAccountsService.removeAccount(email);
          await _loadSavedAccounts();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              _buildHeader(),
              const SizedBox(height: 40),
              _buildForm(),
              const SizedBox(height: 28),
              _buildLoginButton(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _buildError(),
              ],
              const SizedBox(height: 20),
              _buildForgotPassword(),
              const SizedBox(height: 32),
              _buildDivider(),
              const SizedBox(height: 24),
              _buildSignupLink(),
              if (_savedAccounts.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildSavedAccountsButton(),
              ],
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Image.asset(
          'assets/images/logos/logo.png',
          width: 72,
          height: 72,
        ),
        const SizedBox(height: 16),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'AERO',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                  letterSpacing: 2,
                ),
              ),
              TextSpan(
                text: 'TAXI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryContainer,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Welcome back',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sign in to your account',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppTheme.greyText,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined, size: 18),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passCtrl,
            focusNode: _passFocus,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: AppTheme.greyText,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'At least 6 characters';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryContainer,
          foregroundColor: AppTheme.onPrimaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.onPrimaryContainer,
                ),
              )
            : Text(
                'Sign In',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppTheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Center(
      child: GestureDetector(
        onTap: _loading ? null : _forgotPassword,
        child: Text(
          'Forgot password?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppTheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'New to AeroTAXI?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppTheme.greyText,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppTheme.outlineVariant)),
      ],
    );
  }

  Widget _buildSignupLink() {
    return OutlinedButton(
      onPressed: () => context.push('/signup'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primary,
        side: const BorderSide(color: AppTheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(
        'Create an Account',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildSavedAccountsButton() {
    return GestureDetector(
      onTap: _showSavedAccountsSheet,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Stacked avatars preview
            SizedBox(
              width: _savedAccounts.length > 1
                  ? 20.0 + (_savedAccounts.take(3).length - 1) * 18.0
                  : 28,
              height: 28,
              child: Stack(
                children: [
                  for (int i = _savedAccounts.take(3).length - 1;
                      i >= 0;
                      i--)
                    Positioned(
                      left: i * 18.0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.primaryContainer,
                        child: Text(
                          _savedAccounts[i].initial,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saved Accounts',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  Text(
                    '${_savedAccounts.length} account${_savedAccounts.length == 1 ? '' : 's'} on this device',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppTheme.greyText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Saved accounts bottom sheet ───────────────────────────────────────────────

class _SavedAccountsSheet extends StatefulWidget {
  final List<SavedAccount> accounts;
  final ValueChanged<String> onSelect;
  final Future<void> Function(String email) onRemove;

  const _SavedAccountsSheet({
    required this.accounts,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  State<_SavedAccountsSheet> createState() => _SavedAccountsSheetState();
}

class _SavedAccountsSheetState extends State<_SavedAccountsSheet> {
  late List<SavedAccount> _accounts;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    _accounts = List.from(widget.accounts);
  }

  Future<void> _remove(SavedAccount account) async {
    setState(() => _removing = true);
    await widget.onRemove(account.email);
    if (!mounted) return;
    setState(() {
      _accounts.removeWhere((a) => a.email == account.email);
      _removing = false;
    });
    if (_accounts.isEmpty && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 14, bottom: 20),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved Accounts',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    Text(
                      'Tap to sign in automatically',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppTheme.greyText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Account list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _accounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final acc = _accounts[i];
              return _AccountTile(
                account: acc,
                onTap: () => widget.onSelect(acc.email),
                onRemove: _removing ? null : () => _remove(acc),
              );
            },
          ),

          SizedBox(height: 24 + bottomPad),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final SavedAccount account;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _AccountTile({
    required this.account,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primaryContainer,
              child: Text(
                account.initial,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (account.name.isNotEmpty)
                    Text(
                      account.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    account.email,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppTheme.greyText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Remove button
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: onRemove == null
                      ? AppTheme.outlineVariant.withValues(alpha: 0.4)
                      : AppTheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
