// =================================================================
// ARQUIVO COMPLETO: functions/index.js
// Contém as funções de API do Google e a função de Checkout do Stripe
// =================================================================

// Imports do Firebase Functions e de bibliotecas externas
import {onRequest} from "firebase-functions/v2/https";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";
import {logger} from "firebase-functions";
import fetch from "node-fetch";
import corsLib from "cors";
import admin from "firebase-admin";
import Stripe from "stripe";

// Inicializa o Firebase Admin SDK (necessário para funções que interagem com o Firebase)
admin.initializeApp();

// --- Configuração de CORS para as funções HTTP ---
const allowedOrigins = [
  "https://carbono-tracker-app.web.app", // Seu domínio de produção
  "http://localhost:58265", 
  "http://localhost:58265",             // Porta de desenvolvimento local
  "http://localhost:63284",             // Porta que causou o erro
  "http://localhost:50709",             // Outra porta dos seus prints            // Sua porta de desenvolvimento local
  // Adicione outras portas ou domínios de teste se necessário
];

const corsOptions = {
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      logger.warn(`CORS: Origem não permitida pela configuração: ${origin}. Permitidas: ${allowedOrigins.join(", ")}`);
      callback(new Error(`A origem ${origin} não é permitida pelo CORS.`));
    }
  },
};
const cors = corsLib(corsOptions);

// --- Configurações Globais das Funções ---
setGlobalOptions({region: "us-central1"}); // Define a região padrão para as funções HTTP

// --- Carregamento de Chaves e Segredos de Ambiente ---

// Chave da API do Google Maps
const GOOGLE_API_KEY = process.env.GOOGLE_API_KEY_FROM_ENV;
if (!GOOGLE_API_KEY) {
  logger.error(
      'CRÍTICO: A variável de ambiente GOOGLE_API_KEY_FROM_ENV não foi encontrada.'
  );
} else {
  logger.info("Variável de ambiente GOOGLE_API_KEY_FROM_ENV carregada com sucesso.");
}

// Chave Secreta do Stripe
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY;
if (!STRIPE_SECRET_KEY) {
  logger.error(
    "CRÍTICO: A variável de ambiente STRIPE_SECRET_KEY não foi encontrada."
  );
}

// --- Inicialização de Clientes de API ---
const stripe = new Stripe(STRIPE_SECRET_KEY, {
    apiVersion: "2024-06-20", // Use a versão mais recente da API do Stripe
});


// =================================================================
// INÍCIO DAS SUAS FUNÇÕES EXISTENTES (GOOGLE MAPS)
// =================================================================

/**
 * Função HTTP para autocompletar nomes de cidades.
 */
export const getPlaceAutocomplete = onRequest(async (request, response) => {
  cors(request, response, async () => {
    if (!GOOGLE_API_KEY) {
      logger.error('getPlaceAutocomplete: Chave de API não definida no ambiente.');
      response.status(500).send({error: "A chave de API não está configurada no servidor."});
      return;
    }

    const inputText = request.query.input;
    if (!inputText) {
      response.status(400).send({error: "Parâmetro 'input' ausente na requisição."});
      return;
    }

    const apiUrl = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(inputText)}&types=(cities)&language=pt-BR&components=country:BR&key=${GOOGLE_API_KEY}`;

    try {
      const apiResponse = await fetch(apiUrl);
      const apiData = await apiResponse.json();

      if (apiData.status === "OK") {
        response.status(200).send(apiData);
      } else {
        logger.error(
            "getPlaceAutocomplete - Erro na API do Google Places:",
            apiData.status,
            apiData.error_message || "Nenhuma mensagem de erro da API."
        );
        response.status(apiData.status === "REQUEST_DENIED" ? 403 : 500)
            .send({
              error: "Erro na API do Google Places",
              details: apiData.error_message || apiData.status,
            });
      }
    } catch (error) {
      logger.error("getPlaceAutocomplete - Exceção ao chamar a API:", error);
      response.status(500).send({error: "Falha ao chamar a API do Google Places."});
    }
  });
});

/**
 * Função HTTP para obter direções e distância entre dois pontos.
 */
export const getDirections = onRequest(async (request, response) => {
  cors(request, response, async () => {
    if (!GOOGLE_API_KEY) {
      logger.error("getDirections: Chave de API não definida no ambiente.");
      response.status(500).send({error: "A chave de API não está configurada no servidor."});
      return;
    }
    const origin = request.query.origin;
    const destination = request.query.destination;

    if (!origin || !destination) {
      response.status(400).send({error: "Parâmetros 'origin' ou 'destination' ausentes."});
      return;
    }

    const apiUrl = `https://maps.googleapis.com/maps/api/directions/json?origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&key=${GOOGLE_API_KEY}&language=pt-BR`;
    try {
      const apiResponse = await fetch(apiUrl);
      const apiData = await apiResponse.json();

      if (apiData.status === "OK") {
        response.status(200).send(apiData);
      } else {
        logger.error(
            "getDirections - Erro na API do Google Directions:",
            apiData.status,
            apiData.error_message || "Nenhuma mensagem de erro da API."
        );
        response.status(apiData.status === "REQUEST_DENIED" ? 403 : 500)
            .send({
              error: "Erro na API do Google Directions",
              details: apiData.error_message || apiData.status,
            });
      }
    } catch (error) {
      logger.error("getDirections - Exceção ao chamar a API:", error);
      response.status(500).send({error: "Falha ao chamar a API do Google Directions."});
    }
  });
});

