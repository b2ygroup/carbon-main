// lib/screens/signup/vehicle_registration_signup_screen.dart (COMPLETO E CORRIGIDO)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:carbon/main.dart'; // Para o AuthWrapper

enum RegistrationStep { categorySelection, detailsForm }

class VehicleRegistrationScreenForSignup extends StatefulWidget {
  // <<< ALTERAÇÃO 1: Adicionado o parâmetro user, que é obrigatório >>>
  final User user;
  
  const VehicleRegistrationScreenForSignup({super.key, required this.user});

  @override
  State<VehicleRegistrationScreenForSignup> createState() => _VehicleRegistrationScreenForSignupState();
}

class _VehicleRegistrationScreenForSignupState extends State<VehicleRegistrationScreenForSignup> {
  RegistrationStep _currentStep = RegistrationStep.categorySelection;
  String? _selectedCategory;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  String? _selectedMake;
  String? _selectedModelId;
  final _plateController = TextEditingController();
  final _nicknameController = TextEditingController();
  List<String> _makes = [];
  List<Map<String, dynamic>> _models = [];

  static const Color primaryColor = Color(0xFF00BFFF);
  static final Color errorColor = Colors.redAccent[100]!;
  static final Color inputFillColor = Colors.white.withAlpha(13);
  static final Color labelColor = Colors.grey[400]!;
  static const Color textColor = Colors.white;

  @override
  void dispose() {
    _plateController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _fetchMakes(String category) async {
    setState(() {
      _isLoading = true;
      _makes = [];
      _selectedMake = null;
      _models = [];
      _selectedModelId = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vehicle_models')
          .where('category', isEqualTo: category)
          .get();
      
      final makes = snapshot.docs.map((doc) => doc.data()['make'] as String).toSet().toList();
      makes.sort();
      
      if (mounted) {
        setState(() {
          _makes = makes;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar marcas: $e'), backgroundColor: errorColor));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchModels(String make) async {
    setState(() {
      _isLoading = true;
      _models = [];
      _selectedModelId = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vehicle_models')
          .where('category', isEqualTo: _selectedCategory)
          .where('make', isEqualTo: make)
          .orderBy('model')
          .orderBy('year')
          .get();

      final models = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': '${data['model']} ${data['version']} (${data['year']})'
        };
      }).toList();
      
      if (mounted) {
        setState(() {
          _models = models;
        });
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar modelos: $e'), backgroundColor: errorColor));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _submitForm() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_selectedModelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione todos os campos obrigatórios.'), backgroundColor: Colors.orangeAccent)
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // <<< ALTERAÇÃO 2: Usando o user passado via widget, garantido de não ser nulo >>>
    final user = widget.user;

    try {
      final vehicleData = {
        'userId': user.uid,
        'modelId': _selectedModelId,
        'licensePlate': _plateController.text.trim().toUpperCase(),
        'nickname': _nicknameController.text.trim(),
        'createdAt': FieldValue.serverTimestamp()
      };
      
      await FirebaseFirestore.instance.collection('vehicles').add(vehicleData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Veículo registrado com sucesso! Bem-vindo(a)!'),
            backgroundColor: Colors.green));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (ctx) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (error) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao salvar veículo: ${error.toString()}'),
            backgroundColor: errorColor));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cadastre Seu Veículo', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.grey[900],
        automaticallyImplyLeading: false, 
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: AnimatedSwitcher(
            duration: 300.ms,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: _currentStep == RegistrationStep.categorySelection
                ? _buildCategorySelection()
                : _buildDetailsForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Padding(
      key: const ValueKey('step0'),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Selecione a categoria do seu veículo',
              textAlign: TextAlign.center,
              style: GoogleFonts.orbitron(fontSize: 22, color: textColor)),
          const SizedBox(height: 30),
          _CategoryCard(label: 'Carro ou SUV', icon: Icons.directions_car_filled, onTap: () => _onCategorySelected('car')),
          _CategoryCard(label: 'Motocicleta', icon: Icons.two_wheeler, onTap: () => _onCategorySelected('motorcycle')),
          _CategoryCard(label: 'Ônibus', icon: Icons.directions_bus, onTap: () => _onCategorySelected('bus')),
          _CategoryCard(label: 'Caminhão', icon: Icons.local_shipping, onTap: () => _onCategorySelected('truck')),
        ].animate(interval: 100.ms).fadeIn().slideY(begin: 0.5),
      ),
    );
  }

