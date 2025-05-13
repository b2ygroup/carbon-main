// lib/services/carbon_service.dart (ARQUIVO COMPLETO COM getTripCalculationResults ADICIONADO)
import 'dart:math'; // Para usar max()
import 'package:carbon/models/vehicle_type_enum.dart'; // CONFIRME NOME PACOTE

class CarbonService {

  // --- Fatores de Emissão (kg CO2e / litro) - BASEADO NO SEU CÓDIGO ---
  static const double _kgCO2e_per_Liter_GasolineUser = 0.75 * 0.82 * 3.7; // ~2.2755
  static const double _kgCO2e_per_Liter_EthanolUser = 0.75 * 0.82 * 1.5;   // ~0.9225
  static const double _kgCO2e_per_Liter_DieselUser = 0.85 * 0.84 * 3.2;   // ~2.2848

  // --- Consumo Médio (km / litro) - PLACEHOLDERS (Considerar tornar dinâmico por veículo no futuro) ---
  static const double _km_per_Liter_GasolineC = 12.0;
  static const double _km_per_Liter_Ethanol = 8.0;
  static const double _km_per_Liter_DieselS10 = 15.0;
  // Média para Flex (pode ser impreciso, ideal seria saber a proporção usada)
  static const double _km_per_Liter_Flex_Avg = (_km_per_Liter_GasolineC + _km_per_Liter_Ethanol) / 2; // ~10.0

  // --- Fatores Elétrico/Híbrido ---
  static const double _gridEmissionFactorKgPerKWh = 0.07; // Exemplo Brasil (Baixo Fator)
  static const double _evConsumptionKWhPerKm = 0.15;    // Exemplo EV Médio

  // --- Preço Carbono (R$ / ton CO2e) - PLACEHOLDER ---
  static const double _carbonPricePerTon = 55.50; // Exemplo

  // --- Linha Base Média para EV (kg CO2e / km) - RECALCULADO ---
  // Representa a emissão média *evitada* por km ao usar EV em vez de um carro médio a combustão.
  static final double _avgBaselineKgCO2ePerKm = _calculateAverageBaseline();

  static double _calculateAverageBaseline() {
    // Emissão por KM para cada tipo
    const double gasKm = (_kgCO2e_per_Liter_GasolineUser / _km_per_Liter_GasolineC);   // ~0.1896
    const double ethKm = (_kgCO2e_per_Liter_EthanolUser / _km_per_Liter_Ethanol);   // ~0.1153
    const double dslKm = (_kgCO2e_per_Liter_DieselUser / _km_per_Liter_DieselS10);  // ~0.1523
    // Média simples dos tipos a combustão
    return (gasKm + ethKm + dslKm) / 3.0; // ~0.1524 kg CO2e / km
  }

