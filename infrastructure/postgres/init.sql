-- OpenNoiseNet Database Initialization Script
-- This script sets up the initial database schema with TimescaleDB extensions

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
-- PostGIS will be added later when using appropriate image
-- CREATE EXTENSION IF NOT EXISTS postgis CASCADE;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" CASCADE;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements CASCADE;

-- Keep clean-room Docker databases aligned with the schema represented in this
-- bootstrap script so Alembic-based checks do not fail before any migrations
-- are run in the container lifecycle.
CREATE TABLE IF NOT EXISTS alembic_version (
    version_num VARCHAR(32) PRIMARY KEY
);

DELETE FROM alembic_version;
INSERT INTO alembic_version (version_num)
VALUES ('c3e9d4f7ab21');

-- Users table for authentication
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255),
    full_name VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    is_superuser BOOLEAN DEFAULT false,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Devices table for registered sensors
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    device_type VARCHAR(64) NOT NULL DEFAULT 'smartphone',
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    -- location GEOGRAPHY(Point, 4326),  -- Requires PostGIS
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    address TEXT,
    firmware_version VARCHAR(50),
    hardware_info JSONB,
    calibration_offset REAL DEFAULT 0.0,
    is_active BOOLEAN DEFAULT true,
    is_public BOOLEAN DEFAULT false,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_heartbeat TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Events table for noise measurements.
-- Keep this as a regular table for the MVP bootstrap path. The previous
-- hypertable conversion conflicted with the UUID primary key and broke
-- first-start clean-room setups.
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_uuid VARCHAR(36) UNIQUE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    episode_id UUID,
    timestamp_start TIMESTAMP WITH TIME ZONE NOT NULL,
    timestamp_end TIMESTAMP WITH TIME ZONE NOT NULL,
    leq_db REAL NOT NULL,
    lmax_db REAL,
    lmin_db REAL,
    laeq_db REAL, -- A-weighted equivalent level
    exceedance_pct REAL,
    samples_count INTEGER,
    rule_triggered VARCHAR(100),
    -- location GEOGRAPHY(Point, 4326),  -- Requires PostGIS
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    weather_conditions JSONB,
    event_metadata JSONB,
    analysis_state VARCHAR(64) NOT NULL DEFAULT 'not_started',
    classification_label VARCHAR(100),
    classification_confidence REAL,
    classification_source VARCHAR(64),
    segment_type VARCHAR(64),
    reportability_score REAL,
    reportability_reason VARCHAR(255),
    peak_to_average_delta_db REAL,
    variability_db REAL,
    threshold_exceedance_ratio REAL,
    analysis_updated_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Audio snippets table (optional, encrypted)
CREATE TABLE audio_snippets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    codec VARCHAR(20) NOT NULL,
    duration_seconds INTEGER NOT NULL,
    sample_rate INTEGER NOT NULL,
    file_size_bytes INTEGER,
    file_path VARCHAR(500),
    encryption_key_hash VARCHAR(64),
    checksum VARCHAR(64),
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_processed BOOLEAN DEFAULT false
);

-- Event labels from AI classification
CREATE TABLE event_labels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    label VARCHAR(100) NOT NULL,
    confidence REAL NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
    model_version VARCHAR(50),
    model_type VARCHAR(50), -- 'yamnet', 'minicpm', 'custom'
    processing_time_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Device API keys for authentication
CREATE TABLE device_api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    key_hash VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    last_used TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE
);

-- System configuration table
CREATE TABLE system_config (
    id SERIAL PRIMARY KEY,
    key VARCHAR(100) UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Event aggregations for faster queries (materialized view)
CREATE TABLE event_aggregations (
    id SERIAL PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    time_bucket TIMESTAMP WITH TIME ZONE NOT NULL,
    bucket_duration VARCHAR(32) NOT NULL, -- '1 hour', '1 day', etc.
    avg_leq_db REAL,
    max_leq_db REAL,
    min_leq_db REAL,
    event_count INTEGER,
    exceedance_count INTEGER,
    exceedance_pct REAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Pro tenant boundary tables
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    plan_tier VARCHAR(32) NOT NULL DEFAULT 'pro_site',
    status VARCHAR(32) NOT NULL DEFAULT 'pilot',
    billing_state VARCHAR(32) NOT NULL DEFAULT 'trial',
    created_by_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE organization_memberships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(32) NOT NULL DEFAULT 'member',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_org_membership_org_user UNIQUE (organization_id, user_id)
);

CREATE TABLE sites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    timezone VARCHAR(64) NOT NULL DEFAULT 'UTC',
    address TEXT,
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    quiet_hours_start VARCHAR(5),
    quiet_hours_end VARCHAR(5),
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_zone_site_name UNIQUE (site_id, name)
);

