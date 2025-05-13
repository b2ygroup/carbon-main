// lib/screens/signup/vehicle_registration_signup_screen.dart (VERSÃO VALIDADA #129)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

// Importa o enum e o AuthWrapper (Use o nome correto do seu pacote)
import 'package:carbon/models/vehicle_type_enum.dart';
import 'package:carbon/main.dart'; // Para AuthWrapper

class VehicleRegistrationScreenForSignup extends StatefulWidget {
  const VehicleRegistrationScreenForSignup({super.key});
  @override State<VehicleRegistrationScreenForSignup> createState() => _VehicleRegistrationScreenForSignupState();
}

class _VehicleRegistrationScreenForSignupState extends State<VehicleRegistrationScreenForSignup> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isMakeLoading = false;
  bool _isModelLoading = false;

  // Estados do Formulário
  int? _vehicleYear;
  VehicleType? _selectedVehicleType;
  final String _vehicleLicensePlate = '';
  String? _selectedMake;
  String? _selectedModel;

  // Dados Exemplo (TODO: Substituir)
  final List<String> _allMakes = [ 'Fiat', 'Volkswagen', 'Chevrolet', 'Ford', 'Toyota', 'Honda', 'Hyundai', 'Renault', 'Jeep', 'Nissan', 'Peugeot', 'Citroën', 'BMW', 'Mercedes-Benz', 'Audi' ];
  final Map<String, List<String>> _modelsByMake = { 'Fiat': ['Mobi', 'Argo', 'Cronos', 'Strada', 'Toro', 'Pulse', 'Fastback', 'Uno', 'Palio'], 'Volkswagen': ['Gol', 'Voyage', 'Polo', 'Virtus', 'T-Cross', 'Nivus', 'Taos', 'Saveiro', 'Amarok'], /* ... etc ... */ };

  // Cores (Definidas aqui, idealmente viriam do ThemeData)
  static const Color primaryColor = Color(0xFF00FFFF);
  static const Color focusColor = Color(0xFF00BFFF);
  static final Color errorColor = Colors.redAccent[100]!;
  static final Color inputBorderColor = Colors.grey[800]!;
  static final Color labelColor = Colors.grey[400]!;
  static const Color textColor = Color(0xFFECEFF4);

  @override void dispose() { super.dispose(); }

  // --- Função para mostrar diálogo de seleção (COMPLETA) ---
  Future<String?> _showSelectionDialog({ required BuildContext context, required String title, required List<String> items }) async {
     String searchQuery = ''; List<String> filteredItems;
     return showDialog<String>( context: context, builder: (BuildContext dialogContext) {
        return StatefulBuilder( builder: (context, setDialogState) {
            if (searchQuery.isNotEmpty) { filteredItems = items.where((i) => i.toLowerCase().contains(searchQuery.toLowerCase())).toList(); }
            else { filteredItems = List.from(items); }
            // Retorna AlertDialog CORRETAMENTE
            return AlertDialog(
              backgroundColor: Theme.of(context).cardTheme.color ?? Theme.of(context).dialogBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), title: Text(title, style: GoogleFonts.rajdhani()),
              content: SizedBox( width: double.maxFinite, height: MediaQuery.of(context).size.height * 0.5,
                child: Column( mainAxisSize: MainAxisSize.min, children: [
                    TextField( autofocus: true, decoration: const InputDecoration( hintText: 'Buscar...', prefixIcon: Icon(Icons.search), isDense: true ), onChanged: (value) => setDialogState(() => searchQuery = value) ), const SizedBox(height: 10),
                    Expanded( child: filteredItems.isEmpty ? const Center(child: Text('Nenhum item encontrado.')) : ListView.builder( shrinkWrap: true, itemCount: filteredItems.length, itemBuilder: (context, index) { final item = filteredItems[index]; return ListTile( title: Text(item), onTap: () => Navigator.of(dialogContext).pop(item)); }, ) ) ] ) ),
              actions: <Widget>[ TextButton( child: const Text('Cancelar'), onPressed: () => Navigator.of(dialogContext).pop()) ], ); }); });
  }

  // --- Funções para chamar o diálogo (COMPLETAS) ---
  Future<void> _selectMake() async { setState(() => _isMakeLoading = true); await Future.delayed(700.ms); setState(() => _isMakeLoading = false); if (!mounted) return; final String? selected = await _showSelectionDialog( context: context, title: 'Selecione a Marca', items: _allMakes ); if(selected!=null && selected!=_selectedMake) setState((){_selectedMake=selected; _selectedModel=null;}); }
  Future<void> _selectModel() async { if(_selectedMake==null) return; setState(() => _isModelLoading = true); await Future.delayed(500.ms); final List<String> availableModels = _modelsByMake[_selectedMake!] ?? []; setState(() => _isModelLoading = false); if (!mounted) return; if (availableModels.isEmpty) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum modelo para esta marca.'))); return; } final String? selected = await _showSelectionDialog( context: context, title: 'Selecione o Modelo ($_selectedMake)', items: availableModels ); if(selected!=null && selected!=_selectedModel) setState(()=>_selectedModel=selected); }

  // --- Função de Submit (COMPLETA) ---
  void _submitForm() async { final isValid = _formKey.currentState?.validate() ?? false; if (!isValid) return; _formKey.currentState?.save(); if (_selectedVehicleType == null || _selectedMake == null || _selectedModel == null) { if(mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Selecione Tipo, Marca e Modelo.'), backgroundColor: Colors.orangeAccent)); return; } setState(()=>_isLoading=true); await Future.delayed(300.ms); try { final user = FirebaseAuth.instance.currentUser; if (user == null) throw Exception('Usuário não encontrado.'); String userId = user.uid; final Map<String, dynamic> vehicleData = {'userId':userId, 'make':_selectedMake, 'model':_selectedModel, 'year':_vehicleYear, 'type':_selectedVehicleType!.name, 'licensePlate':_vehicleLicensePlate.isNotEmpty?_vehicleLicensePlate.toUpperCase():null, 'createdAt':FieldValue.serverTimestamp()}; print("Salvando primeiro veículo: $vehicleData"); await FirebaseFirestore.instance.collection('vehicles').add(vehicleData); print("Primeiro veículo salvo!"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('${_selectedMake??""} ${_selectedModel??""} adicionado!'), backgroundColor: Colors.green)); Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (ctx)=>const AuthWrapper()), (r)=>false); } } catch (error, stackTrace) { print("!!! ERRO AO SALVAR VEÍCULO !!!\n$error\n$stackTrace"); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $error'), backgroundColor: errorColor)); } finally { if(mounted) setState(()=>_isLoading=false); } }

  // --- Função Helper _inputDecoration (COMPLETA E CORRETA) ---
  InputDecoration _inputDecoration({ required String labelText, required IconData prefixIcon, required Color labelColor,
      required Color iconColor, required Color borderColor, required Color focusColor, required Color errorColor }) {
    // Garante retorno de InputDecoration
    return InputDecoration( labelText: labelText, labelStyle: GoogleFonts.poppins(textStyle:TextStyle(color: labelColor, fontSize: 14)),
      prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Icon(prefixIcon, color: iconColor, size: 20)),
      prefixIconConstraints: const BoxConstraints(minWidth:20, minHeight:20), contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
      filled: true, fillColor: Colors.white.withOpacity(0.05), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: borderColor.withOpacity(0.5))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: focusColor, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: errorColor)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: errorColor, width: 1.5)),
      counterText: "", errorStyle: TextStyle(color: errorColor.withOpacity(0.95), fontSize: 12) );
  }

  // --- Função Helper _buildSelectionRow (COMPLETA E CORRETA) ---
  Widget _buildSelectionRow({ required String label, String? value, VoidCallback? onPressed, required String selectText, String? placeholder, bool isLoading = false}) {
    const currentTextColor = textColor; final currentLabelColor = labelColor; const currentPrimaryColor = primaryColor;
    final currentInputBorderColor = inputBorderColor; const currentFocusColor = focusColor; final currentErrorColor = errorColor; const currentIconColor = primaryColor;
    // Garante retorno de InputDecorator
    return InputDecorator(
      decoration: _inputDecoration( labelText: label, prefixIcon: Icons.directions_car_outlined, labelColor: currentLabelColor, iconColor: currentIconColor, borderColor: currentInputBorderColor, focusColor: currentFocusColor, errorColor: currentErrorColor),
      child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded( child: Text( value ?? placeholder ?? 'Não selecionado', overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(textStyle:TextStyle( color: value!=null?currentTextColor:currentLabelColor.withOpacity(0.7), fontSize: 16, fontWeight: value!=null?FontWeight.w500:FontWeight.normal )))),
          isLoading ? const SizedBox(height: 24, width: 24, child: SpinKitFadingCircle(color: primaryColor, size: 20))
          : TextButton( style: TextButton.styleFrom( foregroundColor: currentPrimaryColor, padding: const EdgeInsets.symmetric(horizontal: 8) ), onPressed: onPressed,
              child: Row( mainAxisSize: MainAxisSize.min, children: [ Text(selectText, style: GoogleFonts.poppins(fontSize: 14)), const Icon(Icons.search, size: 20) ] ))])); // Ícone de busca no botão
  }

  // --- Método Build Principal (COMPLETO E CORRIGIDO) ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const currentPrimaryColor = primaryColor; const currentFocusColor = focusColor; final currentErrorColor = errorColor;
    final currentInputBorderColor = inputBorderColor; final currentLabelColor = labelColor; const currentIconColor = primaryColor;

    // Garante retorno de Scaffold
    return Scaffold(
      appBar: AppBar( title: Text('Cadastre Seu Veículo', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600)), automaticallyImplyLeading: false ),
      body: Center( child: ConstrainedBox( constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView( padding: const EdgeInsets.all(25.0),
            child: Form( key: _formKey,
              child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                  Text('Último passo: informe os dados do seu veículo principal.', textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(color: currentLabelColor)), const SizedBox(height: 35),
                  // Chamadas CORRETAS para _buildSelectionRow
                  _buildSelectionRow( label: 'Marca', value: _selectedMake, onPressed: _isLoading ? null : _selectMake, selectText: 'Buscar Marca', isLoading: _isMakeLoading).animate().fadeIn(delay: 100.ms), const SizedBox(height: 20),
                  _buildSelectionRow( label: 'Modelo', value: _selectedModel, onPressed: _isLoading || _isMakeLoading || _selectedMake==null ? null : _selectModel, selectText: 'Buscar Modelo', placeholder: _selectedMake==null?'Selecione marca':null, isLoading: _isModelLoading).animate().fadeIn(delay: 200.ms), const SizedBox(height: 20),
                  // Chamadas CORRETAS para _inputDecoration
                  TextFormField( enabled: !_isLoading, decoration: _inputDecoration(labelText:'Ano', prefixIcon: Icons.calendar_month_outlined, labelColor: currentLabelColor, iconColor: currentIconColor, borderColor: currentInputBorderColor, focusColor: currentFocusColor, errorColor: currentErrorColor), /*...*/).animate().fadeIn(delay: 300.ms), const SizedBox(height: 20),
                  TextFormField( enabled: !_isLoading, decoration: _inputDecoration(labelText:'Placa (Opcional)', prefixIcon: Icons.badge_outlined, labelColor: currentLabelColor, iconColor: currentIconColor, borderColor: currentInputBorderColor, focusColor: currentFocusColor, errorColor: currentErrorColor), /*...*/).animate().fadeIn(delay: 400.ms), const SizedBox(height: 20),
                  // Dropdown CORRETO
                  DropdownButtonFormField<VehicleType>( value: _selectedVehicleType, decoration: _inputDecoration(labelText:'Tipo Combustível/Motor', prefixIcon: Icons.speed_outlined, labelColor: currentLabelColor, iconColor: currentIconColor, borderColor: currentInputBorderColor, focusColor: currentFocusColor, errorColor: currentErrorColor),
                    items: VehicleType.values.map((t)=>DropdownMenuItem<VehicleType>(value:t, child:Row(children:[Icon(t.icon,size:20,color:t.displayColor), const SizedBox(width:10), Text(t.displayName)]))).toList(), // items OK
                    onChanged: _isLoading ? null : (v)=>setState(()=>_selectedVehicleType=v), // onChanged OK
                    validator: (v)=>v==null?'Selecione':null ).animate().fadeIn(delay: 500.ms), const SizedBox(height: 45),
                  // Botão Salvar
                  _isLoading ? const Center(child: SpinKitWave(color: currentPrimaryColor, size: 30.0))
                  : ElevatedButton.icon( onPressed: _submitForm, icon: const Icon(Icons.directions_car_filled), label: const Text('Concluir Cadastro'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16))).animate().fadeIn(delay: 600.ms).scale(), const SizedBox(height: 20),
                ], ), ), ), ), ), ); // Fim Scaffold Body
  } // Fim build
} // Fim State