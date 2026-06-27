// 저장된 사용자 데이터를 조회/내보내기 하는 개발용 스크립트.
//
// 사용법 (momo_server 폴더에서 실행):
//   npm run db:view      → 콘솔에 사용자 목록을 표로 출력
//   npm run db:export    → data/export-users.json 으로 내보내기 (AI 학습용 추출 예시)
//
// 주의: password_hash 는 민감정보이므로 출력/내보내기에서 항상 제외한다.

const path = require("path");
const fs = require("fs");
const db = require("../db");

const rows = db
  .prepare(
    "SELECT id, email, nickname, birthdate, created_at FROM users ORDER BY id"
  )
  .all();

console.log(`총 사용자 수: ${rows.length}`);
console.table(rows);

// --export 플래그가 있으면 JSON 파일로 저장한다.
if (process.argv.includes("--export")) {
  const outPath = path.join(__dirname, "..", "data", "export-users.json");
  fs.writeFileSync(outPath, JSON.stringify(rows, null, 2), "utf-8");
  console.log(`내보내기 완료: ${outPath}`);
}
