// lib/providers/user_provider.dart (Atualizado para Admin e Login com Google)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider with ChangeNotifier {
  String? _userId;
  String? _userEmail;
  String? _userName;
  String? _accountType;
  bool _isAdmin = false;
  bool _isGoogleSignIn = false;

  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get accountType => _accountType;
  bool get isAdmin => _isAdmin;
  bool get isGoogleSignIn => _isGoogleSignIn;
  
  // Getter de conveniência para verificar permissão de admin
  bool get canAccessAdminPanel => _isAdmin && _isGoogleSignIn;
  
  bool get isLoggedIn => _userId != null;

  Future<void> loadUserData(String uid) async {
    if (_userId == uid && _userName != null) return; // Não recarrega se já estiver carregado

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != uid) {
      _clearLocalData();
      notifyListeners();
      return;
    }

    _userId = uid;
    _userEmail = currentUser.email;

    // Verifica se o provedor de login foi o Google
    _isGoogleSignIn = currentUser.providerData.any((provider) => provider.providerId == 'google.com');

    print('UserProvider: Carregando dados para UID: $uid');
    print('UserProvider: Método de login é Google? $_isGoogleSignIn');

    try {
      DocumentSnapshot userDataSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDataSnapshot.exists) {
        final data = userDataSnapshot.data() as Map<String, dynamic>;
        _userName = data['fullName'] ?? data['companyName'];
        _accountType = data['accountType'];
        _isAdmin = data['isAdmin'] ?? false; // Carrega o status de admin
        print('UserProvider: Dados carregados: $_userName ($_accountType)');
        print('UserProvider: Usuário é admin? $_isAdmin');
      } else {
        print('UserProvider: Documento do usuário não encontrado.');
        _clearLocalData();
      }
    } catch (error) {
      print("UserProvider: Erro ao carregar dados: $error");
      _clearLocalData();
    } finally {
      notifyListeners();
    }
  }

  void _clearLocalData() {
    _userId = null;
    _userEmail = null;
    _userName = null;
    _accountType = null;
    _isAdmin = false;
    _isGoogleSignIn = false;
  }

  void clearUserDataOnLogout() {
    if (_userId != null) {
      print('UserProvider: Limpando dados do usuário ao fazer logout.');
      _clearLocalData();
      notifyListeners();
    }
  }
}