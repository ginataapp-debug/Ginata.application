import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/ginata_theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final String? googleAuthMessage;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    this.googleAuthMessage,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Mode: 0 = Sign In, 1 = Sign Up
  int _authMode = 0;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (Uri.base.queryParameters['mode'] == 'signup') _authMode = 1;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
        );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final redirectUri = kIsWeb
          ? AuthService.googleWebRedirectUri(Uri.base)
          : AuthService.androidGoogleRedirectUri;
      final result = await AuthService.beginGoogleSignIn(
        redirectUri: redirectUri,
      );
      if (!mounted) return;
      if (result['success'] != true) {
        _showError(
          result['message']?.toString() ?? 'Could not start Google sign-in.',
        );
        return;
      }

      final opened = await launchUrl(
        Uri.parse(result['url']!.toString()),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        await AuthService.cancelGoogleSignIn();
        _showError('Could not open Google sign-in. Please try again.');
        return;
      }
      if (!kIsWeb) {
        _showNotice(
          'Complete Google sign-in in your browser, then return to Ginata.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showError('Google sign-in could not be started. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_authMode == 0) {
        // Sign In
        final res = await AuthService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (!mounted) return;

        if (res['verification_required'] == true) {
          await _confirmEmail(isNewAccount: false);
        } else if (res['success'] == true) {
          await _showSessionConfirmation(
            host: (res['host'] as Map<String, dynamic>?) ?? {},
            message: res['message'] ?? 'Signed in securely.',
            isNewAccount: false,
          );
        } else {
          _showError(res['message'] ?? 'Invalid email or password.');
        }
      } else {
        // Sign Up
        if (_passwordController.text != _confirmPasswordController.text) {
          _showError('Passwords do not match.');
          setState(() => _isLoading = false);
          return;
        }

        final res = await AuthService.signUp(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
        );

        if (!mounted) return;

        if (res['success'] == true && res['verification_required'] == true) {
          await _confirmEmail(isNewAccount: true);
        } else if (res['success'] == true) {
          await _showSessionConfirmation(
            host: (res['host'] as Map<String, dynamic>?) ?? {},
            message: res['message'] ?? 'Account created successfully!',
            isNewAccount: true,
          );
        } else {
          _showError(res['message'] ?? 'Unable to create account.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Connection error. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmEmail({required bool isNewAccount}) async {
    final codeController = TextEditingController();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    bool busy = false;
    String? error;
    String notice = isNewAccount
        ? 'A six-digit code was emailed to $email.'
        : 'Enter your code for $email, or request a new one below.';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: const Text('Confirm your email'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notice),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Six-digit code',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Codes expire and can only be used once. Check your spam folder.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        setDialogState(() {
                          busy = true;
                          error = null;
                        });
                        final response = await AuthService.sendVerification(
                          email,
                          password,
                        );
                        if (!ctx.mounted) return;
                        setDialogState(() {
                          busy = false;
                          if (response['success'] == true) {
                            notice =
                                response['message']?.toString() ?? 'Code sent.';
                          } else {
                            error =
                                response['message']?.toString() ??
                                'Could not send code.';
                          }
                        });
                      },
                child: const Text('Send new code'),
              ),
              ElevatedButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!RegExp(
                          r'^[0-9]{6}$',
                        ).hasMatch(codeController.text)) {
                          setDialogState(
                            () => error = 'Enter the six-digit code.',
                          );
                          return;
                        }
                        setDialogState(() {
                          busy = true;
                          error = null;
                        });
                        final response = await AuthService.verifyEmail(
                          email,
                          codeController.text,
                        );
                        if (!ctx.mounted) return;
                        if (response['success'] == true) {
                          Navigator.of(ctx).pop(response);
                        } else {
                          setDialogState(() {
                            busy = false;
                            error =
                                response['message']?.toString() ??
                                'Could not confirm email.';
                          });
                        }
                      },
                child: Text(busy ? 'Please wait...' : 'Confirm email'),
              ),
            ],
          ),
        ),
      ),
    );
    codeController.dispose();
    if (!mounted || result == null) return;
    await _showSessionConfirmation(
      host: (result['host'] as Map<String, dynamic>?) ?? {},
      message: result['message']?.toString() ?? 'Email confirmed.',
      isNewAccount: isNewAccount,
    );
  }

  Future<void> _showPasswordReset() async {
    final resetEmail = await showDialog<String>(
      context: context,
      builder: (_) =>
          _PasswordResetDialog(initialEmail: _emailController.text.trim()),
    );
    if (!mounted || resetEmail == null) return;
    _emailController.text = resetEmail;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password updated. Sign in with your new password.'),
        backgroundColor: GinataColors.primary,
      ),
    );
  }

  Future<void> _showSessionConfirmation({
    required Map<String, dynamic> host,
    required String message,
    required bool isNewAccount,
  }) async {
    if (!mounted) return;
    final name = (host['full_name'] ?? _nameController.text.trim()).toString();
    final email = (host['email'] ?? _emailController.text.trim()).toString();
    final phone = (host['phone'] ?? _phoneController.text.trim()).toString();
    final verified = host['is_verified'] == true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GinataColors.secondaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.verified_user,
                color: GinataColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isNewAccount ? 'Account Created' : 'Signed In Securely',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: GinataColors.primary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: GinataColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            _confirmRow(
              Icons.person_outline,
              'Host',
              name.isNotEmpty ? name : 'Host',
            ),
            _confirmRow(Icons.email_outlined, 'Email', email),
            if (phone.isNotEmpty)
              _confirmRow(Icons.phone_outlined, 'Phone', phone),
            _confirmRow(
              verified ? Icons.verified : Icons.pending_outlined,
              'Status',
              verified ? 'Verified account' : 'Pending verification',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GinataColors.surfaceSubdued,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: GinataColors.secondary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your device uses an expiring session token. Use HTTPS for secure connections. Signing out revokes this device\'s session.',
                      style: TextStyle(
                        fontSize: 11,
                        color: GinataColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GinataColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Continue to Dashboard',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
    if (mounted) widget.onLoginSuccess();
  }

  Widget _confirmRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: GinataColors.secondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: GinataColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: GinataColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: GinataColors.alertTerracotta,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      );
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: GinataColors.primary),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2EB),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: isWide
                      ? Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 1240,
                              minHeight: constraints.maxHeight,
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(28),
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: GinataColors.surface,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: const Color(0x1C003329),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: GinataColors.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    blurRadius: 48,
                                    offset: const Offset(0, 20),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 11, child: _buildStoryPanel()),
                                  Expanded(
                                    flex: 10,
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 48,
                                        vertical: 40,
                                      ),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: constraints.maxHeight - 80,
                                        ),
                                        child: Center(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 440,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _buildDesktopBrand(),
                                                const SizedBox(height: 48),
                                                Text(
                                                  _authMode == 0
                                                      ? 'Welcome back'
                                                      : 'Make room for better hosting',
                                                  style: const TextStyle(
                                                    color: GinataColors
                                                        .textPrimary,
                                                    fontSize: 30,
                                                    height: 1.12,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -1.1,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  _authMode == 0
                                                      ? 'Your stays are in good hands. Sign in to pick up where you left off.'
                                                      : 'Create your host account and bring every stay into one considered workspace.',
                                                  style: const TextStyle(
                                                    color: GinataColors
                                                        .textSecondary,
                                                    fontSize: 14,
                                                    height: 1.55,
                                                  ),
                                                ),
                                                const SizedBox(height: 28),
                                                _buildCard(),
                                                const SizedBox(height: 18),
                                                _buildFooter(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildHeader(),
                                  const SizedBox(height: 28),
                                  Text(
                                    _authMode == 0
                                        ? 'Your properties, in good hands.'
                                        : 'A better home for your hosting.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: GinataColors.textPrimary,
                                      fontSize: 25,
                                      height: 1.15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _authMode == 0
                                        ? 'Sign in to your calm, connected host workspace.'
                                        : 'One thoughtful workspace for every stay.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: GinataColors.textSecondary,
                                      fontSize: 14,
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildCard(),
                                  const SizedBox(height: 18),
                                  _buildFooter(),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE5EAE1),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Image.asset(
              'assets/images/brand_mark.png',
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.park_outlined,
                size: 34,
                color: GinataColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GINATA',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: GinataColors.primary,
                  letterSpacing: 4.2,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'THE HOST WORKSPACE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: GinataColors.textMuted,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBrand() {
    return Row(
      children: [
        Image.asset(
          'assets/images/brand_mark.png',
          width: 40,
          height: 40,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.park_outlined,
            size: 36,
            color: GinataColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'GINATA',
          style: TextStyle(
            color: GinataColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.2,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F5EF),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 14,
                color: GinataColors.primary,
              ),
              SizedBox(width: 6),
              Text(
                'SECURE HOST ACCESS',
                style: TextStyle(
                  color: GinataColors.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStoryPanel() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF174B3E), Color(0xFF062C25)],
            ),
          ),
        ),
        Positioned(
          top: -150,
          right: -155,
          child: Container(
            width: 390,
            height: 390,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
        ),
        Positioned(
          top: -95,
          right: -100,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(36),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2E9),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Image.asset(
                        'assets/images/brand_mark.png',
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.park_outlined,
                              color: GinataColors.primary,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'GINATA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 44),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        color: Color(0xFFE1C38B),
                        size: 15,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'MADE FOR THE WAY YOU HOST',
                        style: TextStyle(
                          color: Color(0xFFF0E8D7),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'A more\nthoughtful stay\nstarts here.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    height: 1.08,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.8,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Bring your properties, guests, and the little details of great hosting into one beautifully clear place.',
                  style: TextStyle(
                    color: Color(0xFFD4E2D9),
                    fontSize: 15,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Row(
                    children: [
                      _StoryIcon(icon: Icons.calendar_month_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Every stay, in rhythm',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Bookings, guest details, and finances together.',
                              style: TextStyle(
                                color: Color(0xFFD4E2D9),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_outward_rounded,
                        color: Color(0xFFE1C38B),
                        size: 17,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'DESIGNED FOR INDEPENDENT HOSTS',
                  style: TextStyle(
                    color: Color(0xFFAEC7B8),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: GinataColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x12101828)),
        boxShadow: [
          BoxShadow(
            color: GinataColors.primary.withValues(alpha: 0.055),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Switcher Tab
            Container(
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: GinataColors.surfaceSubdued,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (_authMode != 0) {
                          setState(() => _authMode = 0);
                        }
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _authMode == 0
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _authMode == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _authMode == 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: _authMode == 0
                                ? GinataColors.primary
                                : GinataColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (_authMode != 1) {
                          setState(() => _authMode = 1);
                        }
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _authMode == 1
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _authMode == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _authMode == 1
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: _authMode == 1
                                ? GinataColors.primary
                                : GinataColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                icon: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GinataColors.textPrimary,
                  side: BorderSide(
                    color: const Color(0xFF172B24).withValues(alpha: 0.14),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (widget.googleAuthMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                widget.googleAuthMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GinataColors.alertTerracotta,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Divider(color: Colors.black.withValues(alpha: 0.1)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR CONTINUE WITH EMAIL',
                    style: TextStyle(
                      color: GinataColors.textMuted.withValues(alpha: 0.9),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: Colors.black.withValues(alpha: 0.1)),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (_authMode == 1) ...[
              // Full Name
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Host Full Name *',
                  hintText: 'e.g. Clara Kariuki',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
                validator: (val) {
                  if (_authMode == 1 && (val == null || val.trim().isEmpty)) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
            ],

            // Email
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Host Email Address *',
                hintText: 'host@ginata.ke',
                prefixIcon: Icon(Icons.email_outlined, size: 20),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!val.contains('@') || !val.contains('.')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            if (_authMode == 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _showPasswordReset,
                  child: const Text('Forgot password?'),
                ),
              ),

            if (_authMode == 1) ...[
              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  hintText: '+254 700 000 000',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Password
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: _authMode == 1
                  ? TextInputAction.next
                  : TextInputAction.done,
              onFieldSubmitted: (_) {
                if (_authMode == 0) _handleSubmit();
              },
              decoration: InputDecoration(
                labelText: 'Password *',
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Please enter your password';
                }
                if (_authMode == 1 && val.length < 10) {
                  return 'Password must be at least 10 characters';
                }
                return null;
              },
            ),

            if (_authMode == 1) ...[
              const SizedBox(height: 14),
              // Confirm Password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleSubmit(),
                decoration: const InputDecoration(
                  labelText: 'Confirm Password *',
                  hintText: '••••••••',
                  prefixIcon: Icon(Icons.lock_reset_outlined, size: 20),
                ),
                validator: (val) {
                  if (_authMode == 1 && (val == null || val.isEmpty)) {
                    return 'Please confirm your password';
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 22),

            // Submit Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GinataColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _authMode == 0
                            ? 'Sign In to Host Portal'
                            : 'Create Host Account',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.shield_outlined,
          size: 14,
          color: GinataColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _authMode == 0
                ? 'Secure token session · Verified against the cloud'
                : 'Password protected with PBKDF2-SHA256 hashing',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: GinataColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryIcon extends StatelessWidget {
  const _StoryIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: const Color(0xFFE1C38B).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Icon(icon, color: const Color(0xFFE1C38B), size: 21),
  );
}

class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  var _busy = false;
  var _codeSent = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid account email.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final response = await AuthService.requestPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (response['success'] == true) {
        _codeSent = true;
        _notice =
            response['message']?.toString() ??
            'If an account exists for that email, a reset code has been sent.';
      } else {
        _error =
            response['message']?.toString() ??
            'Could not request a reset code.';
      }
    });
  }

  Future<void> _resetPassword() async {
    if (!RegExp(r'^[0-9]{6}$').hasMatch(_codeController.text)) {
      setState(() => _error = 'Enter the six-digit reset code.');
      return;
    }
    if (_passwordController.text.length < 10) {
      setState(() => _error = 'Password must be at least 10 characters.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final response = await AuthService.resetPassword(
      email: _emailController.text,
      code: _codeController.text,
      newPassword: _passwordController.text,
    );
    if (!mounted) return;
    if (response['success'] == true) {
      Navigator.pop(context, _emailController.text.trim());
    } else {
      setState(() {
        _busy = false;
        _error =
            response['message']?.toString() ?? 'Could not reset your password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reset your password'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'We’ll email a one-time reset code if this account exists.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Account email'),
          ),
          if (_codeSent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'Six-digit reset code',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              enabled: !_busy,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              enabled: !_busy,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
              ),
            ),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 12),
            Text(
              _notice!,
              style: const TextStyle(color: GinataColors.secondary),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: GinataColors.alertTerracotta),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _busy ? null : _requestCode,
        child: Text(_codeSent ? 'Resend code' : 'Send code'),
      ),
      if (_codeSent)
        ElevatedButton(
          onPressed: _busy ? null : _resetPassword,
          child: Text(_busy ? 'Please wait...' : 'Reset password'),
        ),
    ],
  );
}
