// lib/screens/auth_screen.dart (VERSÃO COMPLETA E CORRIGIDA)
import 'dart:ui';
import 'package:carbon/screens/onboarding_screen.dart';
import 'package:carbon/services/wallet_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Importante para a lógica web
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final isValid = _formKey.currentState?.validate() ?? false;
    FocusScope.of(context).unfocus();
    if (!isValid) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (err) {
      String msg = 'Erro de autenticação.';
      final map = {
        'user-not-found': 'Email não encontrado.',
        'wrong-password': 'Senha incorreta.',
        'invalid-credential': 'Credenciais inválidas.',
      };
      msg = map[err.code] ?? err.message ?? msg;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: errorColor),
        );
      }
    } catch (err) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ocorreu um erro inesperado.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // FUNÇÃO DE LOGIN COM GOOGLE ATUALIZADA PARA USAR REDIRECT
  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      // Para a web, sempre usamos o fluxo de redirecionamento que é mais robusto
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        // Esta linha inicia o redirecionamento. O main.dart cuida do resto.
        await FirebaseAuth.instance.signInWithRedirect(googleProvider);
      } else {
        // Se um dia precisar para mobile, a lógica antiga com `GoogleSignIn().signIn()` entraria aqui.
        throw Exception("Login com Google para mobile não implementado.");
      }
    } catch (err) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao iniciar login com Google: $err"), backgroundColor: errorColor)
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _goToRegisterFlow() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const OnboardingScreen()),
    );
  }
  
  // O resto do ficheiro (build, _inputDecoration, etc.) continua igual ao que você forneceu...
  // ...
  // [CÓDIGO COMPLETO DA UI ABAIXO]
  // ...

  void _showContactDialog() {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBackgroundColor.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: cardBorderColor)
        ),
        title: Row(
          children: [
            const Icon(Icons.support_agent, color: primaryColor),
            const SizedBox(width: 10),
            Text("Entre em Contato", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContactRow(Icons.public, "Website", "group-tau.vercel.app", "https://group-tau.vercel.app/"),
            _buildContactRow(Icons.email_outlined, "Email", "b2ylion@gmail.com", "mailto:b2ylion@gmail.com"),
            _buildContactRow(Icons.phone_iphone_rounded, "Celular", "+55 11 96552-0979", "https://wa.me/5511965520979"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(), 
            child: const Text("Fechar", style: TextStyle(color: secondaryColor))
          )
        ],
      )
    );
  }
  
  Widget _buildContactRow(IconData icon, String label, String value, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () async {
          final Uri uri = Uri.parse(url);
          if (!await launchUrl(uri)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Não foi possível abrir o link.'), backgroundColor: errorColor),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(icon, color: labelColor, size: 20),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(color: labelColor, fontSize: 12)),
                Text(value, style: GoogleFonts.poppins(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            )
          ],
        ),
      ),
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
    const currentFocusColor = secondaryColor;
    const currentLabelColor = labelColor;
    const currentIconColor = primaryColor;
    const currentBorderColor = inputBorderColor;
    final currentErrorColor = errorColor;

    final Widget footer = Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        children: [
          Text(
            "Desenvolvido por B2Y Group",
            style: GoogleFonts.poppins(
              color: labelColor.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          IconButton(
            icon: const Icon(Icons.support_agent_rounded, color: primaryColor),
            tooltip: "Entrar em contato",
            onPressed: _showContactDialog,
          )
          .animate(onPlay: (controller) => controller.repeat())
          .shake(hz: 2, duration: 1500.ms, curve: Curves.easeInOutCubic)
          .then(delay: 2000.ms),
        ],
      ),
    );

    final Widget mainContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
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
                            enabled: !_isLoading,
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
                                    ? 'Email inválido.'
                                    : null,
                          ).animate().fadeIn().slideY(),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !_isLoading,
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
                                ? 'A senha deve ter no mínimo 6 caracteres.'
                                : null,
                          ).animate().fadeIn().slideY(),
                          const SizedBox(height: 40),
                          if (_isLoading)
                            const Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: 10.0),
                                child: SpinKitFadingCube(
                                    color: primaryColor, size: 35.0),
                              )
                          else ...[
                              ElevatedButton.icon(
                                  icon: const Icon(Icons.login_rounded, size: 20),
                                  label: const Text('ENTRAR'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.black,
                                    minimumSize: const Size(double.infinity, 52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15.0),
                                    ),
                                    textStyle: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                    elevation: 8,
                                    shadowColor: primaryColor.withOpacity(0.6),
                                  ),
                                  onPressed: _submitLoginForm,
                                ).animate().fadeIn().scale(),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  const Expanded(child: Divider(color: inputBorderColor)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text("OU", style: GoogleFonts.poppins(color: labelColor, fontSize: 12)),
                                  ),
                                  const Expanded(child: Divider(color: inputBorderColor)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                icon: Image.asset('assets/images/google_logo.png', height: 20.0),
                                label: const Text('Entrar com Google'),
                                onPressed: _googleSignIn,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: textColor,
                                  minimumSize: const Size(double.infinity, 52),
                                  side: const BorderSide(color: inputBorderColor),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                                  textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                              ).animate().fadeIn(delay: 200.ms),
                            ],
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _isLoading ? null : _goToRegisterFlow,
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
    );

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
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: mainContent,
              ),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}