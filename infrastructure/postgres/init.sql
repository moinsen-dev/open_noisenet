-- OpenNoiseNet Database Initialization Script
-- This script sets up the initial database schema with TimescaleDB extensions

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
-- PostGIS will be added later when using appropriate image
-- CREATE EXTENSION IF NOT EXISTS postgis CASCADE;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" CASCADE;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements CASCADE;

-- Create custom data types
CREATE TYPE device_type_enum AS ENUM ('smartphone', 'esp32', 'raspberry_pi', 'custom');
CREATE TYPE event_status_enum AS ENUM ('pending', 'processed', 'failed');

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
    device_type device_type_enum NOT NULL DEFAULT 'smartphone',
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

-- Events table for noise measurements (hypertable)
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
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
    status event_status_enum DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Convert events to hypertable for time-series optimization
SELECT create_hypertable('events', 'timestamp_start', 
    chunk_time_interval => INTERVAL '1 day',
    create_default_indexes => false
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

-- Convert audio_snippets to hypertable
SELECT create_hypertable('audio_snippets', 'uploaded_at',
    chunk_time_interval => INTERVAL '1 day',
    create_default_indexes => false
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
    bucket_duration INTERVAL NOT NULL, -- '1 hour', '1 day', etc.
    avg_leq_db REAL,
    max_leq_db REAL,
    min_leq_db REAL,
    event_count INTEGER,
    exceedance_count INTEGER,
    exceedance_pct REAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Convert aggregations to hypertable
SELECT create_hypertable('event_aggregations', 'time_bucket',
    chunk_time_interval => INTERVAL '7 days',
    create_default_indexes => false
);

-- Create indexes for optimal query performance
-- Device indexes
CREATE INDEX idx_devices_device_id ON devices(device_id);
-- CREATE INDEX idx_devices_location ON devices USING GIST(location) WHERE location IS NOT NULL;
CREATE INDEX idx_devices_location_lat_lng ON devices(location_lat, location_lng) WHERE location_lat IS NOT NULL;
CREATE INDEX idx_devices_active ON devices(is_active) WHERE is_active = true;
CREATE INDEX idx_devices_last_seen ON devices(last_seen DESC);
CREATE INDEX idx_devices_owner ON devices(owner_id);

-- Event indexes
CREATE INDEX idx_events_device_id_time ON events(device_id, timestamp_start DESC);
-- CREATE INDEX idx_events_location ON events USING GIST(location) WHERE location IS NOT NULL;
CREATE INDEX idx_events_location_lat_lng ON events(location_lat, location_lng) WHERE location_lat IS NOT NULL;
CREATE INDEX idx_events_leq_db ON events(leq_db);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_rule ON events(rule_triggered) WHERE rule_triggered IS NOT NULL;

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

CREATE TRIGGER update_devices_updated_at BEFORE UPDATE ON devices
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
        INTERVAL '1 hour' AS bucket_duration,
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
    d.location,
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