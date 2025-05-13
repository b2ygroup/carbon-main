// lib/screens/signup/registration_screen.dart (COMPLETO - Cores Constantes Corrigido)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:carbon/models/vehicle_type_enum.dart';
import 'dart:async';

class RegistrationScreen extends StatefulWidget {
 const RegistrationScreen({super.key});
 @override State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
 final _formKey = GlobalKey<FormState>(); bool _isLoading = false;
 int? _year; VehicleType? _selectedType; String _licensePlate = '';
 String? _selectedMake; String? _selectedModel;

 final _yearController = TextEditingController();
 final _plateController = TextEditingController();

 final List<String> _allMakes = [ 'Fiat', 'Volkswagen', 'Chevrolet', 'Ford', 'Toyota', 'Honda', 'Hyundai', 'Renault', 'Jeep', 'Nissan', 'Peugeot', 'Citroën', 'BMW', 'Mercedes-Benz', 'Audi', 'Mitsubishi', 'Kia', 'Caoa Chery', 'Land Rover', 'Volvo', 'Outra' ];
 final Map<String, List<String>> _modelsByMake = { 'Fiat': ['Mobi', 'Argo', 'Cronos', 'Pulse', 'Strada', 'Toro', 'Fiorino', 'Ducato', 'Scudo', '500e', 'Outro'], 'Volkswagen': ['Gol', 'Voyage', 'Polo', 'Virtus', 'Nivus', 'T-Cross', 'Taos', 'Saveiro', 'Amarok', 'ID.4', 'Outro'], /* Adicione mais */ };

 // <<< CORREÇÃO: Cores definidas como const Color(0x...) >>>
 static const Color primaryColor = Color(0xFF00BFFF); // DeepSkyBlue
 static const Color secondaryColor = Color(0xFF00FFFF); // Cyan/Aqua
 static const Color errorColor = Color(0xFFFF8A80); // Red Accent 100
 static const Color inputFillColor = Color(0x0DFFFFFF); // White with 5% opacity (aprox)
 static const Color inputBorderColor = Color(0xFF616161); // Grey 700
 static const Color labelColor = Color(0xFFBDBDBD); // Grey 400
 static const Color textColor = Colors.white; // Mantido
 static const Color iconColor = primaryColor; // Mantido

 @override void dispose() { _yearController.dispose(); _plateController.dispose(); super.dispose(); }

 Future<String?> _showSelectionDialog({ required BuildContext context, required String title, required List<String> items, String? currentSelection, }) async {
    // Implementação do Dialog (sem alterações, mas garanta que funcione com as cores const)
    return showDialog<String>( context: context, builder: (BuildContext context) { String? tempSelection = currentSelection; return AlertDialog( backgroundColor: Colors.grey[900], title: Text(title, style: GoogleFonts.orbitron(color: primaryColor)), content: SizedBox( width: double.maxFinite, child: ListView.builder( shrinkWrap: true, itemCount: items.length, itemBuilder: (BuildContext context, int index) { final item = items[index]; return RadioListTile<String>( title: Text(item, style: GoogleFonts.poppins(color: textColor)), value: item, groupValue: tempSelection, onChanged: (String? value) { Navigator.of(context).pop(value); }, activeColor: secondaryColor, controlAffinity: ListTileControlAffinity.trailing, contentPadding: EdgeInsets.zero, ); }, ), ), actions: <Widget>[ TextButton( child: const Text('Cancelar', style: TextStyle(color: labelColor)), onPressed: () => Navigator.of(context).pop(null), ), ], ); }, );
 }
 Future<void> _selectMake() async { FocusScope.of(context).unfocus(); final String? make = await _showSelectionDialog( context: context, title: 'Selecione a Marca', items: _allMakes, currentSelection: _selectedMake, ); if (make != null && make != _selectedMake) { setState(() { _selectedMake = make; _selectedModel = null; }); } }
 Future<void> _selectModel() async { if (_selectedMake == null) return; FocusScope.of(context).unfocus(); final List<String> models = _modelsByMake[_selectedMake!] ?? ['Modelo Único', 'Outro']; final String? model = await _showSelectionDialog( context: context, title: 'Selecione o Modelo', items: models, currentSelection: _selectedModel, ); if (model != null) { setState(() => _selectedModel = model); } }

