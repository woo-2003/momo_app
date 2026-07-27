/**
 * 저장소 추상화 스모크 테스트 (HTTP 없이 userService 직접).
 * STORAGE=sqlite|firestore 로 실행.
 *
 *   node scripts/smoke-user-store.js
 */

require("dotenv").config();

const bcrypt = require("bcryptjs");

async function main() {
  const {
    findByEmail,
    isNicknameTaken,
    listUsersForExport,
    storage,
  } = require("../services/userService");

  console.log(`STORAGE=${storage}`);

  const users = await listUsersForExport();
  console.log(`export count=${users.length}`);
  console.table(users);

  if (users.length === 0) {
    console.log("사용자 없음 — list/export OK, login 스킵");
    return;
  }

  const sample = users[0];
  const byEmail = await findByEmail(sample.email);
  if (!byEmail || !byEmail.password_hash) {
    throw new Error("findByEmail 실패 또는 password_hash 없음");
  }
  console.log("findByEmail OK:", byEmail.email, "id=", byEmail.id);

  const taken = await isNicknameTaken(sample.nickname);
  if (!taken) throw new Error("isNicknameTaken 이 기존 닉네임에 false");
  console.log("isNicknameTaken OK");

  const free = await isNicknameTaken(`__free_${Date.now()}__`);
  if (free) throw new Error("없는 닉네임이 taken=true");
  console.log("isNicknameTaken(free) OK");

  // password_hash 가 bcrypt 형태인지 확인 (비교는 실제 비번 없이 형식만)
  if (!String(byEmail.password_hash).startsWith("$2")) {
    console.warn("warning: password_hash 가 bcrypt 형태가 아닐 수 있음");
  } else {
    console.log("password_hash bcrypt prefix OK");
  }

  // 잘못된 비번 compare
  const wrong = await bcrypt.compare("definitely-wrong-password", byEmail.password_hash);
  if (wrong) throw new Error("잘못된 비번이 match");
  console.log("bcrypt.compare(wrong) OK");

  console.log("smoke-user-store PASSED");
}

main().catch((e) => {
  console.error("smoke FAILED:", e);
  process.exit(1);
});