CREATE TABLE policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    site_id UUID REFERENCES sites(id) ON DELETE CASCADE,
    zone_id UUID REFERENCES zones(id) ON DELETE CASCADE,
    scope_type VARCHAR(32) NOT NULL,
    name VARCHAR(255) NOT NULL,
    evidence_mode VARCHAR(32) NOT NULL DEFAULT 'derived_only',
    retention_days INTEGER NOT NULL DEFAULT 365,
    quiet_hours_start VARCHAR(5),
    quiet_hours_end VARCHAR(5),
    day_threshold_db REAL,
    night_threshold_db REAL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE calibration_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    site_id UUID REFERENCES sites(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    offset_db REAL NOT NULL DEFAULT 0.0,
    method VARCHAR(255),
    confidence REAL,
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE episodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    zone_id UUID REFERENCES zones(id) ON DELETE SET NULL,
    device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    policy_id UUID REFERENCES policies(id) ON DELETE SET NULL,
    primary_class VARCHAR(128) NOT NULL,
    class_family VARCHAR(128),
    review_label VARCHAR(128),
    classification_confidence REAL,
    severity VARCHAR(32) NOT NULL DEFAULT 'low',
    reviewed_severity VARCHAR(32),
    nuisance_score REAL NOT NULL DEFAULT 0.0,
    quiet_hours_triggered BOOLEAN DEFAULT false,
    evidence_mode VARCHAR(32) NOT NULL DEFAULT 'derived_only',
    review_state VARCHAR(32) NOT NULL DEFAULT 'pending_review',
    lifecycle_state VARCHAR(32) NOT NULL DEFAULT 'closed',
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ended_at TIMESTAMP WITH TIME ZONE NOT NULL,
    event_count INTEGER NOT NULL DEFAULT 1,
    review_notes TEXT,
    review_metadata JSONB,
    model_bundle_id VARCHAR(128),
    reviewed_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    exported_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE events
    ADD CONSTRAINT fk_events_episode_id_episodes
    FOREIGN KEY (episode_id) REFERENCES episodes(id) ON DELETE SET NULL;

CREATE TABLE cases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    zone_id UUID REFERENCES zones(id) ON DELETE SET NULL,
    opened_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'open',
    title VARCHAR(255) NOT NULL,
    summary TEXT,
    audit_history JSONB,
    closed_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
    last_status_changed_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
    last_status_changed_at TIMESTAMP WITH TIME ZONE,
    opened_at TIMESTAMP WITH TIME ZONE NOT NULL,
    closed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE case_episode_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    case_id UUID NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    episode_id UUID NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_case_episode_link UNIQUE (case_id, episode_id)
);

CREATE TABLE export_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    case_id UUID NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    created_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
    format VARCHAR(16) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'ready',
    file_name VARCHAR(255) NOT NULL,
    content_type VARCHAR(128) NOT NULL,
    output_text TEXT,
    output_encoding VARCHAR(32) NOT NULL DEFAULT 'utf-8',
    exported_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE devices
    ADD COLUMN site_id UUID REFERENCES sites(id) ON DELETE SET NULL,
    ADD COLUMN zone_id UUID REFERENCES zones(id) ON DELETE SET NULL,
    ADD COLUMN calibration_profile_id UUID REFERENCES calibration_profiles(id) ON DELETE SET NULL;

-- Create indexes for optimal query performance
-- Device indexes
CREATE INDEX idx_devices_device_id ON devices(device_id);
-- CREATE INDEX idx_devices_location ON devices USING GIST(location) WHERE location IS NOT NULL;
CREATE INDEX idx_devices_location_lat_lng ON devices(location_lat, location_lng) WHERE location_lat IS NOT NULL;
CREATE INDEX idx_devices_active ON devices(is_active) WHERE is_active = true;
CREATE INDEX idx_devices_last_seen ON devices(last_seen DESC);
CREATE INDEX idx_devices_owner ON devices(owner_id);
CREATE INDEX idx_devices_site ON devices(site_id);
CREATE INDEX idx_devices_zone ON devices(zone_id);
CREATE INDEX idx_devices_calibration_profile ON devices(calibration_profile_id);

