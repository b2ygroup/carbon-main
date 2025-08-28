// lib/screens/onboarding_screen.dart
import 'package:carbon/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:carbon/screens/signup/account_type_screen.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {'icon': Icons.public, 'title': 'Sua Direção Transforma o Planeta', 'description': 'Seja evitando emissões com seu elétrico ou compensando com seu carro a combustão, cada viagem se torna uma ação positiva.', 'color': Colors.cyan[300]!,},
    {'icon': Icons.monetization_on_outlined, 'title': 'Seu Elétrico Gera Dinheiro Real', 'description': 'Dirija seu carro elétrico, evite emissões de CO₂ e veja seu impacto se transformar em B2Y Coins, nossa moeda digital com valor real.', 'color': Colors.greenAccent[400]!,},
    {'icon': Icons.forest_outlined, 'title': 'Seu Carro a Combustão Regenera', 'description': 'Monitore suas emissões e compense sua pegada. Cada contribuição é destinada ao plantio de árvores e projetos ambientais parceiros.', 'color': Colors.amberAccent[400]!,},
    {'icon': Icons.rocket_launch_outlined, 'title': 'Pronto para Começar?', 'description': 'Crie sua conta para começar a ganhar B2Y Coins ou faça login se você já faz parte da nossa comunidade sustentável.', 'color': Colors.purpleAccent[200]!,}
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _markOnboardingAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
  }

  Future<void> _navigateToRegister() async {
    await _markOnboardingAsSeen();
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => const AccountTypeScreen(),
      ));
    }
  }

  Future<void> _navigateToLogin() async {
    await _markOnboardingAsSeen();
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => const AuthScreen(),
      ));
    }
  }

  // <<< NOVA FUNÇÃO PARA O BOTÃO PULAR >>>
  void _skipToLastPage() {
    // Anima a transição para a última página
    _pageController.animateToPage(
      _pages.length - 1,
      duration: 600.ms,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color titleColor = Colors.white;
    final Color descriptionColor = Colors.white.withOpacity(0.85);
    final Color skipButtonColor = Colors.white.withOpacity(0.7);
    final bool isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [ Color(0xFF0A1F2C), Color(0xFF00111A) ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return OnboardingPageContent(data: _pages[index], titleColor: titleColor, descriptionColor: descriptionColor,);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedOpacity(
                    opacity: !isLastPage ? 1.0 : 0.0,
                    duration: 200.ms,
                    child: TextButton(
                      // <<< FUNÇÃO DO BOTÃO ALTERADA >>>
                      onPressed: !isLastPage ? _skipToLastPage : null,
                      child: Text('Pular', style: TextStyle(color: skipButtonColor, fontSize: 16)),
                    ),
                  ),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) => AnimatedContainer(
                      duration: 300.ms,
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      height: 8.0,
                      width: _currentPage == index ? 24.0 : 8.0,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? _pages[_currentPage]['color'] as Color : Colors.grey[800],
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                    )),
                  ),

                  AnimatedSwitcher(
                    duration: 300.ms,
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: isLastPage
                      ? Column(
                          key: const ValueKey('finalActions'),
                          mainAxisSize: MainAxisSize.min, // Adicionado para evitar overflow
                          children: [
                            ElevatedButton(
                              onPressed: _navigateToRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _pages[_currentPage]['color'] as Color,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              ),
                              child: Text('Criar Conta', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _navigateToLogin, 
                              child: const Text('Fazer Login', style: TextStyle(color: Colors.white70))
                            ),
                          ],
                        )
                      : ElevatedButton(
                          key: const ValueKey('nextButton'),
                          onPressed: () {
                             _pageController.nextPage(duration: 400.ms, curve: Curves.easeInOut);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _pages[_currentPage]['color'] as Color,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          ),
                          child: Text('Próximo', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),),
                        ).animate().scale(delay: 100.ms),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPageContent extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color titleColor;
  final Color descriptionColor;

  const OnboardingPageContent({super.key, required this.data, required this.titleColor, required this.descriptionColor,});

  @override
  Widget build(BuildContext context) {
    final Color highlightColor = data['color'] as Color;
    final IconData icon = data['icon'] as IconData;
    final String title = data['title'] as String;
    final String description = data['description'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlightColor.withOpacity(0.1),
              border: Border.all(color: highlightColor.withOpacity(0.3), width: 2),
            ),
            child: Icon(icon, size: 60, color: highlightColor),
          ).animate().scale(duration: 700.ms, curve: Curves.elasticOut).then(delay: 100.ms).shimmer(duration: 1500.ms, color: highlightColor.withOpacity(0.4), angle: 0.8),
          
          const SizedBox(height: 50.0),
          
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.orbitron(fontSize: 26, fontWeight: FontWeight.bold, color: titleColor, shadows: [Shadow(color: highlightColor.withOpacity(0.5), blurRadius: 10)])).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5, duration: 600.ms, curve: Curves.easeOutCubic),
          
          const SizedBox(height: 20.0),
          
          Text(description, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 17, color: descriptionColor, height: 1.5, fontWeight: FontWeight.w400,)).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5, duration: 600.ms, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}