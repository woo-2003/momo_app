const path = require("path");
const admin = require("firebase-admin");

let db = null;

/**
 * Firebase Admin + Firestore 초기화 (프로세스당 1회).
 * GOOGLE_APPLICATION_CREDENTIALS 와 FIREBASE_PROJECT_ID 가 필요하다.
 */
function getFirestore() {
  if (db) return db;

  if (admin.apps.length === 0) {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    if (!projectId) {
      throw new Error(
        "FIREBASE_PROJECT_ID 환경변수가 없습니다. .env 를 확인하세요."
      );
    }

    const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (!credPath) {
      throw new Error(
        "GOOGLE_APPLICATION_CREDENTIALS 환경변수가 없습니다. .env 를 확인하세요."
      );
    }

    const absoluteCredPath = path.isAbsolute(credPath)
      ? credPath
      : path.resolve(__dirname, credPath);

    // eslint-disable-next-line import/no-dynamic-require, global-require
    const serviceAccount = require(absoluteCredPath);

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });
  }

  db = admin.firestore();
  return db;
}

module.exports = {
  getFirestore,
  admin,
};
