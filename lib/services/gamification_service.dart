// lib/services/gamification_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class GamificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Método principal que é chamado para verificar todos os emblemas possíveis.
  /// Retorna uma lista de nomes de emblemas recém-conquistados para exibir na UI.
  Future<List<String>> checkAndAwardBadges(String userId) async {
    List<String> newlyAwardedBadges = [];

    // Tenta conceder o emblema de "Primeira Viagem"
    bool awardedFirstTrip = await _awardFirstTripBadge(userId);
    if (awardedFirstTrip) {
      newlyAwardedBadges.add("Pioneiro Sustentável");
    }

    // Tenta conceder o emblema de "Maratonista Verde"
    bool awardedMarathoner = await _awardGreenMarathonerBadge(userId);
    if (awardedMarathoner) {
      newlyAwardedBadges.add("Maratonista Verde");
    }

    // Adicione aqui as chamadas para outros emblemas que você criar...

    return newlyAwardedBadges;
  }

  /// Concede o emblema se for a primeira viagem do usuário.
  Future<bool> _awardFirstTripBadge(String userId) async {
    const String badgeId = 'pioneiro_sustentavel';
    
    // 1. Verifica se o usuário já tem o emblema
    final badgeDoc = _db.collection('users').doc(userId).collection('unlocked_badges').doc(badgeId);
    if ((await badgeDoc.get()).exists) {
      return false; // Já possui
    }

    // 2. Verifica se o usuário tem pelo menos uma viagem
    final tripQuery = await _db.collection('trips').where('userId', isEqualTo: userId).limit(1).get();
    
    if (tripQuery.docs.isNotEmpty) {
      // 3. Concede o emblema
      await badgeDoc.set({
        'unlockedAt': FieldValue.serverTimestamp(),
        'badgeId': badgeId,
      });
      debugPrint("Emblema 'Pioneiro Sustentável' concedido para o usuário $userId");
      return true;
    }
    
    return false;
  }

  /// Concede o emblema se o usuário atingir 100km em viagens sustentáveis.
  Future<bool> _awardGreenMarathonerBadge(String userId) async {
    const String badgeId = 'maratonista_verde_100km';
    const double distanceThreshold = 100.0; // 100 km

    // 1. Verifica se o usuário já tem o emblema
    final badgeDoc = _db.collection('users').doc(userId).collection('unlocked_badges').doc(badgeId);
    if ((await badgeDoc.get()).exists) {
      return false;
    }

    // 2. Calcula a distância total de viagens sustentáveis
    final tripQuery = await _db
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .where('co2SavedKg', isGreaterThan: 0)
        .get();

    if (tripQuery.docs.isEmpty) {
      return false;
    }

    double totalDistance = 0.0;
    for (var doc in tripQuery.docs) {
      totalDistance += (doc.data()['distanceKm'] as num?)?.toDouble() ?? 0.0;
    }
    
    // 3. Verifica se atingiu o limiar
    if (totalDistance >= distanceThreshold) {
      await badgeDoc.set({
        'unlockedAt': FieldValue.serverTimestamp(),
        'badgeId': badgeId,
        'achievedValue': totalDistance,
      });
      debugPrint("Emblema 'Maratonista Verde' concedido para o usuário $userId");
      return true;
    }

    return false;
  }
}