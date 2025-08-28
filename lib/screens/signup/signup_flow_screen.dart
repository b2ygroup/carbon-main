// lib/screens/signup/signup_flow_screen.dart (VERIFICAR E USAR ESTA VERSÃO)

import 'dart:convert';
import 'package:carbon/screens/signup/widgets/vehicle_form_widget.dart';
import 'package:carbon/services/wallet_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class SignupFlowScreen extends StatefulWidget {
  const SignupFlowScreen({super.key});

  @override
  State<SignupFlowScreen> createState() => _SignupFlowScreenState();
}

class _SignupFlowScreenState extends State<SignupFlowScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  User? _createdUser;

  final _personalDataFormKey = GlobalKey<FormState>();
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
  static final Color labelColor = Colors.grey[400]!;
  static const Color textColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _cepFocusNode.addListener(_onCepFocusChange);
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  Future<void> _submitPersonalDataAndGoToNext() async {
    final isValid = _personalDataFormKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      _createdUser = userCredential.user;

      if (_createdUser == null) throw Exception('Falha ao criar usuário na autenticação.');
      
      final userId = _createdUser!.uid;
      String? dobString;
      if (_selectedDate != null) {
        dobString = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      }
      Map<String, dynamic> userData = {
        'uid': userId, 'fullName': _nameController.text.trim(), 'cpf': _cpfFormatter.getUnmaskedText(),
        'dateOfBirth': dobString, 'phone': _phoneFormatter.getUnmaskedText(), 'email': _createdUser!.email,
        'createdAt': FieldValue.serverTimestamp(), 'accountType': 'PF', 'isAdmin': false,
        'address': {
          'cep': _cepController.text.replaceAll(RegExp(r'[^0-9]'), ''), 'street': _streetController.text.trim(),
          'number': _numberController.text.trim(), 'complement': _complementController.text.trim(),
          'neighborhood': _neighborhoodController.text.trim(), 'city': _cityController.text.trim(),
          'state': _stateController.text.trim().toUpperCase(),
        }
      };
      await FirebaseFirestore.instance.collection('users').doc(userId).set(userData);
      await WalletService().initializeWallet(userId);

      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);

    } catch (e) {
       if (_createdUser != null) {
        await _createdUser!.delete().catchError((err) => debugPrint("Falha crítica ao reverter usuário: $err"));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro no cadastro: ${e.toString()}'), backgroundColor: errorColor));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToPreviousPage() {
    _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }
  
  void _onCepFocusChange() {
    if (!_cepFocusNode.hasFocus && _cepController.text.isNotEmpty) _fetchAddressFromCep();
  }

  Future<void> _fetchAddressFromCep() async {
    final String cepToSearch = _cepController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cepToSearch.length != 8) return;
    if (mounted) setState(() => _isFetchingCep = true);
    try {
      final response = await http.get(Uri.parse('https://viacep.com.br/ws/$cepToSearch/json/'));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data.containsKey('erro') && data['erro'] == true) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('CEP não encontrado.'), backgroundColor: errorColor));
        } else {
          setState(() {
            _streetController.text = data['logradouro'] ?? ''; _neighborhoodController.text = data['bairro'] ?? '';
            _cityController.text = data['localidade'] ?? ''; _stateController.text = data['uf'] ?? '';
          });
          if (mounted) FocusScope.of(context).requestFocus(_numberFocusNode);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Erro de conexão ao buscar CEP.'), backgroundColor: errorColor));
    } finally {
      if (mounted) setState(() => _isFetchingCep = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now(), locale: const Locale('pt', 'BR'));
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cadastro Pessoal - Passo ${_currentPage + 1} de 2', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.grey[900],
        leading: _currentPage == 0 
            ? BackButton(onPressed: () => Navigator.of(context).pop()) 
            : IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: _goToPreviousPage),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) => setState(() => _currentPage = page),
        children: [
          _buildPersonalDataPage(),
          if (_createdUser != null) 
            VehicleFormWidget(userId: _createdUser!.uid, accountType: 'PF')
          else 
            const Center(child: Text("Erro: usuário não criado."))
        ],
      ),
    );
  }

  Widget _buildPersonalDataPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _personalDataFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Conte-nos sobre você', textAlign: TextAlign.center, style: TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 25),
            TextFormField(controller: _nameController, decoration: _inputDecoration(labelText: 'Nome Completo*', prefixIcon: Icons.person_outline), validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null),
            const SizedBox(height: 15),
            TextFormField(controller: _cpfController, decoration: _inputDecoration(labelText: 'CPF*', prefixIcon: Icons.badge_outlined), keyboardType: TextInputType.number, inputFormatters: [_cpfFormatter], validator: (v) { if (_cpfFormatter.getUnmaskedText().length != 11) return 'CPF Inválido'; return null; }),
            const SizedBox(height: 15),
            TextFormField(
              controller: _dobController,
              decoration: _inputDecoration(
                labelText: 'Data Nasc. (DD/MM/AAAA)*', 
                prefixIcon: Icons.calendar_today_outlined, 
                suffixIconWidget: IconButton(
                  icon: Icon(Icons.calendar_month, color: labelColor.withAlpha(204)),
                  onPressed: () => _isLoading ? null : _selectDate(context),
                )
              ), 
              keyboardType: TextInputType.datetime, 
              inputFormatters: [_dobFormatter], 
              onTap: () => _isLoading ? null : _selectDate(context), 
              validator: (v) { if (v == null || v.isEmpty) return 'Data obrigatória'; return null; }
            ),
            const SizedBox(height: 15),
            TextFormField(controller: _phoneController, decoration: _inputDecoration(labelText: 'Telefone/Celular*', prefixIcon: Icons.phone_android_outlined), keyboardType: TextInputType.phone, inputFormatters: [_phoneFormatter], validator: (v) { if (_phoneFormatter.getUnmaskedText().length < 10) return 'Telefone inválido'; return null; }),
            const SizedBox(height: 25),
            const Text('Endereço', textAlign: TextAlign.center, style: TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 15),
            TextFormField(controller: _cepController, focusNode: _cepFocusNode, decoration: _inputDecoration(labelText: 'CEP*', prefixIcon: Icons.pin_drop_outlined, suffixIconWidget: _isFetchingCep ? const Padding(padding: EdgeInsets.all(10.0), child: SpinKitFadingCircle(color: primaryColor, size: 20)) : null,), keyboardType: TextInputType.number, inputFormatters: [_cepFormatter], validator: (v) { if (v == null || v.isEmpty) return 'CEP Obrigatório'; return null; }),
            const SizedBox(height: 15),
            TextFormField(controller: _streetController, decoration: _inputDecoration(labelText: 'Logradouro (Rua/Av.)*', prefixIcon: Icons.signpost_outlined), validator: (v)=>(v==null||v.isEmpty)?'Obrigatório':null),
            const SizedBox(height: 15),
            Row(children: [ Expanded(flex: 2, child: TextFormField(focusNode: _numberFocusNode, controller: _numberController, decoration: _inputDecoration(labelText: 'Número*', prefixIcon: Icons.onetwothree), keyboardType: TextInputType.text, validator: (v)=>(v==null||v.isEmpty)?'Obrigatório':null)), const SizedBox(width: 10), Expanded(flex: 3, child: TextFormField(controller: _complementController, decoration: _inputDecoration(labelText: 'Complemento', prefixIcon: Icons.add_home_outlined)))]),
            const SizedBox(height: 15),
            TextFormField(controller: _neighborhoodController, decoration: _inputDecoration(labelText: 'Bairro*', prefixIcon: Icons.holiday_village_outlined), validator: (v)=>(v==null||v.isEmpty)?'Obrigatório':null),
            const SizedBox(height: 15),
            Row(children: [ Expanded(flex: 3, child: TextFormField(controller: _cityController, decoration: _inputDecoration(labelText: 'Cidade*', prefixIcon: Icons.location_city_rounded), validator: (v)=>(v==null||v.isEmpty)?'Obrigatório':null)), const SizedBox(width: 10), Expanded(flex: 1, child: TextFormField(controller: _stateController, maxLength: 2, textCapitalization: TextCapitalization.characters, decoration: _inputDecoration(labelText: 'UF*', prefixIcon: Icons.map_outlined), validator: (v){if(v==null||v.isEmpty)return 'UF'; return null;}))]),
            const SizedBox(height: 35),
            const Text('Crie seu acesso', textAlign: TextAlign.center, style: TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 25),
            TextFormField(controller: _emailController, decoration: _inputDecoration(labelText: 'Email*', prefixIcon: Icons.alternate_email), keyboardType: TextInputType.emailAddress, validator: (v) => (v == null || v.isEmpty || !v.contains('@')) ? 'Email inválido' : null ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _passwordController,
              decoration: _inputDecoration(labelText: 'Senha*', prefixIcon: Icons.lock_outline),
              obscureText: true,
              validator: (v) => (v == null || v.trim().length < 6) ? 'Mínimo 6 caracteres' : null,
              onChanged: (value) {
                if (_confirmPasswordController.text.isNotEmpty) {
                  _personalDataFormKey.currentState?.validate();
                }
              },
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: _inputDecoration(labelText: 'Confirmar Senha*', prefixIcon: Icons.lock_reset_outlined),
              obscureText: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                if (v != _passwordController.text) return 'As senhas não coincidem';
                return null;
              },
            ),
            const SizedBox(height: 40),
            if (_isLoading)
              const Center(child: SpinKitWave(color: primaryColor, size: 30.0))
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward_ios_rounded),
                label: const Text('Avançar para Veículo'),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 15)),
                onPressed: _submitPersonalDataAndGoToNext,
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({ required String labelText, required IconData prefixIcon, Widget? suffixIconWidget}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.poppins(textStyle: TextStyle(color: labelColor, fontSize: 14)),
      prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Icon(prefixIcon, color: primaryColor.withAlpha(204), size: 20)),
      suffixIcon: suffixIconWidget,
      filled: true,
      fillColor: Colors.white.withAlpha(13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey[800]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey[800]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: secondaryColor, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: errorColor)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: errorColor, width: 1.5)),
    );
  }
}