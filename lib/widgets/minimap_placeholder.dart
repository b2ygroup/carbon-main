// lib/widgets/minimap_placeholder.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math; // Usaremos math.Random e math.pi

// Painter para o fundo do mapa fake com estilo de ruas (mantido da versão anterior)
class _StreetMapBackgroundPainter extends CustomPainter {
  final Color landColor;
  final Color roadColor;
  final Color buildingColor;
  final Color parkColor;

  _StreetMapBackgroundPainter({
    required this.landColor,
    required this.roadColor,
    required this.buildingColor,
    required this.parkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(12345);

    final paintLand = Paint()..color = landColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paintLand);

    final paintMainRoad = Paint()
      ..color = roadColor
      ..strokeWidth = size.width * 0.035 // Levemente mais grossas
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintSecondaryRoad = Paint()
      ..color = roadColor.withOpacity(0.8)
      ..strokeWidth = size.width * 0.02
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintPark = Paint()..color = parkColor;
    for (int i = 0; i < 2; i++) {
      final parkX = random.nextDouble() * size.width * 0.7;
      final parkY = random.nextDouble() * size.height * 0.7;
      final parkWidth = size.width * (random.nextDouble() * 0.2 + 0.15);
      final parkHeight = size.height * (random.nextDouble() * 0.2 + 0.15);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(parkX, parkY, parkWidth, parkHeight), const Radius.circular(5)),
          paintPark);
    }

    final paintBuilding = Paint()..color = buildingColor;
    int numBlocks = 7 + random.nextInt(4); // Ajustado para menos blocos com mapa menor
    for (int i = 0; i < numBlocks; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      double w = size.width * (random.nextDouble() * 0.12 + 0.06); // Blocos um pouco menores
      double h = size.height * (random.nextDouble() * 0.12 + 0.06);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(1.5)),
          paintBuilding);
    }

    List<Offset> mainRoadPoints = [];
    mainRoadPoints.add(Offset(0, size.height * (random.nextDouble() * 0.2 + 0.3)));
    mainRoadPoints.add(Offset(size.width * 0.4, size.height * (random.nextDouble() * 0.3 + 0.25)));
    mainRoadPoints.add(Offset(size.width * 0.7, size.height * (random.nextDouble() * 0.3 + 0.35)));
    mainRoadPoints.add(Offset(size.width, size.height * (random.nextDouble() * 0.2 + 0.4)));
    Path mainRoadPath1 = Path()..moveTo(mainRoadPoints[0].dx, mainRoadPoints[0].dy);
    for (int i = 1; i < mainRoadPoints.length; i++) {
      mainRoadPath1.lineTo(mainRoadPoints[i].dx, mainRoadPoints[i].dy);
    }
    canvas.drawPath(mainRoadPath1, paintMainRoad);

    mainRoadPoints.clear();
    mainRoadPoints.add(Offset(size.width * (random.nextDouble() * 0.2 + 0.4), 0));
    mainRoadPoints.add(Offset(size.width * (random.nextDouble() * 0.3 + 0.35), size.height * 0.45));
    mainRoadPoints.add(Offset(size.width * (random.nextDouble() * 0.3 + 0.25), size.height * 0.75));
    mainRoadPoints.add(Offset(size.width * (random.nextDouble() * 0.2 + 0.3), size.height));
    Path mainRoadPath2 = Path()..moveTo(mainRoadPoints[0].dx, mainRoadPoints[0].dy);
    for (int i = 1; i < mainRoadPoints.length; i++) {
      mainRoadPath2.lineTo(mainRoadPoints[i].dx, mainRoadPoints[i].dy);
    }
    canvas.drawPath(mainRoadPath2, paintMainRoad);

    int numSecondaryRoads = 4 + random.nextInt(3); // Ajustado para menos estradas secundárias
    for (int i = 0; i < numSecondaryRoads; i++) {
      double startX, startY, endX, endY;
      if (random.nextBool()) {
        startX = 0; endX = size.width;
        startY = endY = random.nextDouble() * size.height;
      } else {
        startY = 0; endY = size.height;
        startX = endX = random.nextDouble() * size.width;
      }
      if (random.nextBool()) { endX *= (random.nextDouble() * 0.4 + 0.6); }
      else { endY *= (random.nextDouble() * 0.4 + 0.6); }
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paintSecondaryRoad);
    }
  }

  @override
  bool shouldRepaint(covariant _StreetMapBackgroundPainter oldDelegate) {
    return oldDelegate.landColor != landColor ||
           oldDelegate.roadColor != roadColor ||
           oldDelegate.buildingColor != buildingColor ||
           oldDelegate.parkColor != parkColor;
  }
}

class MinimapPlaceholder extends StatelessWidget {
  final bool showUserMarker;

  const MinimapPlaceholder({
    super.key,
    this.showUserMarker = true,
  });

  List<Alignment> _generateRandomAlignments(int count, {int seed = 123, bool avoidCenter = false}) {
    final random = math.Random(seed);
    return List.generate(count, (index) {
      double dx, dy;
      do {
        dx = (random.nextDouble() * 1.8) - 0.9;
        dy = (random.nextDouble() * 1.8) - 0.9;
      } while (avoidCenter && (dx * dx + dy * dy < 0.2 * 0.2));
      return Alignment(dx, dy);
    });
  }