  /// **Método Central:** Calcula o impacto LÍQUIDO de carbono (kg CO2e),
  /// onde negativo significa emissões evitadas e positivo significa emissões geradas.
  /// Também calcula o valor monetário associado e os créditos ganhos (se aplicável).
  Map<String, double> _calculateTripImpactInternal({
    required double distanceKm,
    required VehicleType vehicleType,
  }) {
    double carbonKg = 0; // Impacto líquido

    switch (vehicleType) {
      case VehicleType.gasoline:
        // Emissão = (Distância / Consumo) * Fator_Emissão_Litro
        carbonKg = (distanceKm / _km_per_Liter_GasolineC) * _kgCO2e_per_Liter_GasolineUser;
        break;
      case VehicleType.alcohol:
        carbonKg = (distanceKm / _km_per_Liter_Ethanol) * _kgCO2e_per_Liter_EthanolUser;
        break;
      case VehicleType.diesel:
        carbonKg = (distanceKm / _km_per_Liter_DieselS10) * _kgCO2e_per_Liter_DieselUser;
        break;
      case VehicleType.flex:
        // Usa média de consumo e média de fator de emissão (simplificação)
        double litersFlex = distanceKm / _km_per_Liter_Flex_Avg;
        double avgEmissionFactor = (_kgCO2e_per_Liter_GasolineUser + _kgCO2e_per_Liter_EthanolUser) / 2;
        carbonKg = litersFlex * avgEmissionFactor;
        break;
      case VehicleType.electric:
      case VehicleType.hybrid: // Trata híbrido como elétrico para cálculo de emissão evitada vs linha base
        // Emissões da Geração da Eletricidade Consumida
        double gridEmissionsKg = distanceKm * _evConsumptionKWhPerKm * _gridEmissionFactorKgPerKWh;
        // Emissões da Linha de Base (Média dos carros a combustão)
        double baselineEmissionsKg = distanceKm * _avgBaselineKgCO2ePerKm;
        // Impacto Líquido = Emissão_Real - Emissão_Linha_Base
        // Se for negativo, significa que as emissões reais (grid) foram MENORES que a linha de base.
        carbonKg = gridEmissionsKg - baselineEmissionsKg;
        break;
      // Adicione outros tipos de veículo se necessário (GNV, etc.)
      // default:
      //   carbonKg = 0; // Ou lançar um erro se o tipo for desconhecido
    }

    // --- Cálculos Derivados ---

    // CO2 Salvo: É o valor positivo do carbono evitado (quando carbonKg é negativo).
    // Usamos max(0, -carbonKg) para garantir que seja 0 se carbonKg for positivo.
    double co2SavedKg = max(0.0, -carbonKg);

    // Créditos: Concedidos com base no CO2 salvo (evitado).
    // Usamos a fórmula: CO2_Salvo * 0.1 (ajuste a taxa 0.1 conforme sua regra)
    double creditsEarned = co2SavedKg * 0.1;

    // Valor Monetário: Baseado no impacto líquido e preço por tonelada.
    // Se carbonKg é negativo (evitado), valor é positivo (crédito).
    // Se carbonKg é positivo (emitido), valor é negativo (custo teórico).
    double carbonTonnes = carbonKg / 1000.0;
    double carbonValue = -carbonTonnes * _carbonPricePerTon; // O sinal negativo inverte

    print('[CarbonService] Calculado: ${distanceKm.toStringAsFixed(1)} km, Tipo: ${vehicleType.name}, '
          'Impacto Líquido: ${carbonKg.toStringAsFixed(3)} kg CO2e, '
          'CO2 Salvo: ${co2SavedKg.toStringAsFixed(3)} kg, '
          'Créditos: ${creditsEarned.toStringAsFixed(4)}, '
          'Valor: R\$ ${carbonValue.toStringAsFixed(2)}');

    return {
      'carbonKg': carbonKg,          // Impacto líquido (+ emitido, - evitado)
      'co2SavedKg': co2SavedKg,      // CO2 efetivamente salvo (sempre >= 0)
      'creditsEarned': creditsEarned,  // Créditos ganhos (sempre >= 0)
      'carbonValue': carbonValue,      // Valor monetário (+ crédito, - custo)
    };
  }

  // --- Métodos Públicos para Interface com o App ---

  /// Calcula o CO2 SALVO (kg) para uma viagem.
  /// Retorna 0 se o veículo emitiu mais que a linha de base (ou for a combustão).
  /// Retorna o valor positivo das emissões evitadas para EV/Híbrido.
  Future<double> calculateCO2Saved(VehicleType vehicleType, double distanceKm) async {
    // Simula uma operação assíncrona se necessário no futuro, por enquanto é síncrono.
    await Future.delayed(Duration.zero); // Permite usar async/await
    final results = _calculateTripImpactInternal(distanceKm: distanceKm, vehicleType: vehicleType);
    return results['co2SavedKg'] ?? 0.0;
  }

  /// Calcula os CRÉDITOS ganhos para uma viagem.
  /// Créditos são baseados no CO2 salvo (emissões evitadas).
  Future<double> calculateCreditsEarned(VehicleType vehicleType, double distanceKm) async {
    // Simula uma operação assíncrona
    await Future.delayed(Duration.zero);
    final results = _calculateTripImpactInternal(distanceKm: distanceKm, vehicleType: vehicleType);
    return results['creditsEarned'] ?? 0.0;
  }

  // ****** MÉTODO ADICIONADO ******
  /// Calcula e retorna todos os resultados relevantes de impacto de uma viagem.
  /// Ideal para ser usado por widgets como o TripCalculatorWidget.
  /// Retorna um Map com: 'carbonKg', 'co2SavedKg', 'creditsEarned', 'carbonValue'.
  Future<Map<String, double>> getTripCalculationResults({
    required VehicleType vehicleType,
    required double distanceKm,
  }) async {
    // Simula uma operação assíncrona se necessário
    await Future.delayed(Duration.zero);
    // Chama o método interno que já faz todo o trabalho
    return _calculateTripImpactInternal(distanceKm: distanceKm, vehicleType: vehicleType);
  }
  // *******************************

} // Fim da classe CarbonService