// lib/screens/buy_coins_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

// Modelo para os pacotes de moedas
class CoinPackage {
  final String id;
  final String name;
  final String description;
  final int coinsAmount;
  final double priceBRL;
  final String stripePriceId;

  CoinPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.coinsAmount,
    required this.priceBRL,
    required this.stripePriceId,
  });

  factory CoinPackage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CoinPackage(
      id: doc.id,
      name: data['name'] ?? 'Pacote',
      description: data['description'] ?? '',
      coinsAmount: (data['coinsAmount'] as num?)?.toInt() ?? 0,
      priceBRL: (data['priceBRL'] as num?)?.toDouble() ?? 0.0,
      stripePriceId: data['stripePriceId'] ?? '',
    );
  }
}

class BuyCoinsScreen extends StatefulWidget {
  const BuyCoinsScreen({super.key});

  @override
  State<BuyCoinsScreen> createState() => _BuyCoinsScreenState();
}

class _BuyCoinsScreenState extends State<BuyCoinsScreen> {
  // Variável para controlar o estado de carregamento durante a compra
  bool _isProcessingPurchase = false;

  // Busca os pacotes de moedas ativos no Firestore
  Future<List<CoinPackage>> _fetchPackages() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('coin_packages')
        .where('isActive', isEqualTo: true)
        .orderBy('displayOrder')
        .get();
    return snapshot.docs.map((doc) => CoinPackage.fromFirestore(doc)).toList();
  }

  // Função para lidar com a compra, chamando a Cloud Function
  Future<void> _handlePurchase(CoinPackage package) async {
    if (_isProcessingPurchase) return; // Evita cliques duplos

    if (mounted) {
      setState(() => _isProcessingPurchase = true);
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Usuário não autenticado.'), backgroundColor: Colors.red),
      );
      if (mounted) {
        setState(() => _isProcessingPurchase = false);
      }
      return;
    }

    try {
      // 1. Inicializa a chamada para a Cloud Function
      //    Certifique-se de que a região corresponde à do seu projeto Firebase.
      final functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1'); 
      final HttpsCallable callable = functions.httpsCallable('createStripeCheckout');
      
      // 2. Executa a chamada, passando os dados necessários
      final response = await callable.call<Map<String, dynamic>>({
        'priceId': package.stripePriceId, // ID do preço que você criou no Stripe
        'userId': user.uid,               // ID do usuário para referência futura
      });

      // 3. Recebe a URL de checkout do Stripe e redireciona o usuário
      final String? checkoutUrl = response.data?['url'];
      if (checkoutUrl != null) {
        final Uri url = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(url)) {
          // Abre a página de pagamento segura do Stripe
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw 'Não foi possível abrir a URL: $checkoutUrl';
        }
      } else {
        throw 'A Cloud Function não retornou uma URL de checkout.';
      }

    } on FirebaseFunctionsException catch (e) {
      // Trata erros específicos da Cloud Function
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao iniciar pagamento: ${e.message}'), backgroundColor: Colors.red),
      );
    } catch (e) {
      // Trata outros erros inesperados
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro inesperado: $e'), backgroundColor: Colors.red),
      );
    } finally {
      // Garante que o indicador de carregamento seja desativado ao final
      if (mounted) {
        setState(() => _isProcessingPurchase = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comprar B2Y Coins', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.grey[900],
        elevation: 0,
      ),
      backgroundColor: Colors.grey[900],
      body: FutureBuilder<List<CoinPackage>>(
        future: _fetchPackages(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: SpinKitFadingCube(color: Colors.cyanAccent, size: 50.0));
          }
          if (snapshot.hasError) {
            // Mostra o erro real no corpo da tela para facilitar a depuração
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Erro ao carregar pacotes: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum pacote de moedas disponível no momento.', style: TextStyle(color: Colors.white70)));
          }

          final packages = snapshot.data!;

          // Usamos um Stack para colocar o overlay de carregamento sobre a lista
          return Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: packages.length,
                itemBuilder: (context, index) {
                  final package = packages[index];
                  return Card(
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.5),
                    color: Colors.grey[850],
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ListTile(
                        leading: const Icon(Icons.monetization_on, color: Colors.amberAccent, size: 40),
                        title: Text(package.name, style: GoogleFonts.orbitron(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('${package.coinsAmount} moedas', style: const TextStyle(color: Colors.white70)),
                        trailing: ElevatedButton(
                          onPressed: _isProcessingPurchase ? null : () => _handlePurchase(package), // Desativa o botão durante o processamento
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text('R\$ ${package.priceBRL.toStringAsFixed(2)}'),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Overlay de carregamento que aparece sobre a lista
              if (_isProcessingPurchase)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SpinKitFadingCube(color: Colors.white, size: 50.0),
                        SizedBox(height: 20),
                        Text('Processando seu pedido...', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}