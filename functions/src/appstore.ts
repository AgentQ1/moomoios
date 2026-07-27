/**
 * App Store subscription verification for Moomo Premium.
 *
 * Two entry points:
 *  - verifyAppStorePurchase (callable): the app sends a StoreKit 2 signed
 *    transaction (JWS) after a purchase/restore; we verify Apple's signature
 *    chain against Apple's root CAs and persist the entitlement for the
 *    calling Firebase user.
 *  - appStoreNotifications (HTTPS): App Store Server Notifications V2. Apple
 *    posts signed renewal/expiration/refund events here so the backend stays
 *    authoritative even when the app never launches.
 *
 * The backend never trusts a client-supplied "isPremium" — entitlement state
 * is derived exclusively from Apple-signed payloads and re-checked against
 * expiration/grace/revocation dates on every AI request (see quota.ts).
 */
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { defineInt } from "firebase-functions/params";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { readFileSync } from "fs";
import * as path from "path";
import {
  SignedDataVerifier,
  Environment,
  JWSTransactionDecodedPayload,
  JWSRenewalInfoDecodedPayload,
} from "@apple/app-store-server-library";

export const BUNDLE_ID = "com.moomolab.moomo";
/**
 * Must match the auto-renewable product ID configured in App Store Connect
 * (and `StoreService.monthlyProductID` in the app).
 *
 * The `.v2` suffix is not a version marker: the original
 * `com.moomolab.moomo.premium.monthly` was deleted after its localization became
 * permanently stuck in WAITING_FOR_REVIEW, and Apple never releases a product ID
 * once used. The old ID is deliberately NOT accepted — that product no longer
 * exists in App Store Connect, so Apple can never issue a transaction for it.
 */
export const MONTHLY_PRODUCT_ID = "com.moomolab.moomo.premium.monthly.v2";
const ALLOWED_PRODUCT_IDS = new Set([MONTHLY_PRODUCT_ID]);

/**
 * The app's numeric Apple ID from App Store Connect (App Information page).
 * Required by Apple's verifier for PRODUCTION payloads only — sandbox works
 * without it. Set via `firebase functions:config` param / .env:
 *   APP_APPLE_ID=1234567890
 * Until it is set, production receipts cannot be verified (sandbox still can).
 */
const APP_APPLE_ID = defineInt("APP_APPLE_ID", { default: 0 });

const db = () => admin.firestore();

// ---- Apple signature verification ------------------------------------------

function appleRootCerts(): Buffer[] {
  // __dirname is lib/ after tsc; certs ship alongside the source dir.
  const dir = path.join(__dirname, "..", "certs");
  return [
    "AppleRootCA-G3.cer",
    "AppleRootCA-G2.cer",
    "AppleIncRootCertificate.cer",
  ].map((f) => readFileSync(path.join(dir, f)));
}

let cachedVerifiers: SignedDataVerifier[] | null = null;

/** Sandbox verifier always; production verifier once APP_APPLE_ID is set. */
function verifiers(): SignedDataVerifier[] {
  if (cachedVerifiers) return cachedVerifiers;
  const certs = appleRootCerts();
  const list: SignedDataVerifier[] = [];
  const appAppleId = APP_APPLE_ID.value();
  if (appAppleId > 0) {
    list.push(new SignedDataVerifier(certs, true, Environment.PRODUCTION, BUNDLE_ID, appAppleId));
  }
  list.push(new SignedDataVerifier(certs, true, Environment.SANDBOX, BUNDLE_ID));
  cachedVerifiers = list;
  return list;
}

async function verifyTransaction(jws: string): Promise<JWSTransactionDecodedPayload> {
  let lastError: unknown;
  for (const verifier of verifiers()) {
    try {
      return await verifier.verifyAndDecodeTransaction(jws);
    } catch (err) {
      lastError = err;
    }
  }
  logger.warn("App Store transaction failed verification", lastError);
  throw new HttpsError("invalid-argument", "The purchase could not be verified.");
}

// ---- entitlement persistence -------------------------------------------------

export interface PremiumEntitlementDoc {
  isActive: boolean;
  productId: string;
  originalTransactionId: string;
  expiresDateMs: number | null;
  graceUntilMs: number | null;
  revoked: boolean;
  revocationDateMs: number | null;
  autoRenewStatus: number | null;
  environment: string;
  appAccountToken: string | null;
  lastVerifiedAt: FirebaseFirestore.FieldValue;
  updatedSource: "purchase" | "notification";
}

