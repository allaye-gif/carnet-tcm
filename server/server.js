require('dotenv').config();
const path = require('path');
const fs = require('fs');
const https = require('https');
const http = require('http');
const express = require('express');
const pool = require('./db');
const { sessionMiddleware, requireAuth, requireAdmin, bootstrapAdmin, bcrypt } = require('./auth');
const { getOrCreateSelfSignedCert } = require('./https-cert');

const app = express();
app.use(express.json({ limit: '8mb' }));
app.use(sessionMiddleware());

function pad2(n) { return String(n).padStart(2, '0'); }

/* ---------------- auth ---------------- */
app.post('/api/auth/login', async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: 'Identifiant et mot de passe requis.' });
  try {
    const r = await pool.query('SELECT id, username, password_hash, role FROM users WHERE username = $1', [username]);
    if (!r.rows.length) return res.status(401).json({ error: 'Identifiants incorrects.' });
    const user = r.rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) return res.status(401).json({ error: 'Identifiants incorrects.' });
    req.session.user = { id: user.id, username: user.username, role: user.role };
    res.json({ username: user.username, role: user.role });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

app.post('/api/auth/logout', (req, res) => {
  req.session.destroy(() => res.json({ ok: true }));
});

app.get('/api/auth/me', (req, res) => {
  if (req.session && req.session.user) return res.json(req.session.user);
  res.status(401).json({ error: 'Non connecté.' });
});

/* Tout ce qui suit nécessite d'être connecté. Les fichiers statiques (page web) restent
   accessibles sans connexion pour pouvoir afficher l'écran de connexion lui-même. */
app.use(express.static(path.join(__dirname, '..', 'public')));
app.use('/api', (req, res, next) => {
  if (req.path.startsWith('/auth/')) return next();
  requireAuth(req, res, next);
});

/* ---------------- health ---------------- */
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true, scanConfigured: !!process.env.ANTHROPIC_API_KEY });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

/* ---------------- utilisateurs (admin uniquement) ---------------- */
app.get('/api/users', requireAdmin, async (req, res) => {
  try {
    const r = await pool.query('SELECT id, username, role, created_at FROM users ORDER BY username');
    res.json(r.rows);
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

app.post('/api/users', requireAdmin, async (req, res) => {
  const { username, password, role } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: 'Identifiant et mot de passe requis.' });
  if (password.length < 6) return res.status(400).json({ error: 'Mot de passe trop court (6 caractères minimum).' });
  const finalRole = role === 'admin' ? 'admin' : 'observateur';
  try {
    const hash = await bcrypt.hash(password, 10);
    const r = await pool.query(
      'INSERT INTO users (username, password_hash, role) VALUES ($1,$2,$3) RETURNING id, username, role, created_at',
      [username, hash, finalRole]
    );
    res.json(r.rows[0]);
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ error: 'Cet identifiant existe déjà.' });
    console.error(e); res.status(500).json({ error: e.message });
  }
});

