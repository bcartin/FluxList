/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions";
// import {onRequest} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// The Cloud Functions for Firebase SDK to create Cloud Functions and triggers.
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/firestore";

// The Firebase Admin SDK to access Firestore.
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";

initializeApp();

export const onListCreated = onDocumentCreated("lists/{listId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    logger.error("No data associated with the event");
    return;
  }

  const data = snapshot.data();
  const createdBy = data.createdBy as string;
  const userIDs = data.userIDs as string[];

  const db = getFirestore();

  const creatorDoc = await db.collection("users").doc(createdBy).get();
  const creatorName = creatorDoc.data()?.name as string ?? "Someone";

  for (const userID of userIDs) {
    if (userID === createdBy) continue;

    const userDoc = await db.collection("users").doc(userID).get();
    if (!userDoc.exists) {
      logger.warn("User document not found", {userID});
      continue;
    }

    const token = userDoc.data()?.token as string;
    if (!token) {
      logger.warn("No token found for user", {userID});
      continue;
    }

    await sendPushNotification(`${creatorName} has shared a list with you`, "", token);
  }
});

export const onListUpdated = onDocumentUpdated("lists/{listId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    logger.error("No data associated with the event");
    return;
  }

  const beforeData = snapshot.before.data();
  const afterData = snapshot.after.data();

  const previousUserIDs = beforeData.userIDs as string[] ?? [];
  const currentUserIDs = afterData.userIDs as string[] ?? [];
  const createdBy = afterData.createdBy as string;

  const newUserIDs = currentUserIDs.filter((id) => !previousUserIDs.includes(id));

  if (newUserIDs.length === 0) return;

  const db = getFirestore();

  const creatorDoc = await db.collection("users").doc(createdBy).get();
  const creatorName = creatorDoc.data()?.name as string ?? "Someone";

  for (const userID of newUserIDs) {
    if (userID === createdBy) continue;

    const userDoc = await db.collection("users").doc(userID).get();
    if (!userDoc.exists) {
      logger.warn("User document not found", {userID});
      continue;
    }

    const token = userDoc.data()?.token as string;
    if (!token) {
      logger.warn("No token found for user", {userID});
      continue;
    }

    await sendPushNotification(`${creatorName} has shared a list with you`, "", token);
  }
});

async function sendPushNotification(title: string, message: string, token: string): Promise<string> {
  const result = await getMessaging().send({
    token,
    notification: {
      title,
      body: message,
    },
  });

  logger.info("Push notification sent", {messageId: result});
  return result;
}