  Map<String, String> _generateFakeDataForStation(int index, Alignment alignment) {
    // Seed consistente baseada no índice e na posição do marcador
    final random = math.Random(index + alignment.x.hashCode + alignment.y.hashCode);
    
    List<String> nomes = ["Alpha Charge", "Beta Station", "Gamma Eletroposto", "Delta Energy", "Omega Grid", "Volt Point", "EcoCharge Hub"];
    List<String> precos = ["R\$ 2,35/kWh", "R\$ 2,60/kWh", "R\$ 2,45/kWh", "Grátis (Promocional)", "R\$ 2,90/kWh", "R\$ 2,20/kWh (Noturno)"];
    List<String> vagas = ["1/2 Vagas", "3/3 Vagas", "0/1 Vaga (Ocupado)", "2/4 Vagas", "Manutenção Programada", "1/1 Vaga"];
    List<String> potencias = ["50 kW DC", "22 kW AC", "7.4 kW AC", "150 kW DC (Ultra Rápido)", "11 kW AC", "43 kW AC"];
    List<String> bairros = ["Centro", "Jardins", "Distrito Industrial", "Vila Nova", "Parque Tecnológico", "Zona Sul", "Norte"];

    return {
      'Nome': nomes[random.nextInt(nomes.length)],
      'Endereço': 'Rua das Palmeiras, ${random.nextInt(1200) + 50}, Bairro ${bairros[random.nextInt(bairros.length)]}',
      'Preço': precos[random.nextInt(precos.length)],
      'Status': vagas[random.nextInt(vagas.length)],
      'Potência': potencias[random.nextInt(potencias.length)],
      'Horário': random.nextBool() ? '24 horas' : '08:00 - 22:00',
      'Plugues': random.nextBool() ? 'Tipo 2, CCS' : 'Tipo 2, CHAdeMO',
    };
  }

  void _showEletropostoDetails(BuildContext context, Map<String, String> data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context); // Usar o tema para consistência
        final bool isDarkTheme = theme.brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDarkTheme ? Colors.grey[850] : Colors.grey[100],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical:10),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          title: Text(
            data['Nome'] ?? 'Detalhes do Eletroposto',
            style: GoogleFonts.orbitron(
                color: isDarkTheme ? Colors.cyanAccent[100] : theme.primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: data.entries.map((entry) {
                if (entry.key == 'Nome') return const SizedBox.shrink(); // Não repetir nome
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDarkTheme ? Colors.white70 : Colors.black87,
                      ),
                      children: <TextSpan>[
                        TextSpan(text: '${entry.key}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: entry.value),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Navegar (Sim.)', style: TextStyle(color: isDarkTheme ? Colors.amberAccent[100] : Colors.orange[700])),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Simulando navegação para ${data['Nome']}...'), duration: const Duration(seconds: 2), backgroundColor: Colors.blueAccent,)
                );
              },
            ),
            TextButton(
              child: Text('Fechar', style: TextStyle(color: isDarkTheme ? Colors.cyanAccent[100] : theme.primaryColor)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const landColor = Color(0xFFECEFF1); // Cinza muito claro para terra (quase branco)
    const roadColor = Color(0xFFFFFFFF); // Estradas brancas
    const buildingColor = Color(0xFFCFD8DC); // Edifícios cinza claro azulado
    const parkColor = Color(0xFFC8E6C9); // Verde pastel bem claro para parques

    final eletropostoMarkerColor = Colors.teal[600]!; // Teal para melhor destaque
    final userMarkerColor = Colors.redAccent[400]!;

    // Ajustado para gerar menos estações devido ao tamanho menor do mapa
    final stationPositions = _generateRandomAlignments(math.Random().nextInt(3) + 4, seed: 42, avoidCenter: showUserMarker); // 4 a 6 estações

    int stationIndex = 0;

    return AspectRatio(
      aspectRatio: 16 / 7.5, // <<--- TORNANDO MAIS COMPACTO (MENOS ALTO)
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10), // Bordas um pouco menos arredondadas
          border: Border.all(color: Colors.blueGrey[200]!, width: 0.7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            CustomPaint(
              painter: _StreetMapBackgroundPainter(
                landColor: landColor,
                roadColor: roadColor,
                buildingColor: buildingColor,
                parkColor: parkColor,
              ),
              size: Size.infinite,
            ),
            ...stationPositions.map((alignment) {
              final currentIndex = stationIndex++;
              final stationData = _generateFakeDataForStation(currentIndex, alignment);
              return GestureDetector(
                onTap: () {
                  _showEletropostoDetails(context, stationData);
                },
                child: Align(
                  alignment: alignment,
                  child: Tooltip( // Adiciona um Tooltip básico
                    message: stationData['Nome'],
                    child: Icon(
                      Icons.ev_station_rounded, // Ícone arredondado
                      color: eletropostoMarkerColor,
                      size: 19, // Marcadores um pouco menores
                      shadows: [ Shadow( color: Colors.black.withOpacity(0.3), blurRadius: 2, offset: const Offset(0.5,0.5)) ],
                    ),
                  ),
                ),
              );
            }),
            if (showUserMarker)
              Align(
                alignment: Alignment.center,
                child: Icon(
                  Icons.person_pin_circle_rounded,
                  color: userMarkerColor,
                  size: 24,
                   shadows: [ Shadow( color: Colors.black.withOpacity(0.3), blurRadius: 2, offset: const Offset(0.5,0.5)) ],
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.03),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5))
                ),
                child: Text(
                  'Eletropostos (Simulado)',
                  style: GoogleFonts.poppins(
                    fontSize: 7,
                    color: Colors.black.withOpacity(0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}