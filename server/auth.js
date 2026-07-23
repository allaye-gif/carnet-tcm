const bcrypt = require('bcryptjs');
const session = require('express-session');
const PgSession = require('connect-pg-simple')(session);
const pool = require('./db');

function sessionMiddleware() {
  return session({
    store: new PgSession({ pool, tableName: 'session', createTableIfMissing: true }),
    secret: process.env.SESSION_SECRET || 'meteocarnet-changez-moi-svp',
    resave: false,
    saveUninitialized: false,
    cookie: {
      maxAge: 30 * 24 * 60 * 60 * 1000, // 30 jours
      secure: process.env.ENABLE_HTTPS === 'true',
      sameSite: 'lax'
    }
  });
}

function requireAuth(req, res, next) {
  if (req.session && req.session.user) return next();
  res.status(401).json({ error: 'Non connecté.' });
}

function requireAdmin(req, res, next) {
  if (req.session && req.session.user && req.session.user.role === 'admin') return next();
  res.status(403).json({ error: 'Réservé aux administrateurs.' });
}

async function bootstrapAdmin() {
  const r = await pool.query('SELECT COUNT(*)::int AS c FROM users');
  if (r.rows[0].c > 0) return;
  const username = process.env.ADMIN_USERNAME || 'admin';
  let password = process.env.ADMIN_PASSWORD;
  let generated = false;
  if (!password) {
    password = Math.random().toString(36).slice(-10) + Math.random().toString(36).slice(-2).toUpperCase();
    generated = true;
  }
  const hash = await bcrypt.hash(password, 10);
  await pool.query(
    'INSERT INTO users (username, password_hash, role) VALUES ($1,$2,$3)',
    [username, hash, 'admin']
  );
  console.log('');
  console.log('============================================================');
  console.log(' Premier compte administrateur créé automatiquement :');
  console.log('   Utilisateur : ' + username);
  if (generated) {
    console.log('   Mot de passe : ' + password + '  (généré aléatoirement — notez-le, changez-le ensuite)');
  } else {
    console.log('   Mot de passe : celui défini dans ADMIN_PASSWORD (.env)');
  }
  console.log('============================================================');
  console.log('');
}

module.exports = { sessionMiddleware, requireAuth, requireAdmin, bootstrapAdmin, bcrypt };
