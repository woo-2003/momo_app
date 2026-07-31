/**
 * SQLite users → Firestore users 1회 마이그레이션.
 *
 * 사용법 (momo_server 폴더):
 *   STORAGE=firestore 가 .env 에 설정되어 있어야 함
 *   npm run db:migrate
 *
 * 이미 같은 emailLower 가 있으면 해당 행은 건너뛴다.
 */

require("dotenv").config();

const path = require("path");
const fs = require("fs");

async function main() {
  const dbPath = path.join(__dirname, "..", "data", "momo.db");
  if (!fs.existsSync(dbPath)) {
    console.error(`SQLite DB 없음: ${dbPath}`);
    process.exit(1);
  }

  // SQLite 는 STORAGE 와 무관하게 직접 읽는다.
  const Database = require("better-sqlite3");
  const sqlite = new Database(dbPath, { readonly: true });
  const rows = sqlite
    .prepare(
      "SELECT id, email, password_hash, nickname, birthdate, created_at FROM users ORDER BY id"
    )
    .all();
  sqlite.close();

  console.log(`SQLite 사용자 ${rows.length}명 발견`);

  const {
    findByEmail,
    createUser,
  } = require("../services/firestoreUserStore");

  let migrated = 0;
  let skipped = 0;

  for (const row of rows) {
    const existing = await findByEmail(row.email);
    if (existing) {
      console.log(`skip (이미 존재): ${row.email}`);
      skipped += 1;
      continue;
    }

    const newId = await createUser({
      email: row.email,
      passwordHash: row.password_hash,
      nickname: row.nickname,
      birthdate: row.birthdate,
    });

    // created_at 을 SQLite 값으로 맞춘다.
    const { getFirestore } = require("../firebase");
    await getFirestore().collection("users").doc(newId).update({
      createdAt: row.created_at,
      legacySqliteId: row.id,
    });

    console.log(`migrated: ${row.email} → ${newId}`);
    migrated += 1;
  }

  console.log(`완료 — migrated=${migrated}, skipped=${skipped}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
