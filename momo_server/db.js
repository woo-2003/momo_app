const path = require("path");
const fs = require("fs");
const Database = require("better-sqlite3");

const DATA_DIR = path.join(__dirname, "data");
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

const db = new Database(path.join(DATA_DIR, "momo.db"));

// 동시 읽기/쓰기 성능을 위해 WAL 모드 사용
db.pragma("journal_mode = WAL");

// email / nickname 은 대소문자 무시(COLLATE NOCASE)로 중복을 막는다.
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    email         TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password_hash TEXT NOT NULL,
    nickname      TEXT NOT NULL UNIQUE COLLATE NOCASE,
    birthdate     TEXT NOT NULL,
    created_at    TEXT NOT NULL DEFAULT (datetime('now'))
  );
`);

module.exports = db;
