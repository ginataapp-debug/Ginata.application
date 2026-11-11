import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/ginata_theme.dart';

class ServerUnavailableScreen extends StatefulWidget {
  final Future<void> Function() onRetry;
  final VoidCallback onSignOut;

  const ServerUnavailableScreen({
    super.key,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  State<ServerUnavailableScreen> createState() => _ServerUnavailableScreenState();
}

class _ServerUnavailableScreenState extends State<ServerUnavailableScreen> {
  bool _isChecking = false;
  String _message = 'Your account is still saved securely on this device. Reconnect to verify your session and continue.';

  Future<void> _retry() async {
    setState(() => _isChecking = true);
    final connection = await ApiService.checkServerConnection();
    if (!mounted) return;
    if (!connection.isOnline) {
      setState(() {
        _message = connection.message;
        _isChecking = false;
      });
      return;
    }
    await widget.onRetry();
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GinataColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Image.asset('assets/images/brand_mark.png', height: 88),
                  const SizedBox(height: 24),
                  const Text(
                    'Reconnect to Ginata',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: GinataColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: GinataColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isChecking ? null : _retry,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(_isChecking ? 'Checking connection...' : 'Try again'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _isChecking ? null : widget.onSignOut,
                    child: const Text('Sign out on this device'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
