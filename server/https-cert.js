const fs = require('fs');
const path = require('path');
const selfsigned = require('selfsigned');

const CERT_DIR = path.join(__dirname, 'certs');
const KEY_PATH = path.join(CERT_DIR, 'key.pem');
const CERT_PATH = path.join(CERT_DIR, 'cert.pem');

// Charge un certificat auto-signé existant, ou en génère un nouveau (valable 10 ans)
// si aucun n'existe encore. Le certificat est réutilisé aux démarrages suivants pour
// éviter de faire réapparaître l'avertissement du navigateur à chaque redémarrage.
function getOrCreateSelfSignedCert() {
  if (fs.existsSync(KEY_PATH) && fs.existsSync(CERT_PATH)) {
    return { key: fs.readFileSync(KEY_PATH), cert: fs.readFileSync(CERT_PATH) };
  }
  const attrs = [{ name: 'commonName', value: 'meteocarnet.local' }];
  const pems = selfsigned.generate(attrs, {
    days: 3650,
    keySize: 2048,
    extensions: [
      { name: 'basicConstraints', cA: true },
      {
        name: 'subjectAltName',
        altNames: [
          { type: 2, value: 'localhost' },
          { type: 2, value: 'meteocarnet.local' },
          { type: 7, ip: '127.0.0.1' }
        ]
      }
    ]
  });
  if (!fs.existsSync(CERT_DIR)) fs.mkdirSync(CERT_DIR, { recursive: true });
  fs.writeFileSync(KEY_PATH, pems.private);
  fs.writeFileSync(CERT_PATH, pems.cert);
  return { key: pems.private, cert: pems.cert };
}

module.exports = { getOrCreateSelfSignedCert, CERT_PATH, KEY_PATH };
