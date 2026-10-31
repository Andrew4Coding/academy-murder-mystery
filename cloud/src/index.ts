import { CloudServer } from "./server/server.js";

const dataDir = process.env.DATA_DIR ?? "./data";
const port = Number(process.env.PORT ?? 8080);

const server = new CloudServer({
  dbPath: `${dataDir}/moonfall.sqlite`,
  trustProxy: process.env.TRUST_PROXY === "1",
  pairingSecret: process.env.MOONFALL_PAIRING_SECRET,
  bootstrapPin: process.env.MOONFALL_BOOTSTRAP_PIN
});

await server.start(port);
console.log(`moonfall cloud host listening on :${port}, mode ${server.mode}`);

const shutdown = () => void server.stop().then(() => process.exit(0));
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
