// lib/screens/signup/company_data_screen.dart (Com initializeWallet)
import 'package:carbon/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Importa a próxima tela do fluxo
import 'package:carbon/screens/signup/vehicle_registration_signup_screen.dart';
// <<< IMPORTAR A FUNÇÃO initializeWallet >>>
// Exemplo: import 'package:carbon/services/firestore_service.dart';
// Ou defina a função neste arquivo mesmo (fora da classe)

// Se definir a função initializeWallet neste arquivo, cole-a aqui fora da classe:
// Future<void> initializeWallet(String userId) async { ... }


class CompanyDataScreen extends StatefulWidget {
  const CompanyDataScreen({super.key});
  @override State<CompanyDataScreen> createState() => _CompanyDataScreenState();
}

class _CompanyDataScreenState extends State<CompanyDataScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final _companyNameController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cnpjFormatter = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});
  final _phoneFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});

  static const Color primaryColor = Color(0xFF00BFFF); static const Color secondaryColor = Color(0xFF00FFFF);
  static final Color errorColor = Colors.redAccent[100]!; static final Color inputBorderColor = Colors.grey[800]!;
  static final Color labelColor = Colors.grey[400]!; static const Color textColor = Colors.white;

  @override
  void dispose() {
    _companyNameController.dispose(); _cnpjController.dispose(); _addressController.dispose();
    _phoneController.dispose(); _emailController.dispose(); _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Confirme a senha';
    if (value != _passwordController.text) return 'As senhas não coincidem';
    return null;
  }

  void _submitSignupFormPJ() async {
    print("--- Iniciando _submitSignupForm (PJ) ---");
    final isValid = _formKey.currentState?.validate() ?? false; print("Form válido: $isValid");
    FocusScope.of(context).unfocus(); if (!isValid) return;
    _formKey.currentState?.save();
    setState(() { _isLoading = true; }); await Future.delayed(500.ms);
    User? createdUser;

    try {
      print("Passo 1: Criando Auth User: ${_emailController.text.trim()}");
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword( email: _emailController.text.trim(), password: _passwordController.text.trim());
      createdUser = userCredential.user; if (createdUser == null) throw Exception('Falha Auth.'); final userId = createdUser.uid; print("Auth User (PJ) criado: $userId");

      print("Passo 2: Preparando dados Firestore...");
      final Map<String, dynamic> companyData = {
        'uid': userId, 'email': _emailController.text.trim(),
        'companyName': _companyNameController.text.trim(),
        'cnpj': _cnpjFormatter.getUnmaskedText(),
        'address': _addressController.text.trim(),
        'phone': _phoneFormatter.getUnmaskedText(),
        'accountType': 'PJ',
        'createdAt': FieldValue.serverTimestamp(),
      };
      print("Dados da Empresa a salvar: $companyData");

      print("Passo 3: Salvando no Firestore (/users)...");
      await FirebaseFirestore.instance.collection('users').doc(userId).set(companyData);
      print("Dados da empresa salvos!");

      // <<< PASSO 3.5: Inicializar a carteira >>>
      print("Passo 3.5: Inicializando carteira...");
      await initializeWallet(userId); // <<< CHAMADA ADICIONADA AQUI
      print("Carteira inicializada (ou verificada).");
      // <<< FIM DA CHAMADA >>>

      if (mounted) {
        print("Passo 4: Navegando para VehicleRegistrationScreenForSignup...");
        Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => const VehicleRegistrationScreenForSignup())
        );
      }

    } on FirebaseAuthException { /* ... tratamento erro Auth ... */ }
    catch (err) { /* ... tratamento erro geral ... */ }
    finally { /* ... finaliza loading ... */ }
  }


  @override
  Widget build(BuildContext context) {
    // ... (build method sem alterações, apenas chama _submitSignupFormPJ) ...
     final theme = Theme.of(context);
     return Scaffold(
       appBar: AppBar( title: Text('Cadastro Empresarial', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600))),
       body: SingleChildScrollView( padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
         child: Form( key: _formKey,
           child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
             Text('Dados da Empresa', style: theme.textTheme.titleLarge?.copyWith(color: primaryColor)), const SizedBox(height: 25),
             TextFormField(controller: _companyNameController, decoration: _inputDecoration(labelText:'Razão Social', prefixIcon: Icons.business_center), textCapitalization: TextCapitalization.words, validator: (v)=>(v==null||v.isEmpty)?'Obrigatório':null), const SizedBox(height:15),
             TextFormField(controller: _cnpjController, decoration: _inputDecoration(labelText:'CNPJ', prefixIcon:Icons.badge_outlined), keyboardType:TextInputType.number, inputFormatters:[_cnpjFormatter], validator: (v){if(_cnpjFormatter.getUnmaskedText().length!=14)return 'Inválido'; return null;}), const SizedBox(height:15),
             TextFormField(controller: _addressController, decoration: _inputDecoration(labelText:'Endereço Completo', prefixIcon:Icons.location_city), maxLines: 1, keyboardType: TextInputType.streetAddress, validator: (v)=>(v==null||v.isEmpty)?'Obrigatório':null), const SizedBox(height:15),
             TextFormField(controller: _phoneController, decoration: _inputDecoration(labelText:'Telefone Comercial', prefixIcon:Icons.phone_outlined), keyboardType:TextInputType.phone, inputFormatters:[_phoneFormatter], validator: (v){if(_phoneFormatter.getUnmaskedText().length<10)return 'Inválido'; return null;}),
             const SizedBox(height:35), Text('Crie o acesso principal', style: theme.textTheme.titleLarge?.copyWith(color: primaryColor)), const SizedBox(height: 25),
             TextFormField(controller: _emailController, decoration: _inputDecoration(labelText:'Email Contato/Login', prefixIcon: Icons.alternate_email), keyboardType: TextInputType.emailAddress, validator: (v)=>(v==null||v.isEmpty||!v.contains('@'))?'Inválido':null ), const SizedBox(height: 15),
             TextFormField(controller: _passwordController, decoration: _inputDecoration(labelText:'Senha', prefixIcon: Icons.lock_outline), obscureText: true, validator: (v)=>(v==null||v.trim().length<6)?'Min 6 chars':null ), const SizedBox(height: 15),
             TextFormField(controller: _confirmPasswordController, decoration: _inputDecoration(labelText:'Confirmar Senha', prefixIcon: Icons.lock_reset_outlined), obscureText: true, validator: _validateConfirmPassword ), const SizedBox(height: 40),
             _isLoading ? const Center(child: SpinKitFadingCube(color: primaryColor, size: 40.0))
             : ElevatedButton.icon( icon: const Icon(Icons.app_registration_rounded), label: const Text('Criar Conta Empresarial'), style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 15)), onPressed: _submitSignupFormPJ ), const SizedBox(height: 20),
           ], ).animate().fadeIn(duration: 300.ms),
         ),
       ),
     );
  }

  InputDecoration _inputDecoration({ required String labelText, required IconData prefixIcon }) {
    // ... (código do helper _inputDecoration sem alterações) ...
      final currentLabelColor = labelColor; const currentIconColor = primaryColor; final currentBorderColor = inputBorderColor;
      const currentFocusColor = secondaryColor; final currentErrorColor = errorColor;
      return InputDecoration( labelText: labelText, labelStyle: GoogleFonts.poppins(textStyle:TextStyle(color: currentLabelColor, fontSize: 14)),
       prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Icon(prefixIcon, color: currentIconColor.withOpacity(0.8), size: 20)),
       prefixIconConstraints: const BoxConstraints(minWidth:20, minHeight:20), filled: true, fillColor: Colors.white.withOpacity(0.05),
       contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0), border: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: currentBorderColor.withOpacity(0.5))),
       enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: currentBorderColor.withOpacity(0.5))),
       focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: currentFocusColor, width: 2.0)),
       errorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: currentErrorColor)),
       focusedErrorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: currentErrorColor, width: 1.5)),
       errorStyle: TextStyle(color: currentErrorColor.withOpacity(0.95), fontSize: 12));
  }
}