/**
 * Função HTTP para obter o nome da cidade a partir de coordenadas.
 */
export const getCityFromCoordinates = onRequest(async (request, response) => {
  cors(request, response, async () => {
    if (!GOOGLE_API_KEY) {
      logger.error("getCityFromCoordinates: Chave de API não definida no ambiente.");
      response.status(500).send({error: "A chave de API não está configurada no servidor."});
      return;
    }
    const lat = request.query.lat;
    const lng = request.query.lng;

    if (!lat || !lng) {
      response.status(400).send({error: "Parâmetros 'lat' ou 'lng' ausentes."});
      return;
    }

    const apiUrl = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${GOOGLE_API_KEY}&language=pt-BR&result_type=locality`;
    try {
      const apiResponse = await fetch(apiUrl);
      const apiData = await apiResponse.json();
      if (apiData.status === "OK") {
        response.status(200).send(apiData);
      } else {
        logger.error(
            "getCityFromCoordinates - Erro na API do Google Geocoding:",
            apiData.status,
            apiData.error_message || "Nenhuma mensagem de erro da API."
        );
        response.status(apiData.status === "REQUEST_DENIED" ? 403 : 500)
            .send({
              error: "Erro na API do Google Geocoding",
              details: apiData.error_message || apiData.status,
            });
      }
    } catch (error) {
      logger.error("getCityFromCoordinates - Exceção ao chamar a API:", error);
      response.status(500).send({error: "Falha ao chamar a API do Google Geocoding."});
    }
  });
});

// =================================================================
// FIM DAS SUAS FUNÇÕES EXISTENTES (GOOGLE MAPS)
// =================================================================


// =================================================================
// INÍCIO DA NOVA FUNÇÃO (STRIPE CHECKOUT)
// =================================================================

/**
 * Função Callable para criar uma sessão de checkout do Stripe.
 * É chamada diretamente pelo app Flutter.
 */
export const createStripeCheckout = onCall({
  region: "southamerica-east1", // Região consistente com o app e Firestore
  secrets: ["STRIPE_SECRET_KEY"], // Permite que a função acesse o segredo
}, async (request) => {
    // Valida se o usuário está autenticado
    if (!request.auth) {
      logger.warn("createStripeCheckout: Chamada não autenticada.");
      throw new HttpsError(
        "unauthenticated",
        "Você precisa estar logado para fazer uma compra."
      );
    }

    const userId = request.auth.uid;
    const priceId = request.data.priceId;

    if (!priceId) {
      logger.error(`createStripeCheckout: Chamada do usuário ${userId} sem priceId.`);
      throw new HttpsError(
        "invalid-argument",
        "O 'priceId' do pacote não foi fornecido."
      );
    }

    try {
      // Domínio base do seu app web.
      const appBaseUrl = "https://carbono-tracker-app.web.app";

      // Cria a sessão de checkout no Stripe
      const session = await stripe.checkout.sessions.create({
        payment_method_types: ["card"],
        mode: "payment",
        success_url: `${appBaseUrl}/payment-success?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${appBaseUrl}/payment-cancel`,
        line_items: [{
          price: priceId,
          quantity: 1,
        }],
        client_reference_id: userId,
        metadata: {
          firebaseUID: userId,
        },
      });

      logger.info(`Sessão de checkout criada para o usuário ${userId}.`);

      // Retorna a URL da sessão para o aplicativo Flutter
      return {
        url: session.url,
      };

    } catch (error) {
      logger.error(`Erro ao criar a sessão de checkout para o usuário ${userId}:`, error);
      throw new HttpsError(
        "internal",
        "Não foi possível criar a sessão de pagamento."
      );
    }
});