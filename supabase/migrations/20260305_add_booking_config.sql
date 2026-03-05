-- Create booking_config table for backend-managed booking configuration
CREATE TABLE IF NOT EXISTS booking_config (
    id text PRIMARY KEY DEFAULT 'default' CHECK (id = 'default'),
    supported_specializations_create jsonb NOT NULL DEFAULT '["automotive","real_estate","search_rescue"]'::jsonb,
    supported_specializations_edit jsonb NOT NULL DEFAULT '["automotive","real_estate"]'::jsonb,
    coming_soon_message text NOT NULL DEFAULT 'Launching in 2026! We are currently only supporting:

• Automotive
• Real Estate
• Search & Rescue',
    service_areas jsonb NOT NULL DEFAULT '[{"name":"Ithaca, NY","lat":42.4434,"lng":-76.5017,"radius_miles":100.0},{"name":"Ontario, Canada","lat":44.0,"lng":-79.5,"radius_miles":250.0},{"name":"British Columbia, Canada","lat":53.7267,"lng":-127.6476,"radius_miles":500.0}]'::jsonb,
    location_out_of_range_message text NOT NULL DEFAULT 'As a first to market app, we currently do not service your area. Please continue to check the app as we are growing and rolling out in many more locations in 2026',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Insert seed row with current hardcoded values
INSERT INTO booking_config (id) VALUES ('default')
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE booking_config ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read the config
CREATE POLICY "Authenticated users can read booking config"
    ON booking_config
    FOR SELECT
    TO authenticated
    USING (true);

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_booking_config_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER booking_config_updated_at
    BEFORE UPDATE ON booking_config
    FOR EACH ROW
    EXECUTE FUNCTION update_booking_config_updated_at();
