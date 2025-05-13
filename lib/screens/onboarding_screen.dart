// lib/screens/onboarding_screen.dart (Garantindo Build Completo)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Garanta que está no pubspec

// Importa a tela de Seleção de Tipo de Conta
import 'package:carbon/screens/signup/account_type_screen.dart'; // CONFIRME NOME PACOTE

// Importa o AuthWrapper para o botão Pular
import 'package:carbon/main.dart'; // CONFIRME NOME PACOTE

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Conteúdo das páginas
  final List<Map<String, dynamic>> _pages = [
    { 'icon': Icons.electric_car_outlined, 'title': 'Dirija seu Elétrico', 'description': 'Monitore suas viagens e veja o impacto positivo.', 'color': Colors.blue[300]!, },
    { 'icon': Icons.eco_outlined, 'title': 'Gere Créditos de Carbono', 'description': 'KMs sem emissão viram créditos valorizados.', 'color': Colors.green[300]!, },
    { 'icon': Icons.paid_outlined, 'title': 'Ganhe Dinheiro e Contribua', 'description': 'Venda créditos ou compense emissões no app.', 'color': Colors.amber[300]!, },
    { 'icon': Icons.rocket_launch_outlined, 'title': 'Pronto para Começar?', 'description': 'Selecione seu tipo de conta e cadastre-se!', 'color': Colors.purple[300]!, }
  ];

  @override void dispose() { _pageController.dispose(); super.dispose(); }
  void _onPageChanged(int page) { setState(() { _currentPage = page; }); }

  // Navega para a tela de Seleção de Tipo de Conta
  void _navigateToRegistration() {
    // Garante que AccountTypeScreen exista em lib/screens/signup/
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => const AccountTypeScreen(),
    ));
  }

  // Navega para o Wrapper (Login) se pular
  void _skipToAuth() {
     Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => const AuthWrapper(),
    ));
  }

  // ***** BUILD COMPLETO PARA _OnboardingScreenState *****
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Retorna o Scaffold principal da tela de Onboarding
    return Scaffold(
      body: Container(
        // Fundo pode usar gradiente do tema ou cor sólida
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.scaffoldBackgroundColor, theme.scaffoldBackgroundColor.withOpacity(0.9)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter
          )
        ),
        child: Column( // Organiza PageView e controles
          children: [
            Expanded( // PageView ocupa a maior parte da tela
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  // Retorna o widget que constrói o conteúdo de cada página
                  return OnboardingPageContent( data: _pages[index] );
                } // Fim itemBuilder
              ) // Fim PageView.builder
            ), // Fim Expanded
            // Barra inferior com indicador de página e botões
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Botão Pular (some na última página)
                  AnimatedOpacity(
                    opacity: _currentPage != _pages.length - 1 ? 1.0 : 0.0,
                    duration: 200.ms,
                    child: TextButton(
                      onPressed: _currentPage != _pages.length - 1 ? _skipToAuth : null, // Desabilita na última pág
                      child: Text('Pular', style: TextStyle(color: Colors.grey[400]))
                    ),
                  ),
                  // Indicador de Bolinhas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) => AnimatedContainer(
                      duration: 300.ms, // Usa extensão do flutter_animate
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      height: 8.0,
                      width: _currentPage == index ? 24.0 : 8.0,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? theme.colorScheme.primary : Colors.grey[700],
                        borderRadius: BorderRadius.circular(4.0)
                      ),
                    )) // Fim List.generate
                  ), // Fim Row Indicador
                  // Botão Próximo / Começar Cadastro
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _pages.length - 1) {
                        _navigateToRegistration(); // Ação final
                      } else {
                        _pageController.nextPage( duration: 400.ms, curve: Curves.easeInOut ); // Próxima página
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1 ? 'Começar Cadastro' : 'Próximo',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)
                    ),
                  ).animate().scale(delay: 100.ms) // Animação sutil
                ], // Fim children Row inferior
              ), // Fim Row inferior
            ), // Fim Padding inferior
          ], // Fim children Column principal
        ), // Fim Container principal
      ), // Fim Scaffold
    ); // Fim return Scaffold
  } // Fim build _OnboardingScreenState
} // Fim classe _OnboardingScreenState


// ***** Widget OnboardingPageContent COMPLETO *****
class OnboardingPageContent extends StatelessWidget {
  final Map<String, dynamic> data;
  const OnboardingPageContent({ super.key, required this.data});

  @override
  Widget build(BuildContext context) { // <-- BUILD COMPLETO AQUI
    final theme = Theme.of(context);
    // Extrai dados do mapa para clareza
    final Color color = data['color'] as Color;
    final IconData icon = data['icon'] as IconData;
    final String title = data['title'] as String;
    final String description = data['description'] as String;

    // Retorna o conteúdo da página
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Centraliza verticalmente
        children: [
          // Ícone animado
          CircleAvatar(
            radius: 60, backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, size: 60, color: color),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut), // Animação no ícone
          const SizedBox(height: 40.0),
          // Título animado
          Text(title, textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani( textStyle: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)))
            .animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, duration: 400.ms), // Animação no título
          const SizedBox(height: 20.0),
          // Descrição animada
          Text(description, textAlign: TextAlign.center,
            style: GoogleFonts.poppins( textStyle: theme.textTheme.bodyLarge?.copyWith(color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8), height: 1.5)))
            .animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, duration: 400.ms), // Animação na descrição
        ],
      ),
    ); // Fim Padding
  } // Fim build OnboardingPageContent
} // Fim classe OnboardingPageContent