-- Event indexes
CREATE INDEX idx_events_device_id_time ON events(device_id, timestamp_start DESC);
-- CREATE INDEX idx_events_location ON events USING GIST(location) WHERE location IS NOT NULL;
CREATE INDEX idx_events_location_lat_lng ON events(location_lat, location_lng) WHERE location_lat IS NOT NULL;
CREATE INDEX idx_events_leq_db ON events(leq_db);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_rule ON events(rule_triggered) WHERE rule_triggered IS NOT NULL;
CREATE INDEX idx_events_analysis_state ON events(analysis_state);
CREATE INDEX idx_events_classification_label ON events(classification_label) WHERE classification_label IS NOT NULL;
CREATE INDEX idx_events_episode_id ON events(episode_id) WHERE episode_id IS NOT NULL;

-- Audio snippet indexes
CREATE INDEX idx_audio_snippets_event_id ON audio_snippets(event_id);
CREATE INDEX idx_audio_snippets_expires ON audio_snippets(expires_at);
CREATE INDEX idx_audio_snippets_processed ON audio_snippets(is_processed);

-- Event labels indexes
CREATE INDEX idx_event_labels_event_id ON event_labels(event_id);
CREATE INDEX idx_event_labels_label ON event_labels(label);
CREATE INDEX idx_event_labels_confidence ON event_labels(confidence DESC);

-- API keys indexes
CREATE INDEX idx_device_api_keys_hash ON device_api_keys(key_hash);
CREATE INDEX idx_device_api_keys_device ON device_api_keys(device_id);
CREATE INDEX idx_device_api_keys_active ON device_api_keys(is_active) WHERE is_active = true;

-- Aggregation indexes
CREATE INDEX idx_aggregations_device_time ON event_aggregations(device_id, time_bucket DESC);
CREATE INDEX idx_aggregations_bucket_duration ON event_aggregations(bucket_duration, time_bucket DESC);

-- User indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_active ON users(is_active) WHERE is_active = true;
CREATE INDEX idx_organizations_slug ON organizations(slug);
CREATE INDEX idx_org_memberships_org ON organization_memberships(organization_id);
CREATE INDEX idx_org_memberships_user ON organization_memberships(user_id);
CREATE INDEX idx_sites_org ON sites(organization_id);
CREATE INDEX idx_zones_site ON zones(site_id);
CREATE INDEX idx_policies_org ON policies(organization_id) WHERE organization_id IS NOT NULL;
CREATE INDEX idx_policies_site ON policies(site_id) WHERE site_id IS NOT NULL;
CREATE INDEX idx_policies_zone ON policies(zone_id) WHERE zone_id IS NOT NULL;
CREATE INDEX idx_calibration_profiles_org ON calibration_profiles(organization_id);
CREATE INDEX idx_calibration_profiles_site ON calibration_profiles(site_id) WHERE site_id IS NOT NULL;
CREATE INDEX idx_episodes_org ON episodes(organization_id);
CREATE INDEX idx_episodes_site ON episodes(site_id);
CREATE INDEX idx_episodes_zone ON episodes(zone_id) WHERE zone_id IS NOT NULL;
CREATE INDEX idx_episodes_device ON episodes(device_id);
CREATE INDEX idx_episodes_policy ON episodes(policy_id) WHERE policy_id IS NOT NULL;
CREATE INDEX idx_episodes_reviewed_by ON episodes(reviewed_by_id) WHERE reviewed_by_id IS NOT NULL;
CREATE INDEX idx_cases_org ON cases(organization_id);
CREATE INDEX idx_cases_site ON cases(site_id);
CREATE INDEX idx_cases_zone ON cases(zone_id) WHERE zone_id IS NOT NULL;
CREATE INDEX idx_cases_opened_by ON cases(opened_by_id);
CREATE INDEX idx_case_episode_links_case ON case_episode_links(case_id);
CREATE INDEX idx_case_episode_links_episode ON case_episode_links(episode_id);
CREATE INDEX idx_export_jobs_case ON export_jobs(case_id);
CREATE INDEX idx_export_jobs_created_by ON export_jobs(created_by_id);
CREATE INDEX idx_cases_closed_by ON cases(closed_by_id) WHERE closed_by_id IS NOT NULL;
CREATE INDEX idx_cases_last_status_changed_by ON cases(last_status_changed_by_id) WHERE last_status_changed_by_id IS NOT NULL;