 void _submitForm() async {
   final isValid = _formKey.currentState?.validate() ?? false; if (!isValid) return;
   _formKey.currentState?.save();
   if (_selectedType == null || _selectedMake == null || _selectedModel == null) { if(mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Selecione Tipo, Marca e Modelo.'), backgroundColor: Colors.orangeAccent)); return; }
   setState(()=>_isLoading=true); await Future.delayed(300.ms);
   try {
     final user = FirebaseAuth.instance.currentUser; if (user == null) throw Exception('Usuário não autenticado.'); String userId = user.uid;
     _year = int.tryParse(_yearController.text); _licensePlate = _plateController.text.trim();
     debugPrint("[RegistrationScreen] Valor de _licensePlate no submit: '$_licensePlate'");
     final Map<String, dynamic> vehicleData = {'userId':userId, 'make':_selectedMake, 'model':_selectedModel, 'year':_year, 'type':_selectedType!.name, 'licensePlate':_licensePlate.isNotEmpty?_licensePlate.toUpperCase():null, 'createdAt':FieldValue.serverTimestamp()};
     print("Salvando veículo: $vehicleData");
     await FirebaseFirestore.instance.collection('vehicles').add(vehicleData); print("Veículo salvo!");
     if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_selectedMake??""} ${_selectedModel??""} registrado!'), backgroundColor: Colors.green)); Navigator.of(context).pop(); }
   } catch (error, s) { debugPrint("!!! ERRO ao salvar veículo: $error\n$s"); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar veículo: ${error.toString()}'), backgroundColor: errorColor)); }
   finally { if(mounted) setState(()=>_isLoading=false); }
 }

 // <<< Função _inputDecoration COMPLETA E CORRETA >>>
 InputDecoration _inputDecoration({ required String labelText, required IconData prefixIcon }) {
    // As cores agora são const, então não precisam ser locais
    return InputDecoration(
       labelText: labelText,
       labelStyle: GoogleFonts.poppins(textStyle:const TextStyle(color: labelColor, fontSize: 14)), // labelColor é const
       // Usar .withOpacity ainda não é const, mas o erro principal era das cores base
       // Vamos manter assim por enquanto, se o erro persistir, removemos opacidade daqui
       prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Icon(prefixIcon, color: iconColor.withOpacity(0.8), size: 20)),
       prefixIconConstraints: const BoxConstraints(minWidth:20, minHeight:20),
       filled: true,
       fillColor: inputFillColor, // inputFillColor é const
       contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
       // Usando cores const nas bordas
       border: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: inputBorderColor)), // inputBorderColor é const
       enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: inputBorderColor)), // inputBorderColor é const
       focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: secondaryColor, width: 1.5)), // secondaryColor é const
       errorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: errorColor)), // errorColor é const
       focusedErrorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: errorColor, width: 1.5)), // errorColor é const
       counterText: "",
       errorStyle: const TextStyle(color: errorColor, fontSize: 12) // errorColor é const
     );
 }

 // <<< Função _buildSelectionRow COMPLETA E CORRETA >>>
 Widget _buildSelectionRow({ required String label, String? value, VoidCallback? onPressed, required String selectText, String? placeholder}) {
    return InputDecorator(
      decoration: _inputDecoration( labelText: label, prefixIcon: Icons.category_outlined,),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded( child: Text( value ?? placeholder ?? 'Não selecionado', overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(textStyle:TextStyle( color: value!=null ? textColor : labelColor.withOpacity(0.7), fontSize: 16, fontWeight: value!=null?FontWeight.w500:FontWeight.normal )))), // textColor/labelColor são const
          TextButton( style: TextButton.styleFrom( foregroundColor: primaryColor, padding: const EdgeInsets.symmetric(horizontal: 8) ), onPressed: onPressed, child: Row( mainAxisSize: MainAxisSize.min, children: [ Text(selectText, style: GoogleFonts.poppins(fontSize: 14)), const SizedBox(width: 4), const Icon(Icons.search, size: 20) ] ))])); // primaryColor é const
 }

 @override
 Widget build(BuildContext context) {
   final theme = Theme.of(context);
   return Scaffold(
     appBar: AppBar(title: Text('Registrar Novo Veículo', style: GoogleFonts.rajdhani())),
     body: Center( child: ConstrainedBox( constraints: const BoxConstraints(maxWidth: 600),
       child: SingleChildScrollView( padding: const EdgeInsets.all(20.0),
         child: Form( key: _formKey,
           child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
               Text('Informe os dados do veículo', textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(color: labelColor)), // labelColor é const
               const SizedBox(height: 30),
               _buildSelectionRow( label: 'Marca*', value: _selectedMake, onPressed: _isLoading ? null : _selectMake, selectText: 'Selecionar').animate().fadeIn(delay: 100.ms), const SizedBox(height: 15),
               _buildSelectionRow( label: 'Modelo*', value: _selectedModel, onPressed: _isLoading || _selectedMake==null ? null : _selectModel, selectText: 'Selecionar', placeholder: _selectedMake==null?'Selecione marca':null).animate().fadeIn(delay: 200.ms), const SizedBox(height: 15),
               // TextFormFields agora não precisam ser const
               TextFormField( controller: _yearController, enabled: !_isLoading, decoration: _inputDecoration(labelText:'Ano*', prefixIcon: Icons.calendar_month_outlined), keyboardType: TextInputType.number, maxLength: 4, validator: (v){ if(v==null||v.isEmpty) return 'Obrigatório'; if(v.length!=4) return 'Inválido'; final yr = int.tryParse(v); if(yr==null || yr < 1950 || yr > DateTime.now().year + 1) return 'Inválido'; return null;}, ).animate().fadeIn(delay: 300.ms), const SizedBox(height: 15),
               TextFormField( controller: _plateController, enabled: !_isLoading, decoration: _inputDecoration(labelText:'Placa (Opcional)', prefixIcon: Icons.badge_outlined), textCapitalization:TextCapitalization.characters, maxLength: 7, ).animate().fadeIn(delay: 400.ms), const SizedBox(height: 15),
               DropdownButtonFormField<VehicleType>( value: _selectedType, decoration: _inputDecoration(labelText:'Tipo Combustível/Motor*', prefixIcon: Icons.speed_outlined), items: VehicleType.values.map((t)=>DropdownMenuItem<VehicleType>(value:t, child:Row(children:[Icon(t.icon,size:20,color:t.displayColor), const SizedBox(width:10), Text(t.displayName)]))).toList(), onChanged: _isLoading ? null : (v)=>setState(()=>_selectedType=v), validator: (v)=>v==null?'Selecione':null ).animate().fadeIn(delay: 500.ms), const SizedBox(height: 40),
               _isLoading
                  ? const Center(child: SpinKitWave(color: primaryColor, size: 30.0)) // primaryColor é const
                  : ElevatedButton.icon( // Não é const
                      onPressed: _submitForm,
                      icon: const Icon(Icons.save_alt_rounded), // OK
                      label: const Text('Salvar Veículo'), // OK
                      style: ElevatedButton.styleFrom( backgroundColor: primaryColor, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 15), textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold) ) // GoogleFonts não é const
                    ).animate().fadeIn(delay: 600.ms).scale(),
               const SizedBox(height: 20),
             ], ), ), ), ), ), );
 }
}