/**
 * Server-authoritative activity check. `isActive` is stored for display, but
 * quota decisions always recompute from dates so an expiration takes effect
 * even if Apple's EXPIRED notification never arrives.
 */
export function entitlementIsActive(d: FirebaseFirestore.DocumentData | undefined): boolean {
  if (!d) return false;
  // Entitlements written for a retired product (e.g. the deleted com.moomo.io
  // app's subscription) never unlock the current app.
  if (typeof d.productId === "string" && d.productId.length > 0 && !ALLOWED_PRODUCT_IDS.has(d.productId)) {
    return false;
  }
  // The subscription moved to another Firebase account (account switch /
  // restore under a different login). Dates alone would still read as active
  // here, so the transfer marker must win.
  if (typeof d.transferredTo === "string" && d.transferredTo.length > 0) return false;
  if (d.revoked === true) return false;
  const now = Date.now();
  if (typeof d.expiresDateMs === "number" && d.expiresDateMs > now) return true;
  if (typeof d.graceUntilMs === "number" && d.graceUntilMs > now) return true;
  return false;
}

/** Is the given Firebase uid currently entitled to Moomo Premium? */
export async function isPremiumUid(uid: string): Promise<boolean> {
  const snap = await db().doc(`users/${uid}/entitlements/premium`).get();
  return entitlementIsActive(snap.data());
}

function entitlementFromApple(
  txn: JWSTransactionDecodedPayload,
  renewal: JWSRenewalInfoDecodedPayload | null,
  source: "purchase" | "notification"
): PremiumEntitlementDoc {
  const expiresDateMs = typeof txn.expiresDate === "number" ? txn.expiresDate : null;
  const revocationDateMs = typeof txn.revocationDate === "number" ? txn.revocationDate : null;
  const graceUntilMs =
    renewal && typeof renewal.gracePeriodExpiresDate === "number"
      ? renewal.gracePeriodExpiresDate
      : null;
  const revoked = revocationDateMs !== null;
  const now = Date.now();
  const isActive =
    !revoked &&
    ((expiresDateMs !== null && expiresDateMs > now) ||
      (graceUntilMs !== null && graceUntilMs > now));
  return {
    isActive,
    productId: txn.productId ?? "",
    originalTransactionId: String(txn.originalTransactionId ?? ""),
    expiresDateMs,
    graceUntilMs,
    revoked,
    revocationDateMs,
    autoRenewStatus: renewal && typeof renewal.autoRenewStatus === "number" ? renewal.autoRenewStatus : null,
    environment: String(txn.environment ?? ""),
    appAccountToken: typeof txn.appAccountToken === "string" ? txn.appAccountToken : null,
    lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedSource: source,
  };
}

/**
 * Persist the entitlement for `uid` and keep the originalTransactionId → uid
 * mapping used by server notifications. If the same Apple subscription was
 * previously attached to a different Firebase account (account switch,
 * restore on a new login), the entitlement MOVES: the old account is
 * deactivated so one Apple subscription never powers several accounts at once.
 */
