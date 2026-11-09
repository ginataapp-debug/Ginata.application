import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/ginata_theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final success = await AuthService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        widget.onLoginSuccess();
      } else {
        _showError('Invalid email or password. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Connection error. Please check your network and try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD92D20),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: GinataColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 40),
                        _buildLoginCard(),
                        const SizedBox(height: 24),
                        _buildFooterText(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GinataColors.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Image.asset(
            'assets/images/logo.png',
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.villa,
              size: 64,
              color: GinataColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'GINATA',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: GinataColors.primary,
            letterSpacing: 6,
            fontFeatures: const [FontFeature.enable('smcp')],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Property Management',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: GinataColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: GinataColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEmailField(),
              const SizedBox(height: 18),
              _buildPasswordField(),
              const SizedBox(height: 28),
              _buildSignInButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      focusNode: _emailFocusNode,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      enabled: !_isLoading,
      autocorrect: false,
      onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: GinataColors.textPrimary,
      ),
      decoration: _inputDecoration(
        label: 'Email address',
        hint: 'you@example.com',
        prefixIcon: Icons.email_outlined,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      enabled: !_isLoading,
      onFieldSubmitted: (_) => _handleLogin(),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: GinataColors.textPrimary,
      ),
      decoration: _inputDecoration(
        label: 'Password',
        hint: '••••••••',
        prefixIcon: Icons.lock_outline,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: GinataColors.textSecondary,
            size: 20,
          ),
          splashRadius: 20,
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        color: GinataColors.textSecondary.withValues(alpha: 0.5),
        fontWeight: FontWeight.w400,
        fontSize: 14,
      ),
      labelStyle: TextStyle(
        color: GinataColors.textSecondary,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      floatingLabelStyle: TextStyle(
        color: GinataColors.primary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(prefixIcon, size: 20, color: GinataColors.textSecondary),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: GinataColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.black.withValues(alpha: 0.08),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.black.withValues(alpha: 0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: GinataColors.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFD92D20),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFD92D20),
          width: 1.5,
        ),
      ),
      errorStyle: const TextStyle(fontSize: 12),
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: GinataColors.primary,
          disabledBackgroundColor: GinataColors.primary.withValues(alpha: 0.7),
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Sign In',
                  key: ValueKey('sign_in_text'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFooterText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.shield_outlined,
          size: 14,
          color: GinataColors.textSecondary.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 6),
        Text(
          'Secure host access · Session saved',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: GinataColors.textSecondary.withValues(alpha: 0.6),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
