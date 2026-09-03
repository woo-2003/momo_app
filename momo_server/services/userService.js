/**
 * 사용자 저장소 파사드.
 * STORAGE=firestore|sqlite (기본: firestore)
 *
 * 반환 shape (findByEmail):
 *   { id, email, password_hash, nickname, birthdate, created_at }
 */

const storage = (process.env.STORAGE || "firestore").toLowerCase();

const store =
  storage === "sqlite"
    ? require("./sqliteUserStore")
    : require("./firestoreUserStore");

async function findByEmail(email) {
  return store.findByEmail(email);
}

async function findById(userId) {
  if (typeof store.findById !== "function") {
    return undefined;
  }
  return store.findById(userId);
}

async function isNicknameTaken(nickname) {
  return store.isNicknameTaken(nickname);
}

async function createUser(params) {
  return store.createUser(params);
}

async function listUsersForExport() {
  return store.listUsersForExport();
}

module.exports = {
  findByEmail,
  findById,
  isNicknameTaken,
  createUser,
  listUsersForExport,
  storage,
  ConflictError: store.ConflictError || class ConflictError extends Error {},
};
