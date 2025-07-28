// lib/config/app_config.dart

/// Classe para gerenciar configurações e chaves de API de forma segura.
class AppConfig {
  /// Chave da API do Google Cloud Vision, fornecida em tempo de compilação.
  ///
  /// Para usar, execute o app com:
  /// flutter run --dart-define=GOOGLE_API_KEY=SUA_CHAVE_AQUI
  static const googleApiKey = String.fromEnvironment(
    'GOOGLE_API_KEY',
    defaultValue: 'CHAVE_NAO_CONFIGURADA',
  );

  /// Verifica se a chave da API do Google foi configurada na compilação.
  static bool get isGoogleApiKeyConfigured =>
      googleApiKey != 'CHAVE_NAO_CONFIGURADA' && googleApiKey.isNotEmpty;
}