async function persistEntitlement(uid: string, doc: PremiumEntitlementDoc): Promise<void> {
  const firestore = db();
  const mappingRef = firestore.collection("appStoreTransactions").doc(doc.originalTransactionId);
  const entitlementRef = firestore.doc(`users/${uid}/entitlements/premium`);

  await firestore.runTransaction(async (tx) => {
    const mapping = await tx.get(mappingRef);
    const previousUid = mapping.data()?.uid as string | undefined;
    if (previousUid && previousUid !== uid) {
      tx.set(
        firestore.doc(`users/${previousUid}/entitlements/premium`),
        {
          isActive: false,
          transferredTo: uid,
          lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
    tx.set(mappingRef, {
      uid,
      productId: doc.productId,
      environment: doc.environment,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Clear any transfer marker left from a previous account switch — this
    // account is the subscription's current home again.
    tx.set(entitlementRef, { ...doc, transferredTo: admin.firestore.FieldValue.delete() }, { merge: true });
  });
}

// ---- callable: verify a purchase from the app --------------------------------

export const verifyAppStorePurchase = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const uid = request.auth.uid;
  const jws = request.data?.jws;
  if (typeof jws !== "string" || jws.length === 0 || jws.length > 20_000) {
    throw new HttpsError("invalid-argument", '"jws" is required.');
  }

  const txn = await verifyTransaction(jws);

  if (!txn.productId || !ALLOWED_PRODUCT_IDS.has(txn.productId)) {
    throw new HttpsError("invalid-argument", "Unknown product.");
  }
  if (!txn.originalTransactionId) {
    throw new HttpsError("invalid-argument", "The purchase could not be verified.");
  }

  const doc = entitlementFromApple(txn, null, "purchase");
  await persistEntitlement(uid, doc);

  logger.info("verifyAppStorePurchase", {
    uid,
    productId: doc.productId,
    environment: doc.environment,
    isActive: doc.isActive,
    expiresDateMs: doc.expiresDateMs,
  });

  return {
    isActive: doc.isActive,
    productId: doc.productId,
    expiresDateMs: doc.expiresDateMs,
    environment: doc.environment,
  };
});

// ---- HTTPS: App Store Server Notifications V2 ---------------------------------

export const appStoreNotifications = onRequest({ cors: false }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }
  const signedPayload = req.body?.signedPayload;
  if (typeof signedPayload !== "string" || signedPayload.length === 0) {
    res.status(400).send("Missing signedPayload");
    return;
  }

  // Try each configured environment's verifier; remember which one succeeded
  // so nested transaction/renewal payloads are decoded with the same one.
  let payload = null;
  let verifier: SignedDataVerifier | null = null;
  for (const v of verifiers()) {
    try {
      payload = await v.verifyAndDecodeNotification(signedPayload);
      verifier = v;
      break;
    } catch {
      // fall through to the next environment
    }
  }
  if (!payload || !verifier) {
    logger.warn("appStoreNotifications: signature verification failed");
    res.status(401).send("Verification failed");
    return;
  }

  const type = payload.notificationType ?? "UNKNOWN";
  const subtype = payload.subtype ?? null;

  // TEST notifications (and any event without transaction info) just ack.
  const signedTxn = payload.data?.signedTransactionInfo;
  if (typeof signedTxn !== "string" || signedTxn.length === 0) {
    logger.info("appStoreNotifications: no transaction info", { type, subtype });
    res.status(200).send("OK");
    return;
  }

  try {
    const txn = await verifier.verifyAndDecodeTransaction(signedTxn);
    let renewal: JWSRenewalInfoDecodedPayload | null = null;
    const signedRenewal = payload.data?.signedRenewalInfo;
    if (typeof signedRenewal === "string" && signedRenewal.length > 0) {
      renewal = await verifier.verifyAndDecodeRenewalInfo(signedRenewal);
    }

    const originalTransactionId = String(txn.originalTransactionId ?? "");
    if (!originalTransactionId || !txn.productId || !ALLOWED_PRODUCT_IDS.has(txn.productId)) {
      logger.info("appStoreNotifications: ignoring product", { type, productId: txn.productId });
      res.status(200).send("OK");
      return;
    }

    const mapping = await db().collection("appStoreTransactions").doc(originalTransactionId).get();
    const uid = mapping.data()?.uid as string | undefined;
    if (!uid) {
      // Purchase not yet registered by the app (e.g. notification raced the
      // callable). Park the event; the next verifyAppStorePurchase call will
      // write fresh state anyway.
      logger.warn("appStoreNotifications: unmatched transaction", { type, originalTransactionId });
      await db().collection("appStoreUnmatchedEvents").add({
        notificationType: type,
        subtype,
        originalTransactionId,
        receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.status(200).send("OK");
      return;
    }

    const doc = entitlementFromApple(txn, renewal, "notification");
    await persistEntitlement(uid, doc);
    logger.info("appStoreNotifications: entitlement updated", {
      uid,
      type,
      subtype,
      isActive: doc.isActive,
      expiresDateMs: doc.expiresDateMs,
      revoked: doc.revoked,
    });
    res.status(200).send("OK");
  } catch (err) {
    logger.error("appStoreNotifications: processing failed", err);
    // Non-2xx makes Apple retry with backoff — desirable for transient failures.
    res.status(500).send("Processing failed");
  }
});
