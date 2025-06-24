-- Script d'initialisation pour Apache Polaris avec PostgreSQL
-- Ce script sera exécuté au démarrage du conteneur PostgreSQL

-- Création des extensions nécessaires
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Configuration des paramètres PostgreSQL pour Polaris
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_min_duration_statement = 1000;
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;

-- Création d'un utilisateur supplémentaire pour la lecture seule
CREATE USER polaris_readonly WITH PASSWORD 'readonly123';
GRANT CONNECT ON DATABASE polaris TO polaris_readonly;
GRANT USAGE ON SCHEMA public TO polaris_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO polaris_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO polaris_readonly;

-- Création des index pour optimiser les performances
-- Ces index seront créés sur les tables une fois qu'elles existent

-- Table pour stocker les métadonnées de schéma
CREATE TABLE IF NOT EXISTS polaris_schema_version (
    id SERIAL PRIMARY KEY,
    version VARCHAR(50) NOT NULL,
    description TEXT,
    installed_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertion de la version initiale
INSERT INTO polaris_schema_version (version, description)
VALUES ('1.0.0', 'Initial Polaris schema setup')
ON CONFLICT DO NOTHING;

-- Création d'une table de configuration pour Polaris
CREATE TABLE IF NOT EXISTS polaris_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(255) NOT NULL UNIQUE,
    config_value TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Configuration par défaut
INSERT INTO polaris_config (config_key, config_value, description) VALUES
('catalog.default.warehouse', 's3://polaris-warehouse', 'Default warehouse location'),
('catalog.default.database', 'default', 'Default database name'),
('auth.token.expiry', '86400', 'Token expiry in seconds'),
('cache.metadata.ttl', '3600', 'Metadata cache TTL in seconds')
ON CONFLICT (config_key) DO NOTHING;

-- Trigger pour mettre à jour automatiquement updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_polaris_config_updated_at
    BEFORE UPDATE ON polaris_config
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Création d'une vue pour les statistiques
CREATE OR REPLACE VIEW polaris_stats AS
SELECT
    schemaname,
    tablename,
    attname,
    n_distinct,
    most_common_vals::text AS most_common_vals_text,
    most_common_freqs::text AS most_common_freqs_text,
    histogram_bounds::text AS histogram_bounds_text
FROM pg_stats
WHERE schemaname = 'public'
  AND tablename LIKE 'polaris_%';

-- Ajout de commentaires pour la documentation
COMMENT ON DATABASE polaris IS 'Apache Polaris catalog database';
COMMENT ON TABLE polaris_config IS 'Configuration settings for Polaris';
COMMENT ON TABLE polaris_schema_version IS 'Database schema version tracking';

-- Création d'un rôle pour les applications
CREATE ROLE polaris_app;
GRANT CONNECT ON DATABASE polaris TO polaris_app;
GRANT USAGE ON SCHEMA public TO polaris_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO polaris_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO polaris_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO polaris_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO polaris_app;

-- Accorder les permissions au rôle d'application
GRANT polaris_app TO polaris;

COMMIT;
