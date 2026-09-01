/**
 * 저장소 루트의 firestore.indexes.json 을 Firebase에 배포한다.
 *
 * 사전 준비:
 *   npx firebase login
 *   (또는 momo_server 에서 npm install 후 npx firebase login)
 *
 * 실행:
 *   npm run deploy:indexes
 */
const { spawnSync } = require("child_process");
const path = require("path");

const repoRoot = path.resolve(__dirname, "../..");
const firebaseBin = path.resolve(
  __dirname,
  "../node_modules/.bin/firebase"
);
const command = process.platform === "win32" ? `${firebaseBin}.cmd` : firebaseBin;

const result = spawnSync(command, ["deploy", "--only", "firestore:indexes"], {
  cwd: repoRoot,
  stdio: "inherit",
  shell: process.platform === "win32",
});

if (result.error) {
  console.error("firebase CLI 실행 실패:", result.error.message);
  console.error("먼저 momo_server 에서 npm install 후 npx firebase login 을 실행하세요.");
  process.exit(1);
}

process.exit(result.status ?? 1);
