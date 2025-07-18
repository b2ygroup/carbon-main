// lib/screens/admin_screen.dart (VERSÃO REALMENTE COMPLETA)

import 'dart:convert';
import 'package:carbon/models/vehicle_type_enum.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  bool _isProcessing = false;
  String _processingMessage = 'Processando...';

  /// Importa uma lista de modelos de um arquivo JSON, ignorando duplicatas.
  Future<void> _importVehiclesFromJson() async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Importando...';
    });
    try {
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
        final key = "${data['make']}-${data['model']}".toLowerCase().trim();
        existingKeys.add(key);
      }

      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('vehicle_models');
      int newCount = 0;
      int skippedCount = 0;
      
      for (final vehicle in vehiclesToImport) {
        if (vehicle is Map<String, dynamic>) {
          final key = "${vehicle['make']}-${vehicle['model']}".toLowerCase().trim();
          
          if (!existingKeys.contains(key)) {
            final docRef = collection.doc();
            vehicle.remove('year'); // Garante que o campo 'year' não seja salvo
            batch.set(docRef, vehicle);
            newCount++;
            existingKeys.add(key);
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
          content: Text("$newCount modelos novos importados. $skippedCount duplicados foram ignorados."),
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
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Exclui um modelo de veículo do banco de dados após confirmação.
  Future<void> _deleteVehicle(String docId, String vehicleName) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E2E32),
        title: const Text('Confirmar Exclusão', style: TextStyle(color: Colors.white)),
        content: Text('Você tem certeza que deseja excluir o modelo "$vehicleName"? Esta ação não pode ser desfeita.', style: TextStyle(color: Colors.grey[300])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
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
            SnackBar(content: Text('Erro ao excluir modelo: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }
  
  /// Exibe um diálogo para adicionar ou editar um modelo de veículo (sem o campo 'ano').
  Future<void> _showVehicleModelDialog({DocumentSnapshot? existingDoc}) async {
    final formKey = GlobalKey<FormState>();
    final makeController = TextEditingController();
    final modelController = TextEditingController();
    VehicleType? selectedType;

    if (existingDoc != null) {
      final data = existingDoc.data() as Map<String, dynamic>;
      makeController.text = data['make'] ?? '';
      modelController.text = data['model'] ?? '';
      selectedType = vehicleTypeFromString(data['type']);
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2E2E32),
              title: Text(
                existingDoc == null ? 'Adicionar Novo Modelo' : 'Editar Modelo',
                style: GoogleFonts.orbitron(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: makeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Marca', labelStyle: TextStyle(color: Colors.grey)),
                        validator: (value) => (value == null || value.isEmpty) ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: modelController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Modelo', labelStyle: TextStyle(color: Colors.grey)),
                        validator: (value) => (value == null || value.isEmpty) ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<VehicleType>(
                        value: selectedType,
                        dropdownColor: const Color(0xFF2E2E32),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Tipo de Veículo', labelStyle: TextStyle(color: Colors.grey)),
                        items: VehicleType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.displayName, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setDialogState(() {
                            selectedType = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Selecione um tipo' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Salvar'),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final vehicleData = {
                        'make': makeController.text.trim(),
                        'model': modelController.text.trim(),
                        'type': selectedType!.name,
                        'lastUpdate': FieldValue.serverTimestamp(),
                      };

                      try {
                        if (existingDoc == null) {
                          vehicleData['createdAt'] = FieldValue.serverTimestamp();
                          await FirebaseFirestore.instance.collection('vehicle_models').add(vehicleData);
                        } else {
                          await FirebaseFirestore.instance.collection('vehicle_models').doc(existingDoc.id).update(vehicleData);
                        }
                        if(mounted) Navigator.of(context).pop();
                      } catch (e) {
                        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red));
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Chama a Cloud Function 'cleanupDuplicateVehicleModels' para limpar o banco de dados.
  Future<void> _runCleanup() async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Verificando duplicatas...';
    });
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final HttpsCallable callable = functions.httpsCallable('cleanupDuplicateVehicleModels');
      final result = await callable.call();
      final message = result.data['message'] ?? "Operação concluída.";
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ));
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erro: ${e.message}"),
          backgroundColor: Colors.redAccent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Um erro inesperado ocorreu: $e"),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text('Painel Administrativo', style: GoogleFonts.orbitron(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A1F2C),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : () => _showVehicleModelDialog(),
        label: const Text('Adicionar Modelo'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.cyanAccent[400],
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Gerenciamento de Dados',
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 30),
            if (_isProcessing)
              Center(child: Column(
                children: [
                  const SpinKitFadingCube(color: Colors.cyanAccent, size: 40.0),
                  const SizedBox(height: 15),
                  Text(_processingMessage, style: const TextStyle(color: Colors.cyanAccent)),
                ],
              ))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
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
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('Verificar e Limpar Duplicatas'),
                    onPressed: _isProcessing ? null : _runCleanup,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orangeAccent,
                      side: const BorderSide(color: Colors.orangeAccent),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 12),
            Text(
              'A limpeza remove itens com mesma marca e modelo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.yellow[700]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Ferramenta de Admin (Uso Único)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.security),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700]),
                    onPressed: () async {
                      final userEmail = FirebaseAuth.instance.currentUser?.email;
                      if (userEmail == null) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Não foi possível obter o e-mail do usuário.")),
                        );
                        return;
                      }
                      try {
                        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
                        final callable = functions.httpsCallable('grantAdminRole');
                        final result = await callable.call({'email': userEmail});
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.data['message']),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Erro ao se tornar admin: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    label: const Text('Tornar-me Admin'),
                  ),
                   const SizedBox(height: 8),
                  Text(
                    'Clique, faça logout e login novamente para aplicar a permissão.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),

            const Divider(height: 40, color: Colors.white24),

            Text(
              'Modelos Cadastrados',
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('vehicle_models').orderBy('make').orderBy('model').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Erro: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Nenhum modelo de veículo encontrado.", style: TextStyle(color: Colors.white)));
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
                        title: Text(vehicleName, style: const TextStyle(color: Colors.white)),
                        subtitle: Text("Tipo: ${vehicleType?.displayName ?? data['type'] ?? 'N/A'}", style: TextStyle(color: Colors.grey[400])),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                              onPressed: () => _showVehicleModelDialog(existingDoc: doc),
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
             const SizedBox(height: 80), 
          ],
        ),
      ),
    );
  }
}