require("dotenv").config();

const path = require("path");
const fs = require("fs");
const { listUsersForExport, storage } = require("../services/userService");

async function main() {
  const rows = await listUsersForExport();

  console.log(`저장소: ${storage}`);
  console.log(`총 사용자 수: ${rows.length}`);
  console.table(rows);

  if (process.argv.includes("--export")) {
    const dataDir = path.join(__dirname, "..", "data");
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    const outPath = path.join(dataDir, "export-users.json");
    fs.writeFileSync(outPath, JSON.stringify(rows, null, 2), "utf-8");
    console.log(`내보내기 완료: ${outPath}`);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
