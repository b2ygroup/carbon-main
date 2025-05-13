// lib/providers/user_provider.dart (Corrigido 'mounted')
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider with ChangeNotifier {
  String? _userId; String? _userEmail; String? _userName;
  String? _accountType;

  String? get userId => _userId; String? get userEmail => _userEmail;
  String? get userName => _userName; String? get accountType => _accountType;
  bool get isLoggedIn => _userId != null;

  Future<void> loadUserData(String uid) async {
    if (_userId == uid && _userName != null) return;
    _userId = uid; _userEmail = FirebaseAuth.instance.currentUser?.email;
    print('UserProvider: Carregando dados para UID: $uid');
    try {
      DocumentSnapshot userDataSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDataSnapshot.exists) {
        final data = userDataSnapshot.data() as Map<String, dynamic>;
        _userName = data['fullName'] ?? data['companyName'];
        _accountType = data['accountType'];
        print('UserProvider: Dados carregados: $_userName ($_accountType)');
      } else { print('UserProvider: Doc usuário não encontrado.'); _clearLocalData(); }
    } catch (error) { print("UserProvider: Erro ao carregar: $error"); _clearLocalData();
    } finally {
       // --- CORREÇÃO: Removido if(mounted) ---
       notifyListeners();
       // ------------------------------------
    }
  }

  void _clearLocalData() { _userId = null; _userEmail = null; _userName = null; _accountType = null; }
  void clearUserDataOnLogout() { if (_userId != null) { print('UserProvider: Limpando dados'); _clearLocalData(); notifyListeners(); } }
}