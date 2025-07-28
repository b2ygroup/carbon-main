// lib/screens/badges_screen.dart

import 'package:carbon/models/badge.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Badge; // <<< CORREÇÃO APLICADA AQUI
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  Future<List<Badge>>? _badgesFuture;

  @override
  void initState() {
    super.initState();
    _badgesFuture = _fetchBadges();
  }

  Future<List<Badge>> _fetchBadges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    // 1. Pega a definição de TODOS os emblemas
    final allBadgesSnapshot = await FirebaseFirestore.instance.collection('badges').orderBy('order').get();
    final allBadges = allBadgesSnapshot.docs.map((doc) => Badge.fromFirestore(doc)).toList();

    // 2. Pega os IDs dos emblemas que o usuário já desbloqueou
    final unlockedBadgesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('unlocked_badges')
        .get();
    final unlockedBadgeIds = unlockedBadgesSnapshot.docs.map((doc) => doc.id).toSet();

    // 3. Marca quais emblemas estão desbloqueados
    for (var badge in allBadges) {
      if (unlockedBadgeIds.contains(badge.id)) {
        badge.isUnlocked = true;
      }
    }
    
    return allBadges;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Meus Emblemas', style: GoogleFonts.orbitron(fontWeight: FontWeight.bold)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
      ),
      body: FutureBuilder<List<Badge>>(
        future: _badgesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar emblemas: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum emblema encontrado.', style: TextStyle(color: Colors.white70)));
          }

          final badges = snapshot.data!;

          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: badges.length,
            itemBuilder: (context, index) {
              final badge = badges[index];
              return BadgeWidget(badge: badge)
                  .animate()
                  .fadeIn(delay: (100 * (index % 3)).ms)
                  .slideY(begin: 0.2, duration: 400.ms);
            },
          );
        },
      ),
    );
  }
}

class BadgeWidget extends StatelessWidget {
  final Badge badge;
  const BadgeWidget({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: badge.isUnlocked ? 1.0 : 0.4,
      child: Tooltip(
        message: "${badge.name}\n${badge.description}",
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Card(
          color: Colors.grey[850]?.withAlpha(150),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: SvgPicture.network(
                    badge.iconUrl,
                    colorFilter: badge.isUnlocked
                        ? null
                        : const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    placeholderBuilder: (_) => const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  badge.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: badge.isUnlocked ? Colors.white : Colors.grey[400],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}