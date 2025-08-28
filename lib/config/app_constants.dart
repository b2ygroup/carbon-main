// lib/config/app_constants.dart

class AppConstants {
  // --- CHAVES DE API ---

  // Chave publicável do Stripe.
  // É seguro mantê-la aqui, pois é uma chave "publicável".
  static const String stripePublishableKey = 'pk_test_51RlGaY4Ie0XV5ATGx5aA75CGqomoet2FJPvHRTmit9VjUW6TL7f30Wx1uriWfloIREMlf4LZFry5p5zVAKDEN3Ic00urqBvXdh';

  // Chave da API do Google Cloud Vision para o serviço de OCR.
  static const String googleVisionApiKey = "AIzaSyDy_WBvHCk13hGIfqEP_VPEDu436PvMF0E";


  // --- IDs DE PRODUTOS E PREÇOS (STRIPE) ---

  static const String carbonOffsetPriceId = "price_1P8g8Y4Ie0XV5ATGXRL1Vv8H";
  static const String carbonOffsetPriceIdAlternative = "price_1RnIIc4Ie0XV5ATGhfVx9F8R";


  // --- PARÂMETROS DE NEGÓCIO ---

  static const double brlPerKgCo2 = 0.25;


  // --- URLs DE SERVIÇOS (CLOUD FUNCTIONS) ---

  static const String getCityFromCoordinatesUrl = 'https://getcityfromcoordinates-ki3ven47oa-uc.a.run.app';
  static const String getDirectionsUrl = 'https://getdirections-ki3ven47oa-uc.a.run.app';
  static const String getPlaceAutocompleteUrl = 'https://getplaceautocomplete-ki3ven47oa-uc.a.run.app';
  static const String googleVisionApiUrl = 'https://vision.googleapis.com/v1/images:annotate';


  // --- INFORMAÇÕES DE CONTATO E SOBRE ---

  static const String contactEmail = 'b2ylion@gmail.com';
  static const String contactPhone = '+5511965520979';
  static const String contactPhoneUrl = 'https://wa.me/5511965520979';
  static const String companyWebsiteUrl = 'https://group-tau.vercel.app/';
  static const String manualPixKey = '334.021.198-11';
}