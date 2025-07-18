// lib/screens/buy_coins_screen.dart (VERSÃO CORRIGIDA)

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// Uma classe simples para organizar os dados de cada pacote de moedas.
class CoinPackage {
  final String stripePriceId;
  final String name;
  final String description;
  final String priceDisplay;
  final IconData icon;

  CoinPackage({
    required this.stripePriceId,
    required this.name,
    required this.description,
    required this.priceDisplay,
    this.icon = Icons.monetization_on,
  });
}

class BuyCoinsScreen extends StatefulWidget {
  const BuyCoinsScreen({super.key});

  @override
  State<BuyCoinsScreen> createState() => _BuyCoinsScreenState();
}

class _BuyCoinsScreenState extends State<BuyCoinsScreen> {
  // ATENÇÃO:
  // Substitua os valores 'stripePriceId' pelos IDs de Preço REAIS do seu painel Stripe.
  final List<CoinPackage> _packages = [
    CoinPackage(
      stripePriceId: 'price_1RlIsQ4Ie0XV5ATGB0X5KtaM',
      name: 'Pacote Bronze',
      description: '100 moedas',
      priceDisplay: 'R\$ 4,99',
    ),
    CoinPackage(
      stripePriceId: 'price_1RlJGu4Ie0XV5ATGNDDcpsCJ',
      name: 'Pacote Prata',
      description: '200 moedas',
      priceDisplay: 'R\$ 8,99',
    ),
    CoinPackage(
      stripePriceId: 'price_1RlT1z4Ie0XV5ATGBRhI9ATa',
      name: 'Pacote Ouro',
      description: '300 moedas',
      priceDisplay: 'R\$ 17,99',
    ),
  ];

  String? _loadingPriceId;

  Future<void> _initiatePurchase(String priceId) async {
    setState(() {
      _loadingPriceId = priceId;
    });

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final callable = functions.httpsCallable('createStripeCheckout');

      final HttpsCallableResult result = await callable.call<Map<String, dynamic>>({
        'priceId': priceId,
      });

      final checkoutUrl = result.data?['url'];
      if (checkoutUrl != null) {
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Não foi possível abrir a página de pagamento.';
        }
      } else {
        throw 'Não foi possível obter a URL de pagamento do servidor.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao iniciar pagamento: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingPriceId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Comprar B2Y Coins',
          style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF1c1c1e),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: _packages.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final package = _packages[index];
          final isLoading = _loadingPriceId == package.stripePriceId;

          return Card(
            color: Colors.grey[850],
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isLoading ? null : () => _initiatePurchase(package.stripePriceId),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: Row(
                  children: [
                    Icon(package.icon, color: Colors.amber, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            package.name,
                            style: GoogleFonts.poppins(
                              textStyle: theme.textTheme.titleMedium,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            package.description,
                            style: GoogleFonts.poppins(
                              textStyle: theme.textTheme.bodySmall,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isLoading
                          ? const SpinKitFadingCircle(
                              key: const ValueKey('loader'), // <<< CORRIGIDO
                              color: Colors.cyan,
                              size: 28,
                            )
                          : Chip(
                              key: const ValueKey('price'), // <<< CORRIGIDO
                              label: Text(
                                package.priceDisplay,
                                style: GoogleFonts.orbitron(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              backgroundColor: Colors.cyan[700],
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}