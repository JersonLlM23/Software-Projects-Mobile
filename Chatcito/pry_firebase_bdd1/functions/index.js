const { onValueCreated } = require("firebase-functions/v2/database");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

/**
 * Cloud Function: notifyNewMessage
 *
 * Triggered when a new node is created inside /chats/general.
 * Sends an FCM notification to all devices subscribed to the
 * "chat_general" topic.
 *
 * Payload written by the Flutter app:
 * {
 *   "autor":     "Jerson",
 *   "texto":     "Hola a todos",
 *   "timestamp": 1234567890
 * }
 */
exports.notifyNewMessage = onValueCreated(
  {
    ref: "/chats/general/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    const message = event.data.val();

    if (!message) return;

    const autor = message.autor ?? "Alguien";
    const texto = message.texto ?? "Has recibido un nuevo mensaje en Chatcito";

    const fcmPayload = {
      // Topic — all subscribed devices receive this.
      topic: "chat_general",

      // Notification shown by the OS when the app is in background/closed.
      notification: {
        title: `Nuevo mensaje de ${autor}`,
        body: texto,
      },

      // Data payload available to the app in all states (foreground, background, terminated).
      // The Flutter app uses these fields to decide whether to show a local notification.
      data: {
        autor: autor,
        texto: texto,
        timestamp: String(message.timestamp ?? Date.now()),
        type: "new_message",
      },

      android: {
        priority: "high",
        notification: {
          channelId: "chatcito_messages",
          sound: "default",
          priority: "high",
        },
      },
    };

    try {
      const response = await getMessaging().send(fcmPayload);
      console.log(`[notifyNewMessage] Notification sent. Message ID: ${response}`);
    } catch (error) {
      console.error("[notifyNewMessage] Error sending notification:", error);
    }
  }
);
