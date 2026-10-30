export const sqliteSchema = `PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL, name TEXT NOT NULL,
      password TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'member'
        CHECK(role IN ('admin','staff','member')),
      verified INTEGER NOT NULL DEFAULT 0, active INTEGER NOT NULL DEFAULT 1,
      assigned_staff_id TEXT REFERENCES users(id) ON DELETE SET NULL,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS challenges (
      id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      purpose TEXT NOT NULL, digest TEXT NOT NULL, expires_at INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0, used INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      expires_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS contacts (
      id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name TEXT NOT NULL, phone TEXT NOT NULL, relationship TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
      UNIQUE(owner_id,phone)
    );
    CREATE TABLE IF NOT EXISTS checkins (
      id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      title TEXT NOT NULL, due_at INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'pending'
        CHECK(status IN ('pending','safe','needs_help','resolved')),
      note TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS contacts_owner ON contacts(owner_id);
    CREATE INDEX IF NOT EXISTS checkins_owner ON checkins(owner_id,due_at);
    CREATE INDEX IF NOT EXISTS challenges_user ON challenges(user_id,purpose,created_at);
    CREATE INDEX IF NOT EXISTS sessions_expiry ON sessions(expires_at);
    CREATE TABLE IF NOT EXISTS google_identities (
      subject TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS google_oauth_flows (
      id TEXT PRIMARY KEY, state_digest TEXT UNIQUE NOT NULL, nonce TEXT NOT NULL,
      google_verifier TEXT NOT NULL, app_challenge TEXT NOT NULL,
      link_user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
      link_session_id TEXT REFERENCES sessions(id) ON DELETE CASCADE,
      user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
      ticket_digest TEXT, callback_used INTEGER NOT NULL DEFAULT 0,
      exchanged INTEGER NOT NULL DEFAULT 0, expires_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS google_flows_expiry ON google_oauth_flows(expires_at);
    PRAGMA user_version=1;
  `;
export const postgresSchema = sqliteSchema
  .replace(/PRAGMA[^;]*;/g, "")
  .replace(/\bINTEGER\b/g, "BIGINT");
