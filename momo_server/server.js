require("dotenv").config();

const express = require("express");
const cors = require("cors");

const app = express();
app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.send('OTP server is running');
});

const otpRoutes = require("./routes/otpRoutes");
app.use("/", otpRoutes);

const authRoutes = require("./routes/authRoutes");
app.use("/", authRoutes);

const PORT = process.env.PORT || 3000;

// 직접 실행할 때만 서버를 띄운다 (테스트에서 app 재사용 가능하도록 export)
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

module.exports = app;