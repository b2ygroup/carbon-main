// functions/index.js (VERSÃO FINAL, COMPLETA E SEM ABREVIAÇÕES)

import {onRequest} from "firebase-functions/v2/https";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";
import {logger} from "firebase-functions";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import fetch from "node-fetch";
import corsLib from "cors";
import admin from "firebase-admin";
import Stripe from "stripe";

// Inicializa o Firebase Admin SDK
admin.initializeApp();
const db = getFirestore();

// --- Configuração de CORS ---
const allowedOrigins = [
  "https://carbono-tracker-app.web.app",
  "http://localhost:58265",
  "http://localhost:63284",
  "http://localhost:50709",
  "http://localhost:62965",
];
const cors = corsLib({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error(`A origem ${origin} não é permitida pelo CORS.`));
    }
  },
});

// --- Configurações Globais ---
setGlobalOptions({region: "us-central1"});

// =================================================================
// FUNÇÕES HTTP (GOOGLE MAPS)
// =================================================================

const googleApiOptions = {
  secrets: ["GOOGLE_API_KEY_FROM_ENV"],
  cors: true,
};

export const getPlaceAutocomplete = onRequest(googleApiOptions, async (request, response) => {
  const GOOGLE_API_KEY = process.env.GOOGLE_API_KEY_FROM_ENV;
  if (!GOOGLE_API_KEY) {
    logger.error("getPlaceAutocomplete: Chave de API do Google não disponível.");
    response.status(500).send({error: "Configuração do servidor incompleta."});
    return;
  }
  const inputText = request.query.input;
  if (!inputText) {
    response.status(400).send({error: "Parâmetro 'input' ausente."});
    return;
  }
  const apiUrl = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(inputText)}&types=(cities)&language=pt-BR&components=country:BR&key=${GOOGLE_API_KEY}`;
  try {
    const apiResponse = await fetch(apiUrl);
    const apiData = await apiResponse.json();
    response.status(200).send(apiData);
  } catch (error) {
    logger.error("getPlaceAutocomplete - Exceção:", error);
    response.status(500).send({error: "Falha ao chamar a API do Google."});
  }
});

export const getDirections = onRequest(googleApiOptions, async (request, response) => {
  const GOOGLE_API_KEY = process.env.GOOGLE_API_KEY_FROM_ENV;
  if (!GOOGLE_API_KEY) {
    logger.error("getDirections: Chave de API do Google não disponível.");
    response.status(500).send({error: "Configuração do servidor incompleta."});
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
    response.status(200).send(apiData);
  } catch (error) {
    logger.error("getDirections - Exceção:", error);
    response.status(500).send({error: "Falha ao chamar a API do Google."});
  }
});

export const getCityFromCoordinates = onRequest(googleApiOptions, async (request, response) => {
  const GOOGLE_API_KEY = process.env.GOOGLE_API_KEY_FROM_ENV;
  if (!GOOGLE_API_KEY) {
    logger.error("getCityFromCoordinates: Chave de API do Google não disponível.");
    response.status(500).send({error: "Configuração do servidor incompleta."});
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
    response.status(200).send(apiData);
  } catch (error) {
    logger.error("getCityFromCoordinates - Exceção:", error);
    response.status(500).send({error: "Falha ao chamar a API do Google."});
  }
});

// =================================================================
// FUNÇÃO CALLABLE (STRIPE CHECKOUT - PIX, BOLETO, CARTÃO)
// =================================================================

export const createStripeCheckout = onCall({
  region: "southamerica-east1",
  secrets: ["STRIPE_SECRET_KEY"],
}, async (request) => {
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
    apiVersion: "2024-06-20",
  });
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Você precisa estar logado.");
  }
  const userId = request.auth.uid;
  const { priceId, co2ToOffset, costBRL } = request.data;

  if (!priceId) {
    throw new HttpsError("invalid-argument", "O 'priceId' não foi fornecido.");
  }

  try {
    const appBaseUrl = "https://carbono-tracker-app.web.app";
    
    const metadata = {
        firebaseUID: userId,
        priceId: priceId,
        ...(co2ToOffset && { co2ToOffset: co2ToOffset.toString() }),
        ...(costBRL && { costBRL: costBRL.toString() }),
    };

    const session = await stripe.checkout.sessions.create({
      payment_method_types: ["card", "pix", "boleto"],
      mode: "payment",
      success_url: `${appBaseUrl}/payment-success`,
      cancel_url: `${appBaseUrl}/payment-cancel`,
      line_items: [{
        price: priceId,
        quantity: 1
      }],
      client_reference_id: userId,
      metadata: metadata,
      expires_at: Math.floor(Date.now() / 1000) + (3600 * 24), // Expira em 1 dia
    });
    return {
      url: session.url
    };
  } catch (error) {
    logger.error(`Erro ao criar a sessão de checkout para ${userId}:`, error);
    throw new HttpsError("internal", "Não foi possível criar a sessão de pagamento.");
  }
});

// =================================================================
// FUNÇÃO DE WEBHOOK (STRIPE)
// =================================================================

export const stripeWebhook = onRequest({
  region: "southamerica-east1", // Executa na mesma região da função de checkout
  secrets: ["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET"]
}, async (request, response) => {
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let event;
  try {
    const signature = request.headers["stripe-signature"];
    event = stripe.webhooks.constructEvent(request.rawBody, signature, webhookSecret);
  } catch (err) {
    logger.error("⚠️ Erro na verificação da assinatura do Webhook:", err.message);
    response.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object;
    logger.info("✅ Sessão de checkout concluída:", session.id);
    const userId = session.metadata.firebaseUID;
    const priceId = session.metadata.priceId;

    if (!userId || !priceId) {
      logger.error("ERRO CRÍTICO: userId ou priceId não encontrados na metadata!", session.id);
      response.status(400).send("Dados da metadata ausentes.");
      return;
    }
    
    try {
        // ATENÇÃO: Substitua pelos IDs de Preço REAIS do seu painel Stripe
        const COIN_PACKAGE_BRONZE_ID = 'price_1RlIsQ4Ie0XV5ATGB0X5KtaM';
        const COIN_PACKAGE_SILVER_ID = 'price_1RlJGu4Ie0XV5ATGNDDcpsCJ';
        const COIN_PACKAGE_GOLD_ID = 'price_1RlT1z4Ie0XV5ATGBRhI9ATa';
        const CARBON_OFFSET_PRICE_ID = 'price_1P8g8Y4Ie0XV5ATGXRL1Vv8H';

        const userWalletRef = db.collection('wallets').doc(userId);

        switch (priceId) {
            case COIN_PACKAGE_BRONZE_ID:
                await userWalletRef.set({ balance: FieldValue.increment(100) }, { merge: true });
                logger.info(`+100 moedas adicionadas ao usuário ${userId}.`);
                break;
            case COIN_PACKAGE_SILVER_ID:
                await userWalletRef.set({ balance: FieldValue.increment(200) }, { merge: true });
                logger.info(`+200 moedas adicionadas ao usuário ${userId}.`);
                break;
            case COIN_PACKAGE_GOLD_ID:
                await userWalletRef.set({ balance: FieldValue.increment(300) }, { merge: true });
                logger.info(`+300 moedas adicionadas ao usuário ${userId}.`);
                break;
            case CARBON_OFFSET_PRICE_ID:
                const { co2ToOffset, costBRL } = session.metadata;
                await db.collection('carbon_offsets').add({
                    userId: userId,
                    offsetAmountKg: parseFloat(co2ToOffset),
                    costBRL: parseFloat(costBRL),
                    createdAt: FieldValue.serverTimestamp(),
                    stripeSessionId: session.id,
                });
                logger.info(`Compensação de ${co2ToOffset}kg de CO2 registrada para o usuário ${userId}.`);
                break;
            default:
                logger.warn(`Price ID não reconhecido: ${priceId} para a sessão ${session.id}. Nenhuma ação executada.`);
        }
        logger.info(`Lógica de negócio pós-pagamento executada com sucesso para o usuário: ${userId}`);

    } catch(error) {
        logger.error(`Erro ao executar a lógica de negócio para a sessão ${session.id}:`, error);
        response.status(500).send("Erro interno ao processar o pagamento.");
        return;
    }
  }

  response.status(200).send({
    received: true
  });
});

// =================================================================
// FUNÇÕES DE ADMINISTRAÇÃO
// =================================================================

export const cleanupDuplicateVehicleModels = onCall({
  secrets: [],
}, async (request) => {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Você precisa ser um administrador para executar esta operação."
    );
  }
  logger.info(`Iniciando limpeza por admin: ${request.auth.uid}`);
  const collectionRef = admin.firestore().collection("vehicle_models");
  const snapshot = await collectionRef.get();
  if (snapshot.empty) {
    return {
      deletedCount: 0,
      keptCount: 0,
      message: "Coleção de modelos está vazia."
    };
  }
  const uniqueKeys = new Map();
  const docsToDelete = [];
  snapshot.forEach((doc) => {
    const data = doc.data();
    const key = `${data.make}-${data.model}`.toLowerCase().trim();
    if (uniqueKeys.has(key)) {
      docsToDelete.push(doc.ref);
    } else {
      uniqueKeys.set(key, doc.id);
    }
  });
  if (docsToDelete.length === 0) {
    return {
      deletedCount: 0,
      keptCount: uniqueKeys.size,
      message: "Nenhuma duplicata encontrada."
    };
  }
  const batch = admin.firestore().batch();
  docsToDelete.forEach((ref) => batch.delete(ref));
  await batch.commit();
  const message = `Limpeza concluída. ${docsToDelete.length} duplicatas removidas.`;
  logger.info(message);
  return {
    deletedCount: docsToDelete.length,
    keptCount: uniqueKeys.size,
    message
  };
});

export const grantAdminRole = onCall(async (request) => {
  const userEmail = request.data.email;
  if (!userEmail) {
    throw new HttpsError("invalid-argument", "O e-mail não foi fornecido.");
  }
  try {
    const user = await admin.auth().getUserByEmail(userEmail);
    await admin.auth().setCustomUserClaims(user.uid, {
      admin: true
    });
    logger.info(`Sucesso! Credencial de admin concedida para ${userEmail} (UID: ${user.uid})`);
    return {
      message: `Sucesso! ${userEmail} agora é um administrador.`
    };
  } catch (error) {
    logger.error(`Erro ao conceder credencial de admin para ${userEmail}:`, error);
    throw new HttpsError("internal", `Erro ao processar a solicitação: ${error.message}`);
  }
});