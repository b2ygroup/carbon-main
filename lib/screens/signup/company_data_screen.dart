// lib/screens/signup/company_data_screen.dart

import 'package:carbon/services/wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:carbon/screens/signup/vehicle_registration_signup_screen.dart';

class CompanyDataScreen extends StatefulWidget {
  const CompanyDataScreen({super.key});
  @override
  State<CompanyDataScreen> createState() => _CompanyDataScreenState();
}

class _CompanyDataScreenState extends State<CompanyDataScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isFetchingCep = false;

  final _companyNameController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _cepController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _cnpjFormatter = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});
  final _phoneFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _cepFormatter = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});

  final FocusNode _cepFocusNode = FocusNode();

  static const Color primaryColor = Color(0xFF00BFFF);
  static const Color secondaryColor = Color(0xFF00FFFF);
  static final Color errorColor = Colors.redAccent[100]!;
  static final Color inputBorderColor = Colors.grey[800]!;
  static final Color labelColor = Colors.grey[400]!;
  static const Color textColor = Colors.white;
  static const Color iconColorStatic = primaryColor;

  @override
  void initState() {
    super.initState();
    _cepFocusNode.addListener(_onCepFocusChange);
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _cnpjController.dispose();
    _cepController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cepFocusNode.removeListener(_onCepFocusChange);
    _cepFocusNode.dispose();
    super.dispose();
  }

  void _onCepFocusChange() {
    if (!_cepFocusNode.hasFocus && _cepController.text.isNotEmpty) {
      _fetchAddressFromCep();
    }
  }

  Future<void> _fetchAddressFromCep() async {
    String cepToSearch = _cepController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cepToSearch.length != 8) return;

    if (mounted) setState(() => _isFetchingCep = true);
    
    try {
      final response = await http.get(Uri.parse('https://viacep.com.br/ws/$cepToSearch/json/'));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data.containsKey('erro') && data['erro'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text('CEP não encontrado.'), backgroundColor: errorColor)
            );
          }
          _addressController.clear();
        } else {
          final String street = data['logradouro'] ?? '';
          final String neighborhood = data['bairro'] ?? '';
          final String city = data['localidade'] ?? '';
          final String state = data['uf'] ?? '';
          
          String fullAddress = "";
          if (street.isNotEmpty) fullAddress += street;
          if (neighborhood.isNotEmpty) fullAddress += (fullAddress.isNotEmpty ? ", " : "") + neighborhood;
          if (city.isNotEmpty) fullAddress += (fullAddress.isNotEmpty ? " - " : "") + city;
          if (state.isNotEmpty) fullAddress += (fullAddress.isNotEmpty ? "/" : "") + state;

          setState(() {
            _addressController.text = fullAddress;
          });
          if (mounted) FocusScope.of(context).nextFocus();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao buscar CEP: ${response.statusCode}'), backgroundColor: errorColor)
          );
        }
         _addressController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Erro de conexão ao buscar CEP.'), backgroundColor: errorColor)
        );
      }
      _addressController.clear();
    } finally {
      if (mounted) setState(() => _isFetchingCep = false);
    }
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Confirme a senha';
    if (value != _passwordController.text) return 'As senhas não coincidem';
    return null;
  }

  void _submitSignupFormPJ() async {
    final isValid = _formKey.currentState?.validate() ?? false; 
    FocusScope.of(context).unfocus(); 

    if (!isValid) return;
    
    _formKey.currentState!.save(); 

    if (_passwordController.text != _confirmPasswordController.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('As senhas não coincidem.'), backgroundColor: _CompanyDataScreenState.errorColor),
        );
      }
      return;
    }

    setState(() { _isLoading = true; });

    User? createdUser; 

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(), 
      );
      createdUser = userCredential.user;

      if (createdUser == null) {
        throw Exception('Falha ao criar conta de autenticação empresarial.');
      }
      final userId = createdUser.uid;

      final Map<String, dynamic> companyData = {
        'uid': userId,
        'email': _emailController.text.trim(),
        'companyName': _companyNameController.text.trim(),
        'cnpj': _cnpjFormatter.getUnmaskedText(),
        'cep': _cepController.text.trim(), 
        'address': _addressController.text.trim(),
        'phone': _phoneFormatter.getUnmaskedText(),
        'accountType': 'PJ', 
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('users').doc(userId).set(companyData);
      
      await WalletService().initializeWallet(userId); 
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conta empresarial para ${_companyNameController.text.trim()} criada!'), backgroundColor: Colors.green)
        );

        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(
            builder: (_) => VehicleRegistrationScreenForSignup(user: createdUser!),
          )
        );
      }

    } on FirebaseAuthException catch (err) {
      String errorMessage;
      if (err.code == 'email-already-in-use') {
        errorMessage = 'Este email já está cadastrado para outra conta.';
      } else if (err.code == 'weak-password') {
        errorMessage = 'A senha fornecida é muito fraca (mínimo 6 caracteres).';
      } else if (err.code == 'invalid-email') {
        errorMessage = 'O formato do email fornecido é inválido.';
      }
      else {
        errorMessage = err.message ?? 'Erro durante o cadastro da autenticação.';
      }
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: _CompanyDataScreenState.errorColor)
        );
      }
    } catch (err) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro inesperado ao salvar dados da empresa: $err'), backgroundColor: _CompanyDataScreenState.errorColor)
        );
      }
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (e) {
          debugPrint("Falha ao reverter usuário de autenticação: $e");
        }
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIconWidget,
  }) {
    return InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(textStyle: TextStyle(color: labelColor, fontSize: 14)),
        prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Icon(prefixIcon, color: iconColorStatic.withAlpha(204), size: 20)),
        suffixIcon: suffixIconWidget,
        prefixIconConstraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        filled: true,
        fillColor: Colors.white.withAlpha(13), 
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: inputBorderColor.withAlpha(128))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: inputBorderColor.withAlpha(128))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: secondaryColor, width: 2.0)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: errorColor)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: errorColor, width: 1.5)),
        errorStyle: TextStyle(color: errorColor.withAlpha(242), fontSize: 12)
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Cadastro Empresarial',
            style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.w600, color: textColor)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Dados da Empresa',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                          color: primaryColor, fontWeight: FontWeight.w600) ??
                      const TextStyle(
                          color: primaryColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w600)),
              const SizedBox(height: 25),
              TextFormField(controller: _companyNameController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText:'Razão Social*', prefixIcon: Icons.business_center), textCapitalization: TextCapitalization.words, validator: (v)=>(v==null||v.isEmpty)?'Obrigatório':null),
              const SizedBox(height:15),
              TextFormField(controller: _cnpjController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText:'CNPJ*', prefixIcon:Icons.badge_outlined), keyboardType:TextInputType.number, inputFormatters:[_cnpjFormatter], validator: (v){if(_cnpjFormatter.getUnmaskedText().length!=14)return 'CNPJ Inválido'; return null;}),
              const SizedBox(height:15),
              TextFormField(
                controller: _cepController,
                focusNode: _cepFocusNode,
                enabled: !_isLoading,
                style: const TextStyle(color: textColor),
                decoration: _inputDecoration(
                  labelText: 'CEP*',
                  prefixIcon: Icons.pin_drop_outlined,
                  suffixIconWidget: _isFetchingCep
                    ? const Padding(padding: EdgeInsets.all(8.0), child: SpinKitFadingCircle(color: primaryColor, size: 20))
                    : null,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [_cepFormatter],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'CEP Obrigatório';
                  if (_cepController.text.replaceAll(RegExp(r'[^0-9]'), '').length != 8) return 'CEP Inválido';
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(controller: _addressController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText:'Endereço Completo*', prefixIcon:Icons.location_city), maxLines: 2, keyboardType: TextInputType.streetAddress, validator: (v)=>(v==null||v.isEmpty)?'Obrigatório':null),
              const SizedBox(height:15),
              TextFormField(controller: _phoneController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText:'Telefone Comercial*', prefixIcon:Icons.phone_outlined), keyboardType:TextInputType.phone, inputFormatters:[_phoneFormatter], validator: (v){if(_phoneFormatter.getUnmaskedText().length<10)return 'Telefone inválido'; return null;}),
              const SizedBox(height:35),
              Text('Crie o acesso principal', textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(color: primaryColor, fontWeight: FontWeight.w600) ?? const TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 25),
              TextFormField(controller: _emailController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText:'Email Contato/Login*', prefixIcon: Icons.alternate_email), keyboardType: TextInputType.emailAddress, validator: (v)=>(v==null||v.isEmpty||!v.contains('@'))?'Email inválido':null ),
              const SizedBox(height: 15),
              TextFormField(controller: _passwordController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText:'Senha*', prefixIcon: Icons.lock_outline), obscureText: true, validator: (v)=>(v==null||v.trim().length<6)?'Mínimo 6 caracteres':null ),
              const SizedBox(height: 15),
              TextFormField(controller: _confirmPasswordController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText:'Confirmar Senha*', prefixIcon: Icons.lock_reset_outlined), obscureText: true, validator: _validateConfirmPassword ),
              const SizedBox(height: 40),
              _isLoading
                  ? const Center(child: SpinKitFadingCube(color: primaryColor, size: 40.0))
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.app_registration_rounded),
                      label: const Text('Criar Conta Empresarial e Avançar'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                      onPressed: _submitSignupFormPJ,
                    ),
              const SizedBox(height: 20),
            ],
          ).animate().fadeIn(duration: 300.ms),
        ),
      ),
    );
  }
}