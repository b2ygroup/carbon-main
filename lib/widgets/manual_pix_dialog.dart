// lib/widgets/manual_pix_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

void showManualPixDialog(BuildContext context, {required double amount, required String pixKey}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF2c2c2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        "Pagar com PIX",
        style: GoogleFonts.orbitron(color: Colors.greenAccent[400], fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Use o app do seu banco para ler o QR Code ou copie a chave abaixo.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: SvgPicture.asset('assets/images/pix_qrcode.svg', height: 150),
          ),
          const SizedBox(height: 16),
          Text(
            "VALOR: R\$ ${amount.toStringAsFixed(2)}",
            style: GoogleFonts.orbitron(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            "Chave PIX (CPF):",
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                pixKey,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.cyanAccent, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: pixKey));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Chave PIX copiada!"), backgroundColor: Colors.green),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "IMPORTANTE: Após o pagamento, o crédito de carbono será validado manualmente em até 24h.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.amberAccent, fontSize: 12),
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text("Fechar", style: TextStyle(color: Colors.white70)),
        )
      ],
    ),
  );
}