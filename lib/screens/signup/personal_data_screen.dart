// lib/screens/signup/personal_data_screen.dart (Corrigido return _inputDecoration)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Verifique o caminho

class PersonalDataScreen extends StatefulWidget {
 const PersonalDataScreen({super.key});
 @override State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
 final _formKey = GlobalKey<FormState>(); final bool _isLoading = false;
 final _nameController = TextEditingController(); final _cpfController = TextEditingController();
 final _dobController = TextEditingController(); final _phoneController = TextEditingController();
 final _emailController = TextEditingController(); final _passwordController = TextEditingController();
 final _confirmPasswordController = TextEditingController(); DateTime? _selectedDate;
 final _cpfFormatter = MaskTextInputFormatter(mask:'###.###.###-##', filter:{"#":RegExp(r'[0-9]')});
 final _phoneFormatter = MaskTextInputFormatter(mask:'(##) #####-####', filter:{"#":RegExp(r'[0-9]')});
 final _dobFormatter = MaskTextInputFormatter(mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});
 static const Color primaryColor = Color(0xFF00BFFF); static const Color secondaryColor = Color(0xFF00FFFF);
 static final Color errorColor = Colors.redAccent[100]!; static final Color inputBorderColor = Colors.grey[800]!;
 static final Color labelColor = Colors.grey[400]!; static const Color textColor = Colors.white;

 @override void dispose() { _nameController.dispose(); _cpfController.dispose(); _dobController.dispose(); _phoneController.dispose(); _emailController.dispose(); _passwordController.dispose(); _confirmPasswordController.dispose(); super.dispose(); }

 Future<void> _selectDate(BuildContext context) async { /* ... código sem alteração ... */ }
 String? _validateConfirmPassword(String? value) {
   return null;
  /* ... código sem alteração ... */ }
 void _submitSignupForm() async { /* ... código sem alteração ... */ }

 @override
 Widget build(BuildContext context) {
   final theme = Theme.of(context);
   return Scaffold(
     appBar: AppBar( title: Text('Cadastro Pessoal', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600))),
     body: SingleChildScrollView( padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
       child: Form( key: _formKey,
         child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
           Text('Conte-nos sobre você', style: theme.textTheme.titleLarge?.copyWith(color: primaryColor)), const SizedBox(height: 25),
           TextFormField(controller: _nameController, decoration: _inputDecoration(labelText: 'Nome Completo', prefixIcon: Icons.person_outline), textCapitalization: TextCapitalization.words, validator: (v)=>(v==null||v.isEmpty)?'Obrigatório':null ), const SizedBox(height: 15),
           TextFormField(controller: _cpfController, decoration: _inputDecoration(labelText: 'CPF', prefixIcon: Icons.badge_outlined), keyboardType: TextInputType.number, inputFormatters: [_cpfFormatter], validator: (v){if(_cpfFormatter.getUnmaskedText().length!=11)return 'Inválido'; return null;}), const SizedBox(height: 15),
           TextFormField( controller: _dobController, decoration: _inputDecoration(labelText: 'Data Nasc (DD/MM/AAAA)', prefixIcon: Icons.calendar_today_outlined, suffixIcon: Icons.calendar_month), keyboardType: TextInputType.datetime, inputFormatters: [_dobFormatter], onTap: ()=>_selectDate(context), validator: (v){if(v==null||v.isEmpty){return 'Obrigatória';} if(v.length!=10)return 'Formato'; try{DateFormat('dd/MM/yyyy').parseStrict(v); return null;}catch(e){return'Inválida';}} ), const SizedBox(height: 15),
           TextFormField(controller: _phoneController, decoration: _inputDecoration(labelText: 'Telefone/Celular', prefixIcon: Icons.phone_android_outlined), keyboardType: TextInputType.phone, inputFormatters: [_phoneFormatter], validator: (v){if(_phoneFormatter.getUnmaskedText().length<10)return 'Inválido'; return null;}),
           const SizedBox(height: 35), Text('Crie seu acesso', style: theme.textTheme.titleLarge?.copyWith(color: primaryColor)), const SizedBox(height: 25),
           TextFormField(controller: _emailController, decoration: _inputDecoration(labelText: 'Email', prefixIcon: Icons.alternate_email), keyboardType: TextInputType.emailAddress, validator: (v)=>(v==null||v.isEmpty||!v.contains('@'))?'Inválido':null ), const SizedBox(height: 15),
           TextFormField(controller: _passwordController, decoration: _inputDecoration(labelText: 'Senha', prefixIcon: Icons.lock_outline), obscureText: true, validator: (v)=>(v==null||v.length<6)?'Min 6 chars':null ), const SizedBox(height: 15),
           TextFormField(controller: _confirmPasswordController, decoration: _inputDecoration(labelText: 'Confirmar Senha', prefixIcon: Icons.lock_reset_outlined), obscureText: true, validator: _validateConfirmPassword ), const SizedBox(height: 40),
           _isLoading ? const Center(child: SpinKitFadingCube(color: primaryColor, size: 40.0)) : ElevatedButton.icon( icon: const Icon(Icons.app_registration_rounded), label: const Text('Criar Conta e Avançar'), style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 15), textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)), onPressed: _submitSignupForm ), const SizedBox(height: 20),
         ], ).animate().fadeIn(duration: 300.ms),
       ),
     ),
   );
 }

 // <<< CORRIGIDO: Adicionado "return" >>>
 InputDecoration _inputDecoration({ required String labelText, required IconData prefixIcon, IconData? suffixIcon }) {
    final currentLabelColor = labelColor; const currentIconColor = primaryColor; final currentBorderColor = inputBorderColor;
    const currentFocusColor = secondaryColor; final currentErrorColor = errorColor;
    // <<< CORRIGIDO: Adicionado "return" >>>
    return InputDecoration(
      labelText: labelText, labelStyle: GoogleFonts.poppins(textStyle:TextStyle(color: currentLabelColor, fontSize: 14)),
      prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Icon(prefixIcon, color: currentIconColor.withOpacity(0.8), size: 20)),
      suffixIcon: suffixIcon != null ? Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Icon(suffixIcon, color: currentLabelColor.withOpacity(0.8), size: 20)) : null,
      prefixIconConstraints: const BoxConstraints(minWidth:20, minHeight:20), filled: true, fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0), border: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: currentBorderColor.withOpacity(0.5))),
      enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: currentBorderColor.withOpacity(0.5))),
      focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: currentFocusColor, width: 2.0)),
      errorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: currentErrorColor)),
      focusedErrorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: currentErrorColor, width: 1.5)),
      errorStyle: TextStyle(color: currentErrorColor.withOpacity(0.95), fontSize: 12)
  );
 }
}