// --- Tratamento de Erro Auth PJ (exemplo dentro do catch) ---
/*
} on FirebaseAuthException catch (err) {
  print("!!! ERRO AUTH (PJ): Code: ${err.code} Message: ${err.message} !!!");
  String errorMessage;
  if (err.code == 'email-already-in-use') { errorMessage = 'Este email já está cadastrado.'; }
  else if (err.code == 'weak-password') { errorMessage = 'A senha é muito fraca.'; }
  else { errorMessage = err.message ?? 'Erro no cadastro.'; }
  if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: errorColor));
}
*/

// --- Tratamento de Erro Geral PJ (exemplo dentro do catch) ---
/*
} catch (err, s) {
  print("!!! ERRO GERAL (PJ): $err\n$s");
  if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro inesperado ao salvar.')));
  // Considerar deletar usuário Auth se Firestore falhou
  // if (createdUser != null) { try { await createdUser.delete(); } catch (e) {} }
}
*/

// --- Finally PJ (exemplo dentro do finally) ---
/*
} finally {
  print("--- Finalizando _submitSignupForm (PJ) ---");
  if (mounted) { setState(() { _isLoading = false; }); }
}
*/

// --- Função initializeWallet (Defina aqui ou importe) ---
// Future<void> initializeWallet(String userId) async { ... }