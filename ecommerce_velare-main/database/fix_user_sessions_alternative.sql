-- Alternative fix: Recreate user_sessions table without SERIAL
-- This avoids sequence permission issues by using Supabase's identity column

-- Drop existing table (backup data first if needed!)
-- DROP TABLE IF EXISTS user_sessions CASCADE;

-- Recreate with GENERATED ALWAYS AS IDENTITY instead of SERIAL
CREATE TABLE IF NOT EXISTS user_sessions (
    session_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    device_info TEXT,
    browser VARCHAR(100),
    os VARCHAR(100),
    ip_address VARCHAR(45),
    login_time TIMESTAMPTZ DEFAULT NOW(),
    last_activity TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users
CREATE POLICY "Users can view their own sessions"
    ON user_sessions FOR SELECT
    USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can insert their own sessions"
    ON user_sessions FOR INSERT
    WITH CHECK (auth.uid()::text = user_id::text);

CREATE POLICY "Users can update their own sessions"
    ON user_sessions FOR UPDATE
    USING (auth.uid()::text = user_id::text);

-- Create policy for service role (for backend operations)
CREATE POLICY "Service role has full access"
    ON user_sessions FOR ALL
    USING (true);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON user_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON user_sessions(is_active);

-- Add comment
COMMENT ON TABLE user_sessions IS 'Tracks user login sessions across multiple devices for security monitoring';

-- Grant permissions
GRANT ALL ON TABLE user_sessions TO authenticated;
GRANT ALL ON TABLE user_sessions TO service_role;
GRANT SELECT ON TABLE user_sessions TO anon;
