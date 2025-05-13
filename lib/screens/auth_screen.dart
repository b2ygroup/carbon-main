import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:carbon/screens/onboarding_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  late final AnimationController _backgroundController;
  late final Animation<Color?> _startColorAnimation;
  late final Animation<Color?> _endColorAnimation;

  // Cores
  static const Color primaryColor = Color(0xFF00FFFF);
  static const Color secondaryColor = Color(0xFF00BFFF);
  static const Color backgroundColorStart = Color(0xFF011A27);
  static const Color backgroundColorEnd = Color(0xFF000D14);
  static const Color cardBackgroundColor = Color(0xFF0A1F2C);
  static const Color cardBorderColor = Color(0xFF005662);
  static const Color inputBorderColor = Color(0xFF00415A);
  static const Color labelColor = Color(0xFF88C0D0);
  static const Color textColor = Color(0xFFECEFF4);
  static final Color errorColor = Colors.redAccent[100]!;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _startColorAnimation = ColorTween(
      begin: backgroundColorStart,
      end: backgroundColorEnd,
    ).animate(_backgroundController);
    _endColorAnimation = ColorTween(
      begin: backgroundColorEnd,
      end: backgroundColorStart,
    ).animate(_backgroundController);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  void _submitLoginForm() async {
    print("--- Botão Entrar Pressionado ---");
    final isValid = _formKey.currentState?.validate() ?? false;
    print("Formulário válido: $isValid");
    FocusScope.of(context).unfocus();
    if (!isValid) return;
    setState(() => _isLoading = true);
    await Future.delayed(500.ms);

    try {
      print("Tentando Firebase signIn...");
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      print("Firebase signIn SUCESSO!");
    } on FirebaseAuthException catch (err) {
      print("!!! ERRO AUTH: ${err.code} !!!");
      String msg = 'Erro.';
      final map = {
        'user-not-found': 'Email não existe.',
        'wrong-password': 'Senha incorreta.',
        'invalid-credential': 'Inválido.',
      };
      msg = map[err.code] ?? err.message ?? msg;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: errorColor),
        );
      }
    } catch (err, s) {
      print("!!! ERRO GERAL Login: $err\n$s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro inesperado.')),
        );
      }
    } finally {
      print("--- Finalizando _submitLoginForm ---");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToRegisterFlow() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const OnboardingScreen()),
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required IconData prefixIcon,
    required Color labelColor,
    required Color iconColor,
    required Color borderColor,
    required Color focusColor,
    required Color errorColor,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.poppins(
        textStyle: TextStyle(color: labelColor, fontSize: 14),
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Icon(prefixIcon, color: iconColor, size: 22),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
      filled: true,
      fillColor: Colors.black.withOpacity(0.1),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: BorderSide(color: focusColor, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: BorderSide(color: errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: BorderSide(color: errorColor, width: 2.0),
      ),
      errorStyle: TextStyle(color: errorColor.withOpacity(0.9), fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    const currentFocusColor = secondaryColor;
    const currentLabelColor = labelColor;
    const currentIconColor = primaryColor;
    const currentBorderColor = inputBorderColor;
    final currentErrorColor = errorColor;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (ctx, child) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _startColorAnimation.value ?? backgroundColorStart,
                _endColorAnimation.value ?? backgroundColorEnd,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: child,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hub_outlined, size: 70, color: primaryColor)
                      .animate().fadeIn().scale(),
                  const SizedBox(height: 20),
                  Text(
                    'B2Y Carbon Login',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ).animate().fadeIn().slideY(),
                  const SizedBox(height: 50),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25.0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        padding: const EdgeInsets.all(30.0),
                        decoration: BoxDecoration(
                          color: cardBackgroundColor.withOpacity(0.85),
                          border: Border.all(color: cardBorderColor),
                          borderRadius: BorderRadius.circular(25.0),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'Login',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 30),
                              TextFormField(
                                controller: _emailController,
                                style: const TextStyle(
                                    color: textColor, letterSpacing: 0.5),
                                decoration: _inputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icons.alternate_email,
                                  labelColor: currentLabelColor,
                                  iconColor: currentIconColor,
                                  borderColor: currentBorderColor,
                                  focusColor: currentFocusColor,
                                  errorColor: currentErrorColor,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) =>
                                    (v == null || v.isEmpty || !v.contains('@'))
                                        ? 'Inválido'
                                        : null,
                              ).animate().fadeIn().slideY(),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _passwordController,
                                style: const TextStyle(
                                    color: textColor, letterSpacing: 0.5),
                                decoration: _inputDecoration(
                                  labelText: 'Senha',
                                  prefixIcon: Icons.lock_outline,
                                  labelColor: currentLabelColor,
                                  iconColor: currentIconColor,
                                  borderColor: currentBorderColor,
                                  focusColor: currentFocusColor,
                                  errorColor: currentErrorColor,
                                ),
                                obscureText: true,
                                validator: (v) => (v == null || v.length < 6)
                                    ? 'Min 6 chars'
                                    : null,
                              ).animate().fadeIn().slideY(),
                              const SizedBox(height: 40),
                              _isLoading
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 10.0),
                                      child: SpinKitFadingCube(
                                          color: primaryColor, size: 35.0),
                                    )
                                  : ElevatedButton.icon(
                                      icon: const Icon(Icons.login_rounded,
                                          size: 20),
                                      label: const Text('ENTRAR'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.black,
                                        minimumSize:
                                            const Size(double.infinity, 52),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15.0),
                                        ),
                                        textStyle: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                        elevation: 8,
                                        shadowColor:
                                            primaryColor.withOpacity(0.6),
                                      ),
                                      onPressed: _submitLoginForm,
                                    ).animate().fadeIn().scale(),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _goToRegisterFlow,
                                child: Text(
                                  'Criar conta',
                                  style: GoogleFonts.poppins(
                                    color: textColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn().slideY(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
