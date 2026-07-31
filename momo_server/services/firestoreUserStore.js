const { getFirestore } = require("../firebase");

const USERS = "users";

function normalizeEmail(email) {
  return email.trim().toLowerCase();
}

function normalizeNickname(nickname) {
  return nickname.trim().toLowerCase();
}

function mapDoc(doc) {
  const data = doc.data();
  return {
    id: doc.id,
    email: data.email,
    password_hash: data.passwordHash,
    nickname: data.nickname,
    birthdate: data.birthdate,
    created_at:
      typeof data.createdAt === "string"
        ? data.createdAt
        : data.createdAt?.toDate?.()?.toISOString?.() ?? null,
  };
}

async function findByEmail(email) {
  const emailLower = normalizeEmail(email);
  const snap = await getFirestore()
    .collection(USERS)
    .where("emailLower", "==", emailLower)
    .limit(1)
    .get();

  if (snap.empty) return undefined;
  return mapDoc(snap.docs[0]);
}

async function isNicknameTaken(nickname) {
  const nicknameLower = normalizeNickname(nickname);
  const snap = await getFirestore()
    .collection(USERS)
    .where("nicknameLower", "==", nicknameLower)
    .limit(1)
    .get();
  return !snap.empty;
}

async function createUser({ email, passwordHash, nickname, birthdate }) {
  const emailTrimmed = email.trim();
  const nicknameTrimmed = nickname.trim();
  const ref = getFirestore().collection(USERS).doc();

  await ref.set({
    email: emailTrimmed,
    emailLower: normalizeEmail(emailTrimmed),
    passwordHash,
    nickname: nicknameTrimmed,
    nicknameLower: normalizeNickname(nicknameTrimmed),
    birthdate,
    createdAt: new Date().toISOString(),
  });

  return ref.id;
}

async function listUsersForExport() {
  const snap = await getFirestore().collection(USERS).orderBy("createdAt").get();
  return snap.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      email: data.email,
      nickname: data.nickname,
      birthdate: data.birthdate,
      created_at:
        typeof data.createdAt === "string"
          ? data.createdAt
          : data.createdAt?.toDate?.()?.toISOString?.() ?? null,
    };
  });
}

class ConflictError extends Error {
  constructor(message) {
    super(message);
    this.name = "ConflictError";
    this.code = "USER_CONFLICT";
  }
}

module.exports = {
  findByEmail,
  isNicknameTaken,
  createUser,
  listUsersForExport,
  ConflictError,
};