  void _onCategorySelected(String category) {
    _fetchMakes(category);
    setState(() {
      _selectedCategory = category;
      _currentStep = RegistrationStep.detailsForm;
    });
  }

  Widget _buildDetailsForm() {
    return SingleChildScrollView(
      key: const ValueKey('step1'),
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _currentStep = RegistrationStep.categorySelection),
                icon: const Icon(Icons.arrow_back_ios, size: 16),
                label: const Text('Mudar Categoria'),
                style: TextButton.styleFrom(foregroundColor: primaryColor),
              ),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: _selectedMake,
              hint: _isLoading ? const Text('Carregando marcas...') : const Text('Selecione a Marca *'),
              isExpanded: true,
              items: _makes.map((make) => DropdownMenuItem(value: make, child: Text(make))).toList(),
              onChanged: _isLoading ? null : (value) {
                if (value != null) {
                  setState(() {
                    _selectedMake = value;
                    _selectedModelId = null;
                    _models = [];
                  });
                  _fetchModels(value);
                }
              },
              decoration: _inputDecoration(prefixIcon: Icons.factory),
              dropdownColor: Colors.grey[850],
              style: const TextStyle(color: textColor, fontSize: 16),
              validator: (v) => v == null ? 'Selecione uma marca' : null,
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: _selectedModelId,
              hint: Text(_selectedMake == null ? 'Selecione a marca primeiro' : 'Selecione o Modelo *'),
              isExpanded: true,
              items: _models.map<DropdownMenuItem<String>>((model) {
                return DropdownMenuItem<String>(
                  value: model['id'],
                  child: Text(model['name'], overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: _isLoading ? null : (value) => setState(() => _selectedModelId = value),
              decoration: _inputDecoration(prefixIcon: Icons.rv_hookup),
              dropdownColor: Colors.grey[850],
              style: const TextStyle(color: textColor, fontSize: 16),
              validator: (v) => v == null ? 'Selecione um modelo' : null,
            ),
            const SizedBox(height: 15),
            
            TextFormField(
              controller: _plateController,
              enabled: !_isLoading,
              decoration: _inputDecoration(prefixIcon: Icons.badge_outlined, hintText: 'Placa *'),
              textCapitalization: TextCapitalization.characters,
              maxLength: 7,
              validator: (v) => (v == null || v.trim().length < 7) ? 'Placa inválida (7 caracteres)' : null,
            ),
            const SizedBox(height: 15),
            
            TextFormField(
              controller: _nicknameController,
              enabled: !_isLoading,
              decoration: _inputDecoration(prefixIcon: Icons.label_important_outline, hintText: 'Apelido do Veículo (Opcional)'),
            ),
            const SizedBox(height: 40),

            _isLoading
                ? const Center(child: SpinKitWave(color: primaryColor, size: 30.0))
                : ElevatedButton.icon(
                    onPressed: _submitForm,
                    icon: const Icon(Icons.app_registration),
                    label: const Text('Concluir Cadastro'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required IconData prefixIcon, String? hintText}) {
    return InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(textStyle: TextStyle(color: labelColor, fontSize: 16)),
        prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Icon(prefixIcon, color: primaryColor.withAlpha(204), size: 20)),
        filled: true,
        fillColor: inputFillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: errorColor)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: errorColor, width: 1.5)),
        counterText: "",
        errorStyle: TextStyle(color: errorColor, fontSize: 12)
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryCard({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[850]!.withAlpha(128),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Icon(icon, size: 30, color: _VehicleRegistrationScreenForSignupState.primaryColor),
              const SizedBox(width: 20),
              Text(label, style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}