-- Create functions for data management
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organization_memberships_updated_at BEFORE UPDATE ON organization_memberships
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sites_updated_at BEFORE UPDATE ON sites
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_zones_updated_at BEFORE UPDATE ON zones
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_policies_updated_at BEFORE UPDATE ON policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_calibration_profiles_updated_at BEFORE UPDATE ON calibration_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_episodes_updated_at BEFORE UPDATE ON episodes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cases_updated_at BEFORE UPDATE ON cases
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_case_episode_links_updated_at BEFORE UPDATE ON case_episode_links
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_export_jobs_updated_at BEFORE UPDATE ON export_jobs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_devices_updated_at BEFORE UPDATE ON devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to clean up expired audio snippets
CREATE OR REPLACE FUNCTION cleanup_expired_snippets()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM audio_snippets WHERE expires_at < NOW();
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to create hourly aggregations
CREATE OR REPLACE FUNCTION create_hourly_aggregations(
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE
)
RETURNS INTEGER AS $$
DECLARE
    inserted_count INTEGER;
BEGIN
    INSERT INTO event_aggregations (
        device_id,
        time_bucket,
        bucket_duration,
        avg_leq_db,
        max_leq_db,
        min_leq_db,
        event_count,
        exceedance_count,
        exceedance_pct
    )
    SELECT 
        device_id,
        date_trunc('hour', timestamp_start) AS time_bucket,
        '1 hour' AS bucket_duration,
        AVG(leq_db) AS avg_leq_db,
        MAX(leq_db) AS max_leq_db,
        MIN(leq_db) AS min_leq_db,
        COUNT(*) AS event_count,
        COUNT(*) FILTER (WHERE exceedance_pct > 0) AS exceedance_count,
        AVG(exceedance_pct) AS exceedance_pct
    FROM events
    WHERE timestamp_start >= start_time 
      AND timestamp_start < end_time
      AND status = 'processed'
    GROUP BY device_id, date_trunc('hour', timestamp_start)
    ON CONFLICT DO NOTHING;
    
    GET DIAGNOSTICS inserted_count = ROW_COUNT;
    RETURN inserted_count;
END;
$$ LANGUAGE plpgsql;

-- Insert default system configuration
INSERT INTO system_config (key, value, description) VALUES
('noise_thresholds', '{"day_leq": 65, "night_leq": 55, "peak_threshold": 85}', 'Default noise level thresholds'),
('data_retention', '{"events_days": 365, "snippets_days": 7, "logs_days": 30}', 'Data retention policies'),
('map_settings', '{"default_zoom": 10, "max_zoom": 18, "cluster_radius": 50}', 'Map visualization settings'),
('ai_models', '{"primary": "minicpm-o-2.6", "fallback": "yamnet", "confidence_threshold": 0.7}', 'AI model configuration');

-- Create database views for common queries
CREATE VIEW public_devices AS
SELECT 
    d.device_id,
    d.name,
    d.device_type,
    d.location_lat,
    d.location_lng,
    d.address,
    d.is_active,
    d.last_seen,
    COALESCE(recent.event_count, 0) as recent_event_count,
    COALESCE(recent.avg_leq_db, 0) as recent_avg_leq
FROM devices d
LEFT JOIN (
    SELECT 
        device_id,
        COUNT(*) as event_count,
        AVG(leq_db) as avg_leq_db
    FROM events 
    WHERE timestamp_start >= NOW() - INTERVAL '24 hours'
    GROUP BY device_id
) recent ON d.id = recent.device_id
WHERE d.is_public = true AND d.is_active = true;

CREATE VIEW device_health AS
SELECT 
    d.device_id,
    d.name,
    d.last_seen,
    d.last_heartbeat,
    CASE 
        WHEN d.last_seen > NOW() - INTERVAL '1 hour' THEN 'online'
        WHEN d.last_seen > NOW() - INTERVAL '24 hours' THEN 'recent'
        ELSE 'offline'
    END as status,
    EXTRACT(EPOCH FROM (NOW() - d.last_seen))/3600 as hours_since_last_seen
FROM devices d
WHERE d.is_active = true;

-- Grant permissions for application user (will be created by the application)
-- These will be executed when the application starts
COMMENT ON DATABASE noisenet IS 'OpenNoiseNet environmental noise monitoring database';

-- Performance optimization: set appropriate work_mem for this database
-- ALTER DATABASE noisenet SET work_mem = '256MB';
