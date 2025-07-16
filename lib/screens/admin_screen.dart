// lib/screens/admin_screen.dart (CORREÇÃO DEFINITIVA DE INICIALIZAÇÃO)
import 'dart:convert';
import 'package:carbon/firebase_options.dart';
import 'package:carbon/models/vehicle_type_enum.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isImporting = false;

  Future<void> _importVehiclesFromJson() async {
    setState(() => _isImporting = true);
    try {
      // ▼▼▼ GARANTIA DE INICIALIZAÇÃO CORRETA E SEGURA ▼▼▼
      // Verifica se o Firebase já foi inicializado para evitar erros.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        throw Exception("Nenhum arquivo selecionado ou o arquivo está vazio.");
      }

      final fileBytes = result.files.single.bytes!;
      final jsonString = utf8.decode(fileBytes);
      final List<dynamic> vehiclesToImport = json.decode(jsonString);

      if (vehiclesToImport.isEmpty) {
        throw Exception("O arquivo JSON está vazio ou em formato inválido.");
      }
      
      final existingVehiclesSnapshot = await FirebaseFirestore.instance.collection('vehicle_models').get();
      final existingKeys = <String>{};
      for (final doc in existingVehiclesSnapshot.docs) {
        final data = doc.data();
        final key = "${data['make']}-${data['model']}-${data['year']}".toLowerCase();
        existingKeys.add(key);
      }

      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('vehicle_models');
      int newCount = 0;
      int skippedCount = 0;
      
      for (final vehicle in vehiclesToImport) {
        if (vehicle is Map<String, dynamic>) {
          final key = "${vehicle['make']}-${vehicle['model']}-${vehicle['year']}".toLowerCase();
          
          if (!existingKeys.contains(key)) {
            final docRef = collection.doc();
            batch.set(docRef, vehicle);
            newCount++;
          } else {
            skippedCount++;
          }
        }
      }

      if (newCount == 0) {
        throw Exception("Nenhum veículo novo para importar. $skippedCount itens já existem.");
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("$newCount veículos novos importados. $skippedCount duplicados foram ignorados."),
          backgroundColor: Colors.green,
        ));
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erro na importação: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _deleteVehicle(String docId, String vehicleName) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E2E32),
        title: const Text('Confirmar Exclusão'),
        content: Text('Você tem certeza que deseja excluir o modelo "$vehicleName"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('vehicle_models').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$vehicleName" excluído com sucesso.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir veículo: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Painel Administrativo', style: GoogleFonts.orbitron(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A1F2C),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Gerenciamento de Dados',
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 30),
            _isImporting 
              ? const Center(child: SpinKitFadingCube(color: Colors.cyanAccent, size: 40.0))
              : ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar Modelos (JSON)'),
                  onPressed: _importVehiclesFromJson,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent[400],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
            const SizedBox(height: 12),
            Text(
              'Selecione o arquivo ".json" do seu computador para adicionar a lista de veículos ao banco de dados.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const Divider(height: 40, color: Colors.white24),

            Text(
              'Modelos Cadastrados',
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('vehicle_models').orderBy('make').orderBy('model').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                   if (snapshot.error.toString().contains('requires an index')) {
                     return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "O banco de dados precisa criar um índice para esta consulta. Isso pode levar alguns minutos. Por favor, aguarde e atualize a página.\n\nDetalhes: ${snapshot.error}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                      ),
                    );
                  }
                  return Center(child: Text("Erro ao carregar veículos: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Nenhum modelo de veículo encontrado."));
                }

                final vehicleDocs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: vehicleDocs.length,
                  itemBuilder: (context, index) {
                    final doc = vehicleDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final vehicleType = vehicleTypeFromString(data['type']);
                    final vehicleName = "${data['make'] ?? ''} ${data['model'] ?? ''}";

                    return Card(
                      color: const Color(0xFF2E2E32),
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      child: ListTile(
                        leading: Icon(vehicleType?.icon ?? Icons.help_outline, color: vehicleType?.displayColor ?? Colors.grey),
                        title: Text("$vehicleName (${data['year'] ?? ''})"),
                        subtitle: Text("Tipo: ${vehicleType?.displayName ?? data['type'] ?? 'N/A'}", style: TextStyle(color: Colors.grey[400])),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                              onPressed: () { /* Lógica de Editar virá aqui */ },
                              tooltip: 'Editar',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => _deleteVehicle(doc.id, vehicleName),
                              tooltip: 'Excluir',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}