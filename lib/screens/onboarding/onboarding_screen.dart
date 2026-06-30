import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/colors.dart';
import '../../core/services/auth_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  bool _loading = false;
  String? _error;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _showEmail = false;
  bool _isCreatingAccount = false;
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl     = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _auth.signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() { _error = 'Google sign-in failed. Please try again.'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _signInWithApple() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _auth.signInWithApple();
    } catch (e) {
      if (mounted) setState(() { _error = 'Apple sign-in failed. Please try again.'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _submitEmail() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final name     = _nameCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) return;
    if (_isCreatingAccount && name.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (_isCreatingAccount) {
        await _auth.createAccountWithEmail(email, password, name);
      } else {
        await _auth.signInWithEmail(email, password);
      }
    } on Exception catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: Stack(
          children: [
            // Background gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0A0A14), Color(0xFF0F0F0F), Color(0xFF0F0F0F)],
                    stops: [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Subtle gold radial glow behind logo
            Positioned(
              top: size.height * 0.10,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  width: 220, height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.gold.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: size.height - MediaQuery.of(context).padding.top),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 52),

                              // App icon
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.gold.withOpacity(0.3),
                                      blurRadius: 30,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 28),

                              // Headline
                              const Text(
                                'Dig Deeper',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Lora',
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warmWhite,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'AI-guided Bible study that goes\nbeyond the surface.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  color: AppColors.warmWhite.withOpacity(0.55),
                                  height: 1.55,
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Feature pills
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: const [
                                  _FeaturePill(icon: Icons.psychology_outlined,       label: 'AI Study'),
                                  _FeaturePill(icon: Icons.group_outlined,             label: 'Group Study'),
                                  _FeaturePill(icon: Icons.route_outlined,             label: 'Reading Plans'),
                                  _FeaturePill(icon: Icons.auto_awesome_outlined,      label: 'Daily Verse'),
                                ],
                              ),

                              const Spacer(),

                              // Error
                              if (_error != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.error.withOpacity(0.35)),
                                  ),
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Auth area
                              if (_showEmail) ...[
                                _EmailForm(
                                  emailCtrl: _emailCtrl,
                                  passwordCtrl: _passwordCtrl,
                                  nameCtrl: _nameCtrl,
                                  isCreatingAccount: _isCreatingAccount,
                                  loading: _loading,
                                  onToggleMode: () => setState(() => _isCreatingAccount = !_isCreatingAccount),
                                  onSubmit: _submitEmail,
                                  onBack: () => setState(() { _showEmail = false; _error = null; }),
                                ),
                              ] else ...[
                                // Apple
                                _AuthButton(
                                  onTap: _loading ? null : _signInWithApple,
                                  loading: _loading,
                                  backgroundColor: AppColors.warmWhite,
                                  foregroundColor: AppColors.black,
                                  icon: Icons.apple,
                                  label: 'Continue with Apple',
                                ),
                                const SizedBox(height: 10),
                                // Google
                                _AuthButton(
                                  onTap: _loading ? null : _signInWithGoogle,
                                  loading: _loading,
                                  backgroundColor: const Color(0xFF1C1C1C),
                                  foregroundColor: AppColors.warmWhite,
                                  icon: Icons.g_mobiledata,
                                  label: 'Continue with Google',
                                  border: Border.all(color: AppColors.warmWhite.withOpacity(0.12)),
                                ),
                                const SizedBox(height: 10),
                                // Email
                                _AuthButton(
                                  onTap: _loading ? null : () => setState(() => _showEmail = true),
                                  loading: false,
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: AppColors.warmWhite.withOpacity(0.5),
                                  icon: Icons.email_outlined,
                                  label: 'Continue with Email',
                                  border: Border.all(color: AppColors.warmWhite.withOpacity(0.1)),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Terms
                              Text(
                                'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  color: AppColors.warmWhite.withOpacity(0.28),
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Auth Button ───────────────────────────────────────────────────────────────

class _AuthButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final String label;
  final BoxBorder? border;

  const _AuthButton({
    required this.onTap,
    required this.loading,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.label,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: border,
          ),
          child: loading
              ? Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: foregroundColor),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: foregroundColor, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: foregroundColor,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Feature Pill ─────────────────────────────────────────────────────────────

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Email Form ────────────────────────────────────────────────────────────────

class _EmailForm extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController nameCtrl;
  final bool isCreatingAccount;
  final bool loading;
  final VoidCallback onToggleMode;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _EmailForm({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.nameCtrl,
    required this.isCreatingAccount,
    required this.loading,
    required this.onToggleMode,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isCreatingAccount) ...[
          _Field(controller: nameCtrl, hint: 'Your name', icon: Icons.person_outline),
          const SizedBox(height: 10),
        ],
        _Field(
          controller: emailCtrl,
          hint: 'Email',
          icon: Icons.email_outlined,
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 10),
        _Field(
          controller: passwordCtrl,
          hint: 'Password',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: loading ? null : onSubmit,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                    )
                  : Text(
                      isCreatingAccount ? 'Create Account' : 'Sign In',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: onBack,
              child: Text('← Back',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                  color: AppColors.warmWhite.withOpacity(0.45))),
            ),
            GestureDetector(
              onTap: onToggleMode,
              child: Text(
                isCreatingAccount ? 'Already have an account?' : 'Create account',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.gold),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboard;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(color: AppColors.warmWhite, fontFamily: 'Inter'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.warmWhite.withOpacity(0.35), fontFamily: 'Inter'),
        prefixIcon: Icon(icon, color: AppColors.warmWhite.withOpacity(0.35), size: 18),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.gold.withOpacity(0.5), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
