// lib/screens/signup/personal_data_screen.dart

import 'package:carbon/services/wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:carbon/screens/signup/vehicle_registration_signup_screen.dart'; 

class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key});
  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isFetchingCep = false; 

  final _nameController = TextEditingController();
  final _cpfController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  DateTime? _selectedDate;

  final _cepController = TextEditingController();
  final _streetController = TextEditingController(); 
  final _numberController = TextEditingController(); 
  final _complementController = TextEditingController(); 
  final _neighborhoodController = TextEditingController(); 
  final _cityController = TextEditingController(); 
  final _stateController = TextEditingController(); 

  final _cpfFormatter = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _phoneFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _dobFormatter = MaskTextInputFormatter(mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});
  final _cepFormatter = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});

  final FocusNode _cepFocusNode = FocusNode();
  final FocusNode _numberFocusNode = FocusNode();

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
    _nameController.dispose();
    _cpfController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cepController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _cepFocusNode.removeListener(_onCepFocusChange);
    _cepFocusNode.dispose();
    _numberFocusNode.dispose();
    super.dispose();
  }

  void _onCepFocusChange() {
    if (!_cepFocusNode.hasFocus && _cepController.text.isNotEmpty) {
      _fetchAddressFromCep();
    }
  }

  Future<void> _fetchAddressFromCep() async {
    final String cepToSearch = _cepController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cepToSearch.length != 8) return;

    if (mounted) setState(() => _isFetchingCep = true);
    _streetController.clear(); _neighborhoodController.clear(); _cityController.clear();
    _stateController.clear(); _numberController.clear(); _complementController.clear();

    try {
      final response = await http.get(Uri.parse('https://viacep.com.br/ws/$cepToSearch/json/'));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data.containsKey('erro') && data['erro'] == true) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('CEP não encontrado.'), backgroundColor: errorColor));
        } else {
          setState(() {
            _streetController.text = data['logradouro'] ?? '';
            _neighborhoodController.text = data['bairro'] ?? '';
            _cityController.text = data['localidade'] ?? '';
            _stateController.text = data['uf'] ?? '';
          });
          if (mounted) FocusScope.of(context).requestFocus(_numberFocusNode);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar CEP: ${response.statusCode}'), backgroundColor: errorColor));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Erro de conexão ao buscar CEP.'), backgroundColor: errorColor));
    } finally {
      if (mounted) setState(() => _isFetchingCep = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: primaryColor, onPrimary: Colors.black, surface: Color(0xFF303030), onSurface: textColor,
            ),
            textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: secondaryColor)), dialogTheme: DialogThemeData(backgroundColor: Colors.grey[850])
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirme a senha';
    }
    if (value != _passwordController.text) {
      return 'As senhas não coincidem';
    }
    return null;
  }

  Future<void> _submitSignupForm() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    FocusScope.of(context).unfocus();

    if (!isValid) return;
    _formKey.currentState!.save();
    
    if (_passwordController.text != _confirmPasswordController.text) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('As senhas não coincidem.'), backgroundColor: errorColor));
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    User? createdUser;

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(), password: _passwordController.text,
      );
      createdUser = userCredential.user;

      if (createdUser == null) throw Exception('Falha ao obter detalhes do novo usuário após criação.');
      
      final userId = createdUser.uid;
      
      String? dobString;
      if (_selectedDate != null) {
        dobString = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      } else if (_dobController.text.isNotEmpty) {
        try {
            DateTime parsedDate = DateFormat('dd/MM/yyyy').parseStrict(_dobController.text);
            dobString = DateFormat('yyyy-MM-dd').format(parsedDate);
            if(mounted) setState(() => _selectedDate = parsedDate );
        } catch (e) {
            dobString = null; 
        }
      }
      Map<String, dynamic> userData = {
        'uid': userId, 'fullName': _nameController.text.trim(), 'cpf': _cpfFormatter.getUnmaskedText(),
        'dateOfBirth': dobString, 'phone': _phoneFormatter.getUnmaskedText(), 'email': createdUser.email, 
        'createdAt': FieldValue.serverTimestamp(), 'accountType': 'PF', 
        'address': {
          'cep': _cepController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          'street': _streetController.text.trim(),
          'number': _numberController.text.trim(), 
          'complement': _complementController.text.trim().isNotEmpty ? _complementController.text.trim() : null,
          'neighborhood': _neighborhoodController.text.trim(),
          'city': _cityController.text.trim(), 'state': _stateController.text.trim().toUpperCase(),
        }
      };

      await FirebaseFirestore.instance.collection('users').doc(userId).set(userData);
      
      await WalletService().initializeWallet(userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Conta para ${_nameController.text.trim()} criada!'), backgroundColor: Colors.green));
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => VehicleRegistrationScreenForSignup(user: createdUser!),
          )
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Ocorreu um erro ao criar a conta.';
      if (e.code == 'weak-password') {
        errorMessage = 'A senha fornecida é muito fraca.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Este email já está em uso por outra conta.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'O formato do email é inválido.';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: errorColor));
    
    } on FirebaseException catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro de banco de dados: ${e.message}'), backgroundColor: errorColor));
      }
      if (createdUser != null) {
        await createdUser.delete();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro desconhecido ao criar conta: $e'), backgroundColor: errorColor));
      if (createdUser != null) {
        await createdUser.delete();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration({
    required String labelText, required IconData prefixIcon, IconData? suffixIcon, Widget? suffixIconWidget,
  }) {
    return InputDecoration(
        labelText: labelText, labelStyle: GoogleFonts.poppins(textStyle: TextStyle(color: labelColor, fontSize: 14)),
        prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Icon(prefixIcon, color: iconColorStatic.withAlpha((255 * 0.8).round()), size: 20)),
        suffixIcon: suffixIconWidget ?? (suffixIcon != null 
            ? IconButton(icon: Icon(suffixIcon, color: labelColor.withAlpha((255 * 0.8).round()), size: 20),
                onPressed: (suffixIcon == Icons.calendar_month) ? () => _isLoading ? null : _selectDate(context) : null,
              ) : null),
        prefixIconConstraints: const BoxConstraints(minWidth: 20, minHeight: 20), filled: true, fillColor: Colors.white.withAlpha((255 * 0.05).round()),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: inputBorderColor.withAlpha((255 * 0.5).round()))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: inputBorderColor.withAlpha((255 * 0.5).round()))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: secondaryColor, width: 2.0)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: errorColor)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: errorColor, width: 1.5)),
        errorStyle: TextStyle(color: errorColor.withAlpha((255 * 0.95).round()), fontSize: 12)
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Cadastro Pessoal', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600, color: textColor,)),
        backgroundColor: Colors.grey[900], iconTheme: const IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Conte-nos sobre você', textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(color: primaryColor, fontWeight: FontWeight.w600) ?? const TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 25),
              TextFormField(controller: _nameController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'Nome Completo*', prefixIcon: Icons.person_outline), textCapitalization: TextCapitalization.words, validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 15),
              TextFormField(controller: _cpfController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'CPF*', prefixIcon: Icons.badge_outlined), keyboardType: TextInputType.number, inputFormatters: [_cpfFormatter], validator: (v) { if (_cpfFormatter.getUnmaskedText().length != 11) return 'CPF Inválido'; return null; }).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 15),
              TextFormField(
                controller: _dobController,
                enabled: !_isLoading,
                style: const TextStyle(color: textColor),
                decoration: _inputDecoration(labelText: 'Data Nasc. (DD/MM/AAAA)*', prefixIcon: Icons.calendar_today_outlined, suffixIcon: Icons.calendar_month),
                keyboardType: TextInputType.datetime,
                inputFormatters: [_dobFormatter],
                onTap: () => _isLoading ? null : _selectDate(context),
                onChanged: (value) {
                  if (value.length == 10) {
                    try {
                      DateTime parsedDate = DateFormat('dd/MM/yyyy').parseStrict(value);
                      if (mounted) { setState(() { _selectedDate = parsedDate; });}
                    } catch (e) {
                      if (mounted) { setState(() { _selectedDate = null; });}
                    }
                  } else {
                    if (mounted && _selectedDate != null) { setState(() { _selectedDate = null; });}
                  }
                },
                validator: (v) { if (v == null || v.isEmpty) return 'Data obrigatória'; if (v.length != 10) return 'Formato inválido'; try { DateFormat('dd/MM/yyyy').parseStrict(v); return null; } catch (e) { return 'Data inválida'; } },
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 15),
              TextFormField(controller: _phoneController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'Telefone/Celular*', prefixIcon: Icons.phone_android_outlined), keyboardType: TextInputType.phone, inputFormatters: [_phoneFormatter], validator: (v) { if (_phoneFormatter.getUnmaskedText().length < 10) return 'Telefone inválido'; return null; }).animate().fadeIn(delay: 250.ms),
              
              const SizedBox(height: 25),
              Text('Endereço', textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(color: primaryColor, fontWeight: FontWeight.w600) ?? const TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 15),

              TextFormField(controller: _cepController, focusNode: _cepFocusNode, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'CEP*', prefixIcon: Icons.pin_drop_outlined, suffixIconWidget: _isFetchingCep ? const Padding(padding: EdgeInsets.all(10.0), child: SpinKitFadingCircle(color: primaryColor, size: 20)) : null,), keyboardType: TextInputType.number, inputFormatters: [_cepFormatter], validator: (v) { if (v == null || v.isEmpty) return 'CEP Obrigatório'; if (_cepController.text.replaceAll(RegExp(r'[^0-9]'), '').length != 8) return 'CEP Inválido'; return null; },).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 15),
              TextFormField(controller: _streetController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'Logradouro (Rua/Av.)*', prefixIcon: Icons.signpost_outlined), validator: (v)=>(v==null||v.isEmpty)?'Obrigatório':null).animate().fadeIn(delay: 350.ms),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(flex: 2, child: TextFormField(focusNode: _numberFocusNode, controller: _numberController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'Número*', prefixIcon: Icons.onetwothree), keyboardType: TextInputType.text, validator: (v)=>(v==null||v.isEmpty)?'Obrigatório':null).animate().fadeIn(delay: 400.ms)),
                  const SizedBox(width: 10),
                  Expanded(flex: 3, child: TextFormField(controller: _complementController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'Complemento', prefixIcon: Icons.add_home_outlined)).animate().fadeIn(delay: 450.ms)),
                ],
              ),
              const SizedBox(height: 15),
              TextFormField(controller: _neighborhoodController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'Bairro*', prefixIcon: Icons.holiday_village_outlined), validator: (v)=>(v==null||v.isEmpty)?'Obrigatório':null).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(flex: 3, child: TextFormField(controller: _cityController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'Cidade*', prefixIcon: Icons.location_city_rounded), validator: (v)=>(v==null||v.isEmpty)?'Obrigatório':null).animate().fadeIn(delay: 550.ms)),
                  const SizedBox(width: 10),
                  Expanded(flex: 1, child: TextFormField(controller: _stateController, enabled: !_isLoading, style: const TextStyle(color: textColor), maxLength: 2, textCapitalization: TextCapitalization.characters, decoration: _inputDecoration(labelText: 'UF*', prefixIcon: Icons.map_outlined), validator: (v){if(v==null||v.isEmpty)return 'UF'; if(v.length!=2)return'Inválido'; return null;}).animate().fadeIn(delay: 600.ms)),
                ],
              ),
              
              const SizedBox(height: 35),
              Text('Crie seu acesso', textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(color: primaryColor, fontWeight: FontWeight.w600) ?? const TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 25),
              TextFormField(controller: _emailController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'Email*', prefixIcon: Icons.alternate_email), keyboardType: TextInputType.emailAddress, validator: (v) => (v == null || v.isEmpty || !v.contains('@')) ? 'Email inválido' : null ).animate().fadeIn(delay: 650.ms),
              const SizedBox(height: 15),
              TextFormField(controller: _passwordController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'Senha*', prefixIcon: Icons.lock_outline), obscureText: true, validator: (v) => (v == null || v.trim().length < 6) ? 'Mínimo 6 caracteres' : null ).animate().fadeIn(delay: 700.ms),
              const SizedBox(height: 15),
              TextFormField(controller: _confirmPasswordController, enabled: !_isLoading, style: const TextStyle(color: textColor), decoration: _inputDecoration(labelText: 'Confirmar Senha*', prefixIcon: Icons.lock_reset_outlined), obscureText: true, validator: _validateConfirmPassword ).animate().fadeIn(delay: 750.ms),
              const SizedBox(height: 40),
              _isLoading
                  ? const Center(child: SpinKitFadingCube(color: primaryColor, size: 40.0))
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.app_registration_rounded),
                      label: const Text('Criar Conta e Avançar'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: _submitSignupForm,
                    ).animate().fadeIn(delay: 800.ms).scale(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}