app.delete('/api/users/:id', requireAdmin, async (req, res) => {
  if (String(req.session.user.id) === String(req.params.id)) {
    return res.status(400).json({ error: 'Vous ne pouvez pas supprimer votre propre compte.' });
  }
  try {
    await pool.query('DELETE FROM users WHERE id = $1', [req.params.id]);
    res.json({ deleted: true });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

app.patch('/api/users/:id/password', requireAdmin, async (req, res) => {
  const { password } = req.body || {};
  if (!password || password.length < 6) return res.status(400).json({ error: 'Mot de passe trop court (6 caractères minimum).' });
  try {
    const hash = await bcrypt.hash(password, 10);
    await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [hash, req.params.id]);
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

/* ---------------- stations ---------------- */
app.get('/api/stations', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, name, lat, lon, alt FROM stations WHERE active = true ORDER BY name');
    res.json(r.rows);
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

app.get('/api/stations/archived', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, name, lat, lon, alt FROM stations WHERE active = false ORDER BY name');
    res.json(r.rows);
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

app.post('/api/stations', requireAdmin, async (req, res) => {
  const { id, name, lat, lon, alt } = req.body || {};
  if (!id || !name) return res.status(400).json({ error: 'id et name requis' });
  try {
    await pool.query(
      `INSERT INTO stations (id, name, lat, lon, alt, active) VALUES ($1,$2,$3,$4,$5,true)
       ON CONFLICT (id) DO UPDATE SET name = $2, lat = $3, lon = $4, alt = $5`,
      [id, name, lat || '', lon || '', alt || '']
    );
    res.json({ id, name, lat: lat || '', lon: lon || '', alt: alt || '' });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

app.patch('/api/stations/:id/archive', requireAdmin, async (req, res) => {
  try {
    await pool.query('UPDATE stations SET active = false WHERE id = $1', [req.params.id]);
    res.json({ archived: true });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

app.patch('/api/stations/:id/restore', requireAdmin, async (req, res) => {
  try {
    await pool.query('UPDATE stations SET active = true WHERE id = $1', [req.params.id]);
    res.json({ restored: true });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

// Suppression définitive : volontairement NON exposée dans l'application (aucun bouton n'appelle
// cette route). Reste disponible pour un usage manuel réfléchi, mais efface tout, irréversiblement.
app.delete('/api/stations/:id', requireAdmin, async (req, res) => {
  try {
    await pool.query('DELETE FROM stations WHERE id = $1', [req.params.id]);
    res.json({ deleted: true });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

/* ---------------- carnet (jours) ---------------- */
// Retire les informations de localisation/horodatage de saisie pour les comptes non-admin :
// seuls les administrateurs voient qui/où/quand une heure a été saisie.
function stripMetaIfNotAdmin(record, req) {
  if (req.session.user.role === 'admin') return record;
  if (record.meta) delete record.meta;
  if (record.hours) {
    Object.keys(record.hours).forEach(h => { if (record.hours[h] && record.hours[h].meta) delete record.hours[h].meta; });
  }
  return record;
}

function rowToCarnet(row) {
  return {
    stationId: row.station_id,
    date: (row.date instanceof Date) ? row.date.toISOString().slice(0, 10) : row.date,
    hours: row.hours,
    extras: row.extras,
    grainsOrages: row.grains_orages,
    observationsSpeciales: row.observations_speciales,
    meta: row.meta || undefined
  };
}

app.get('/api/carnet/:stationId', async (req, res) => {
  const { year, month } = req.query;
  try {
    let r;
    if (year && month) {
      const first = `${year}-${pad2(parseInt(month, 10))}-01`;
      r = await pool.query(
        `SELECT station_id, date, hours, extras, grains_orages, observations_speciales, meta
         FROM carnet_days
         WHERE station_id = $1 AND date >= $2::date AND date < ($2::date + interval '1 month')
         ORDER BY date`,
        [req.params.stationId, first]
      );
    } else {
      r = await pool.query(
        `SELECT station_id, date, hours, extras, grains_orages, observations_speciales, meta
         FROM carnet_days WHERE station_id = $1 ORDER BY date`,
        [req.params.stationId]
      );
    }
    res.json(r.rows.map(rowToCarnet).map(rec => stripMetaIfNotAdmin(rec, req)));
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

app.get('/api/carnet/:stationId/:date', async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT station_id, date, hours, extras, grains_orages, observations_speciales, meta
       FROM carnet_days WHERE station_id = $1 AND date = $2`,
      [req.params.stationId, req.params.date]
    );
    if (!r.rows.length) return res.json(null);
    res.json(stripMetaIfNotAdmin(rowToCarnet(r.rows[0]), req));
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

app.put('/api/carnet/:stationId/:date', async (req, res) => {
  const { hours, extras, grainsOrages, observationsSpeciales, meta } = req.body || {};
  try {
    // Un compte non-admin ne doit jamais pouvoir écraser les métadonnées déjà enregistrées
    // (ni en poser de nouvelles côté "vue" — elles sont capturées et acceptées ici, mais
    // simplement jamais renvoyées à la lecture pour ce rôle). On les accepte donc toujours
    // en écriture : c'est la lecture qui est filtrée par rôle, pas l'écriture.
    await pool.query(
      `INSERT INTO carnet_days (station_id, date, hours, extras, grains_orages, observations_speciales, meta, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7, now())
       ON CONFLICT (station_id, date) DO UPDATE
         SET hours = $3, extras = $4, grains_orages = $5, observations_speciales = $6, meta = $7, updated_at = now()`,
      [
        req.params.stationId, req.params.date,
        JSON.stringify(hours || {}), JSON.stringify(extras || {}),
        JSON.stringify(grainsOrages || []), JSON.stringify(observationsSpeciales || []),
        JSON.stringify(meta || null)
      ]
    );
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

/* ---------------- tableau mensuel ---------------- */
function rowToMensuel(row) {
  return { stationId: row.station_id, year: row.year, month: row.month, days: row.days, dominantText: row.dominant_text };
}

app.get('/api/mensuel/:stationId', async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT station_id, year, month, days, dominant_text FROM mensuel WHERE station_id = $1 ORDER BY year, month',
      [req.params.stationId]
    );
    res.json(r.rows.map(rowToMensuel));
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

app.get('/api/mensuel/:stationId/:year/:month', async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT station_id, year, month, days, dominant_text FROM mensuel WHERE station_id = $1 AND year = $2 AND month = $3',
      [req.params.stationId, parseInt(req.params.year, 10), parseInt(req.params.month, 10)]
    );
    if (!r.rows.length) return res.json(null);
    res.json(rowToMensuel(r.rows[0]));
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

app.put('/api/mensuel/:stationId/:year/:month', async (req, res) => {
  const { days, dominantText } = req.body || {};
  try {
    await pool.query(
      `INSERT INTO mensuel (station_id, year, month, days, dominant_text, updated_at)
       VALUES ($1,$2,$3,$4,$5, now())
       ON CONFLICT (station_id, year, month) DO UPDATE
         SET days = $4, dominant_text = $5, updated_at = now()`,
      [req.params.stationId, parseInt(req.params.year, 10), parseInt(req.params.month, 10), JSON.stringify(days || []), dominantText || null]
    );
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message }); }
});

/* ---------------- scan IA (optionnel, clé côté serveur uniquement) ---------------- */
app.post('/api/scan', async (req, res) => {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return res.status(501).json({ error: 'Scan IA non configuré sur ce serveur (ANTHROPIC_API_KEY absente du .env).' });
  }
  const { images, prompt } = req.body || {};
  if (!Array.isArray(images) || !images.length) {
    return res.status(400).json({ error: 'Aucune image reçue.' });
  }
  try {
    const content = [
      ...images.map(img => ({ type: 'image', source: { type: 'base64', media_type: img.mediaType || 'image/jpeg', data: img.data } })),
      { type: 'text', text: prompt || '' }
    ];
    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({ model: 'claude-sonnet-4-6', max_tokens: 8000, messages: [{ role: 'user', content }] })
    });
    const data = await r.json();
    res.json(data);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

/* ---------------- démarrage ---------------- */
const PORT = process.env.PORT || 3000;
const HTTPS_PORT = process.env.HTTPS_PORT || 3443;
const ENABLE_HTTPS = process.env.ENABLE_HTTPS === 'true';

async function start() {
  console.log('Vérification de la connexion à PostgreSQL...');
  try {
    await pool.query('SELECT 1');
    console.log('✓ Connexion à PostgreSQL réussie (base "' + (process.env.DB_NAME || 'meteocarnet') + '").');
    await bootstrapAdmin();
  } catch (e) {
    console.log('');
    console.log('✗ ÉCHEC de connexion à PostgreSQL :');
    console.log('  ' + e.message);
    console.log('');
    console.log('Causes probables à vérifier dans server/.env :');
    console.log('  - DB_PASSWORD incorrect');
    console.log('  - DB_NAME incorrect ou base non créée');
    console.log('  - PostgreSQL non démarré sur cette machine');
    console.log('  - DB_HOST/DB_PORT incorrects');
    console.log('');
    console.log('Le serveur web reste allumé mais aucune donnée ne pourra être lue ni enregistrée tant que ceci n\'est pas corrigé.');
    console.log('');
  }

  if (!process.env.ANTHROPIC_API_KEY) {
    console.log('(Scan IA désactivé — ANTHROPIC_API_KEY non définie dans .env. Le reste de l\'application fonctionne normalement.)');
  }

  if (ENABLE_HTTPS) {
    const { key, cert } = getOrCreateSelfSignedCert();
    https.createServer({ key, cert }, app).listen(HTTPS_PORT, () => {
      console.log(`MétéoCarnet — serveur HTTPS démarré sur https://localhost:${HTTPS_PORT}`);
      console.log('(Certificat auto-signé : votre navigateur affichera un avertissement la première fois — voir README pour l\'installer comme certificat de confiance.)');
    });
    // Redirige aussi le port HTTP existant vers HTTPS, par confort (anciens liens/marque-pages).
    http.createServer((req, res) => {
      res.writeHead(301, { Location: `https://${req.headers.host ? req.headers.host.split(':')[0] : 'localhost'}:${HTTPS_PORT}${req.url}` });
      res.end();
    }).listen(PORT, () => {
      console.log(`(Le port http://localhost:${PORT} redirige automatiquement vers HTTPS.)`);
    });
  } else {
    http.createServer(app).listen(PORT, () => {
      console.log(`MétéoCarnet — serveur démarré sur http://localhost:${PORT}`);
      console.log('(HTTPS désactivé — mettez ENABLE_HTTPS=true dans .env pour l\'activer ; nécessaire pour que la géolocalisation fonctionne hors "localhost".)');
    });
  }
}

start();
