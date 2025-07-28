// lib/screens/marketplace_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:carbon/models/product_model.dart';
import 'package:carbon/services/wallet_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final WalletService _walletService = WalletService();
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  bool _isProcessingPurchase = false;

  final NumberFormat _coinFormatter = NumberFormat("#,##0.00", "pt_BR");

  static const Color primaryColor = Color(0xFF00BFFF);
  static const Color textColor = Colors.white;
  static final Color errorColor = Colors.redAccent[100]!;
  static final Color successColor = Colors.greenAccent[400]!;

  Future<List<Product>> _fetchProducts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
  }

  void _handlePurchase(Product product) {
    if (product.stripePriceId != null && product.stripePriceId!.isNotEmpty) {
      _purchaseWithStripe(product);
    } else {
      _showCoinPurchaseDialog(product);
    }
  }

  Future<void> _purchaseWithStripe(Product product) async {
    setState(() => _isProcessingPurchase = true);
    try {
      final String checkoutUrl = await _walletService.purchaseProductWithStripe(priceId: product.stripePriceId!);
      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir a URL de pagamento.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingPurchase = false);
      }
    }
  }

  void _showCoinPurchaseDialog(Product product) {
    _isProcessingPurchase = false;
    showDialog(
      context: context,
      barrierDismissible: !_isProcessingPurchase,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text("Confirmar Resgate", style: GoogleFonts.orbitron(color: primaryColor)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 100,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(product.imageUrl, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(product.name, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(product.description, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: textColor.withAlpha((255 * 0.7).round()), fontSize: 14)),
                  const SizedBox(height: 20),
                  Chip(
                    backgroundColor: Colors.amber.withAlpha((255 * 0.1).round()),
                    avatar: const Icon(Icons.toll_outlined, color: Colors.amberAccent),
                    label: Text('Custo: ${_coinFormatter.format(product.priceCoins)} B2Y Coins', style: GoogleFonts.orbitron(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                if (!_isProcessingPurchase)
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar', style: TextStyle(color: Colors.white70))),
                SizedBox(
                  width: 150,
                  height: 40,
                  child: _isProcessingPurchase
                      ? const Center(child: SpinKitFadingCircle(color: primaryColor, size: 25))
                      : ElevatedButton(
                          onPressed: () async {
                            if (userId == null) return;
                            setDialogState(() => _isProcessingPurchase = true);
                            
                            final result = await _walletService.executePurchase(userId: userId!, product: product);
                            
                            setDialogState(() => _isProcessingPurchase = false);
                            
                            if (!mounted) return;
                            
                            Navigator.of(ctx).pop();
                            if (result == "success") {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('"${product.name}" resgatado com sucesso!'), backgroundColor: successColor, behavior: SnackBarBehavior.floating),
                              );
                            } else {
                              final errorMessage = result.replaceFirst("Exception: ", "");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Falha na compra: $errorMessage'), backgroundColor: errorColor, behavior: SnackBarBehavior.floating),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.black),
                          child: const Text('Confirmar'),
                        ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = (screenWidth / 220).floor().clamp(2, 5);
    final double childAspectRatio = (screenWidth > 600) ? 0.9 : 0.8;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text('Loja B2Y', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700, fontSize: 24)),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        actions: [
          if (userId != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: StreamBuilder<double>(
                stream: _walletService.getWalletBalanceStream(userId!),
                builder: (context, snapshot) {
                  final balance = snapshot.data ?? 0.0;
                  return Chip(
                    avatar: const Icon(Icons.toll_outlined, color: Colors.amberAccent, size: 18),
                    label: Text(_coinFormatter.format(balance), style: const TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    backgroundColor: Colors.black38,
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
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _ProductCard(
                product: product, 
                formatter: _coinFormatter,
                onTap: () => _handlePurchase(product)
              );
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
  final NumberFormat formatter;
  const _ProductCard({required this.product, required this.onTap, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final bool isRealMoneyPurchase = product.stripePriceId != null && product.stripePriceId!.isNotEmpty;
    final cardColor = Colors.grey[850]!.withAlpha(200);

    return Card(
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                color: Colors.black12,
                padding: const EdgeInsets.all(8.0),
                child: Hero(
                  tag: 'product_image_${product.id}',
                  child: Image.network(
                    product.imageUrl,
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
            Expanded(
              flex: 3,
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
                    const Spacer(),
                    if (isRealMoneyPurchase && product.priceReal != null)
                      Text(
                        'R\$ ${product.priceReal!.toStringAsFixed(2)}',
                        style: GoogleFonts.orbitron(color: _MarketplaceScreenState.successColor, fontWeight: FontWeight.bold, fontSize: 15),
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.toll_outlined, color: Colors.amberAccent, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            formatter.format(product.priceCoins),
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