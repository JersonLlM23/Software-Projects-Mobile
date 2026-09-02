const {initializeApp} = require("firebase-admin/app");
const {getDatabase} = require("firebase-admin/database");
const {getMessaging} = require("firebase-admin/messaging");
const {onValueCreated} = require("firebase-functions/v2/database");
const {setGlobalOptions} = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");

initializeApp();

setGlobalOptions({maxInstances: 10});

/**
 * Cloud Function v2 - onPrivateMessageCreated
 *
 * Escucha la creación de nuevos mensajes en el nodo:
 *   /conversations/{conversationId}/mensajes/{mensajeId}
 *
 * Al dispararse:
 * 1. Extrae autor, texto y autorUid del mensaje.
 * 2. Determina el receptorUid a partir del conversationId (uid1_uid2).
 * 3. Lee el fcmToken del receptor desde /users/{receptorUid}/fcmToken.
 * 4. Envía la notificación push programáticamente vía Firebase Admin SDK.
 */
exports.onPrivateMessageCreated = onValueCreated(
    {
      ref: "/conversations/{conversationId}/mensajes/{mensajeId}",
      region: "us-central1",
    },
    async (event) => {
      const conversationId = event.params.conversationId;
      const mensaje = event.data.val();

      if (!mensaje) {
        logger.warn("onPrivateMessageCreated: mensaje vacío, ignorado.");
        return null;
      }

      const {autor, texto, autorUid} = mensaje;

      if (!autorUid) {
        logger.warn("onPrivateMessageCreated: autorUid ausente, ignorado.");
        return null;
      }

      // Determinar el receptorUid desde conversationId = "uid1_uid2"
      // El separador garantizado es el primer guion bajo entre dos UIDs
      const underscoreIndex = conversationId.indexOf("_");
      if (underscoreIndex === -1) {
        logger.error(
            "onPrivateMessageCreated: conversationId inválido:",
            conversationId,
        );
        return null;
      }
      const uid1 = conversationId.substring(0, underscoreIndex);
      const uid2 = conversationId.substring(underscoreIndex + 1);

      // El receptor es el que NO envió el mensaje
      const receptorUid = autorUid === uid1 ? uid2 : uid1;

      logger.info(
          `Mensaje de ${autor} (${autorUid}) → receptor: ${receptorUid}`,
      );

      // Leer el token FCM del receptor desde Realtime Database
      const db = getDatabase();
      const tokenRef = db.ref(
          `users/${receptorUid}/fcmToken`,
      );
      const tokenSnapshot = await tokenRef.get();

      if (!tokenSnapshot.exists() || !tokenSnapshot.val()) {
        logger.info(
            `Sin token FCM para receptorUid=${receptorUid}, ` +
            "notificación omitida.",
        );
        return null;
      }

      const fcmToken = tokenSnapshot.val();

      // Construir y enviar la notificación push con Firebase Admin SDK
      const messagePayload = {
        token: fcmToken,
        notification: {
          title: `💬 Nuevo mensaje de ${autor}`,
          body: texto || "(mensaje vacío)",
        },
        data: {
          conversationId: conversationId,
          receptor: receptorUid,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "chatcito_messages",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      try {
        const response = await getMessaging().send(messagePayload);
        logger.info(
            "Notificación FCM enviada exitosamente:",
            response,
        );
      } catch (error) {
        logger.error("Error al enviar notificación FCM:", error);
      }

      return null;
    },
);
