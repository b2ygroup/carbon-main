// lib/screens/marketplace_screen.dart (COM LAYOUT RESPONSIVO E IMAGENS AJUSTADAS)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:carbon/models/product_model.dart';
import 'package:carbon/services/wallet_service.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final WalletService _walletService = WalletService();
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  bool _isProcessingPurchase = false;

  static const Color primaryColor = Color(0xFF00BFFF);
  static const Color textColor = Colors.white;
  static final Color cardBackgroundColor = Colors.grey[850]!.withAlpha(200);

  Future<List<Product>> _fetchProducts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
  }

  void _showPurchaseDialog(Product product) {
    showDialog(
      context: context,
      barrierDismissible: !_isProcessingPurchase,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(product.name, style: GoogleFonts.orbitron(color: primaryColor)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.description, style: GoogleFonts.poppins(color: textColor.withOpacity(0.8))),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.toll_outlined, color: Colors.amberAccent),
                      const SizedBox(width: 8),
                      Text('${product.priceCoins} B2Y Coins', style: GoogleFonts.orbitron(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              actions: [
                if (!_isProcessingPurchase)
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar', style: TextStyle(color: Colors.white70))),
                
                _isProcessingPurchase
                  ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () async {
                        if (userId == null) return;
                        
                        setDialogState(() => _isProcessingPurchase = true);

                        final result = await _walletService.executePurchase(userId: userId!, product: product);
                        
                        if (mounted) {
                          Navigator.of(ctx).pop();
                          if (result == "success") {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${product.name}" resgatado com sucesso!'), backgroundColor: Colors.green));
                          } else {
                            final errorMessage = result.replaceFirst("Exception: ", "");
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha na compra: $errorMessage'), backgroundColor: Colors.redAccent));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.black),
                      child: const Text('Confirmar Compra'),
                    ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ▼▼▼ LÓGICA PARA RESPONSIVIDADE DA GRADE ▼▼▼
    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = (screenWidth / 220).floor().clamp(2, 5); // Pelo menos 2, no máximo 5 colunas
    final double childAspectRatio = (screenWidth > 600) ? 0.9 : 0.8; // Cards um pouco mais altos em telas menores

    return Scaffold(
      appBar: AppBar(
        title: Text('Loja B2Y', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.grey[900],
        actions: [
          if (userId != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: StreamBuilder<double>(
                stream: _walletService.getWalletBalanceStream(userId!),
                builder: (context, snapshot) {
                  final balance = snapshot.data ?? 0.0;
                  return Chip(
                    avatar: const Icon(Icons.toll_outlined, color: Colors.amberAccent),
                    label: Text(balance.toStringAsFixed(4), style: const TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    backgroundColor: Colors.black.withOpacity(0.3),
                  );
                },
              ),
            )
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _fetchProducts(),
        builder: (context, productSnapshot) {
          if (productSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: SpinKitFadingCube(color: primaryColor, size: 50.0));
          }
          if (productSnapshot.hasError) {
            return Center(child: Text('Erro ao carregar produtos: ${productSnapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (!productSnapshot.hasData || productSnapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum produto disponível no momento.', style: TextStyle(color: Colors.white70)));
          }
          final products = productSnapshot.data!;

          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount, // Usa a contagem de colunas dinâmica
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: childAspectRatio, // Usa a proporção dinâmica
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _ProductCard(product: product, onTap: () => _showPurchaseDialog(product));
            },
          ).animate().fadeIn(duration: 300.ms);
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _MarketplaceScreenState.cardBackgroundColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Área da imagem com altura proporcional e conteúdo centralizado
            Expanded(
              flex: 5, // Dá mais espaço para a área da imagem
              child: Container(
                color: Colors.black.withOpacity(0.2),
                padding: const EdgeInsets.all(8.0), // Um respiro para a imagem
                child: Hero(
                  tag: 'product_image_${product.id}',
                  child: Image.network(
                    product.imageUrl,
                    // ▼▼▼ AJUSTE DA IMAGEM PARA CABER INTEIRA ▼▼▼
                    fit: BoxFit.contain, 
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: SpinKitFadingCircle(color: _MarketplaceScreenState.primaryColor, size: 25));
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 40);
                    },
                  ),
                ),
              ),
            ),
            // Área de informações do produto
            Expanded(
              flex: 3, // Menos espaço, apenas para o texto
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _MarketplaceScreenState.textColor, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(), // Empurra o preço para baixo
                    Row(
                      children: [
                        const Icon(Icons.toll_outlined, color: Colors.amberAccent, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          product.priceCoins.toString(),
                          style: GoogleFonts.orbitron(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}