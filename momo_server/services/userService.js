const db = require("../db");

const findByEmailStmt = db.prepare(
  "SELECT id, email, password_hash, nickname, birthdate, created_at FROM users WHERE email = ?"
);
const isNicknameTakenStmt = db.prepare(
  "SELECT 1 FROM users WHERE nickname = ? LIMIT 1"
);
const insertUserStmt = db.prepare(
  `INSERT INTO users (email, password_hash, nickname, birthdate)
   VALUES (@email, @passwordHash, @nickname, @birthdate)`
);

function findByEmail(email) {
  return findByEmailStmt.get(email);
}

function isNicknameTaken(nickname) {
  return isNicknameTakenStmt.get(nickname) !== undefined;
}

function createUser({ email, passwordHash, nickname, birthdate }) {
  const info = insertUserStmt.run({ email, passwordHash, nickname, birthdate });
  return info.lastInsertRowid;
}

module.exports = {
  findByEmail,
  isNicknameTaken,
  createUser,
};
