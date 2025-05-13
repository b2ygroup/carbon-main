// lib/widgets/ad_banner_placeholder.dart (Simulando Carrossel - Revisado)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// Para animação se desejar

class AdBannerPlaceholder extends StatefulWidget {
  final double height;
  const AdBannerPlaceholder({super.key, this.height = 60.0}); // Altura do banner

  @override
  State<AdBannerPlaceholder> createState() => _AdBannerPlaceholderState();
}

class _AdBannerPlaceholderState extends State<AdBannerPlaceholder> {
  int _currentIndex = 0;
  Timer? _timer;
  // Lista de Widgets para simular diferentes anúncios visuais
  final List<Widget> _adContents = [
    _buildAdContent("Ad: Compense Carbono e Ganhe Recompensas!", Colors.lightGreenAccent.shade700),
    _buildAdContent("Ad: Postos parceiros com desconto!", Colors.lightBlueAccent.shade400),
    _buildAdContent("Ad: Seguro Automotivo Verde? Confira!", Colors.purpleAccent.shade100),
    _buildAdContent("Ad: Viaje Verde e Seja Recompensado!", Colors.tealAccent.shade400),
  ];

  // Helper estático para construir o conteúdo interno do anúncio
  static Widget _buildAdContent(String text, Color accentColor) {
    return Padding( padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row( mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.campaign_outlined, color: accentColor, size: 18), const SizedBox(width: 8),
          Expanded( child: Text( text, style: GoogleFonts.poppins( textStyle: TextStyle( color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w500)), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2, ), ),
        ], ), );
  }

  @override
  void initState() { super.initState(); if (_adContents.isNotEmpty) _startTimer(); }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) { if (mounted) { setState(() { _currentIndex = (_currentIndex + 1) % _adContents.length; }); } else { timer.cancel(); } });
  }

  @override
  Widget build(BuildContext context) {
    return Container( height: widget.height, width: double.infinity, margin: const EdgeInsets.only(bottom: 8.0), // Margem só embaixo se está no topo
      decoration: BoxDecoration( color: Colors.grey[900]?.withOpacity(0.7), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[700]!, width: 0.5)),
      child: ClipRRect( borderRadius: BorderRadius.circular(7.5),
        child: AnimatedSwitcher( duration: const Duration(milliseconds: 900), transitionBuilder: (Widget child, Animation<double> animation) { return FadeTransition( opacity: animation, child: ScaleTransition( scale: animation, child: child ) ); },
          child: _adContents.isNotEmpty ? Container( key: ValueKey<int>(_currentIndex), alignment: Alignment.center, child: _adContents[_currentIndex] ) : const SizedBox.shrink(),
        ), ), );
  }
}