-- SubForge Database Initialization
-- This runs automatically on first PostgreSQL start

CREATE TABLE IF NOT EXISTS users (
    id          SERIAL PRIMARY KEY,
    username    VARCHAR(64) UNIQUE NOT NULL,
    password    VARCHAR(128) NOT NULL,
    role        VARCHAR(16) DEFAULT 'user',
    created_by  INTEGER REFERENCES users(id),
    status      SMALLINT DEFAULT 1,
    created_at  TIMESTAMP DEFAULT NOW(),
    updated_at  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subscriptions (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name        VARCHAR(128) NOT NULL,
    url         TEXT NOT NULL,
    auto_refresh INTEGER DEFAULT 3600,
    tags        JSONB DEFAULT '[]',
    last_fetch  TIMESTAMP,
    node_count  INTEGER DEFAULT 0,
    status      SMALLINT DEFAULT 1,
    created_at  TIMESTAMP DEFAULT NOW(),
    updated_at  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS nodes (
    id              SERIAL PRIMARY KEY,
    subscription_id INTEGER REFERENCES subscriptions(id) ON DELETE CASCADE,
    name            VARCHAR(256),
    display_name    VARCHAR(256),
    node_type       VARCHAR(32),
    server          VARCHAR(256),
    port            INTEGER,
    region          VARCHAR(64),
    raw_uri         TEXT,
    config_json     JSONB,
    latency         INTEGER,
    last_check      TIMESTAMP,
    status          SMALLINT DEFAULT 1,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_nodes_sub ON nodes(subscription_id);
CREATE INDEX IF NOT EXISTS idx_nodes_region ON nodes(region);
CREATE INDEX IF NOT EXISTS idx_nodes_server ON nodes(server);
CREATE INDEX IF NOT EXISTS idx_nodes_latency ON nodes(latency);
CREATE INDEX IF NOT EXISTS idx_subs_user ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subs_token ON subscriptions(token);
CREATE INDEX IF NOT EXISTS idx_subs_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
