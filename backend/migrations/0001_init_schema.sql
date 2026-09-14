CREATE TABLE IF NOT EXISTS subscriptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE,
  code_hash TEXT UNIQUE,
  subscription_code TEXT UNIQUE, -- Hashed later, or kept for admin view
  server_type TEXT DEFAULT 'xtream', -- 'xtream', 'mac', 'stalker'
  content_mode TEXT DEFAULT 'standard', -- 'standard', 'adult', 'kids'
  host TEXT,
  username_iptv TEXT,
  password_iptv TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME,
  max_devices INTEGER DEFAULT 1,
  status TEXT DEFAULT 'active', -- 'active', 'suspended', 'revoked', 'expired'
  plan_name TEXT,
  features TEXT,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS devices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subscription_id INTEGER,
  device_id TEXT,
  device_name TEXT,
  last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
  ip_address TEXT,
  UNIQUE(subscription_id, device_id),
  FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS plans (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE,
  duration_days INTEGER,
  price REAL,
  features TEXT,
  max_devices INTEGER DEFAULT 1,
  status TEXT DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS app_config (
  key TEXT PRIMARY KEY,
  value TEXT
);

CREATE TABLE IF NOT EXISTS admin_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  admin_user TEXT,
  action TEXT,
  target TEXT,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  details TEXT
);
