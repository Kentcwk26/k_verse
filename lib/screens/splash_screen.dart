import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../viewmodels/auth_viewmodel.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _dotController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  int _dotCount = 0;
  bool _isLoading = true;
  String _loadingText = "loading_text".tr();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkLogin();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.elasticOut),
    );

    _fadeController.forward();

    _dotController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        )..addListener(() {
          if (_dotController.status == AnimationStatus.completed) {
            _dotController.reverse();
          } else if (_dotController.status == AnimationStatus.dismissed) {
            _dotController.forward();
          }
        });
    _dotController.forward();
    _startDotAnimation();
  }

  void _startDotAnimation() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return false;
      setState(() {
        _dotCount = (_dotCount + 1) % 6;
      });
      return _isLoading;
    });
  }

  Future<void> _checkLogin() async {
    try {
      final authVM = context.read<AuthViewModel>();

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      setState(() {
        _loadingText = "splash.checking_auth".tr();
      });

      final targetPage = await authVM.checkLoginStatus();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadingText = "";
      });

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => targetPage,
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadingText = "splash.error_loading".tr();
      });

      await _showErrorDialog(e.toString());
    }
  }

  Future<void> _showErrorDialog(String error) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('splash.error_dialog_title'.tr()),
        content: Text('splash.error_dialog_content'.tr(args: [error])),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retryLoading();
            },
            child: Text('retry'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showFallbackScreen();
            },
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  void _retryLoading() {
    setState(() {
      _isLoading = true;
      _loadingText = "loading_text".tr();
      _dotCount = 0;
    });
    _checkLogin();
  }

  void _showFallbackScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FlutterLogo(size: 80),
                const SizedBox(height: 20),
                Text(
                  'splash.fallback_title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'splash.fallback_message'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _retryLoading,
                  child: Text('common.retry'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo-removebg.png', width: 180, height: 180),
                const SizedBox(height: 40),
                if (_isLoading) ...[
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 30),
                ],
                Text(
                  "$_loadingText ${_isLoading ? '.' * _dotCount : ''}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),

                if (!_isLoading && _loadingText == "splash.error_loading".tr()) ...[
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _retryLoading,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                    child: Text('common.retry'.tr()),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}