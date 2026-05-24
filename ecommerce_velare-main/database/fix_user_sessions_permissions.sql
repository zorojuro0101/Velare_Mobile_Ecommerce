-- Fix permissions for user_sessions table and sequence
-- Run this in your Supabase SQL Editor

-- Grant permissions on the table
GRANT ALL ON TABLE user_sessions TO authenticated;
GRANT ALL ON TABLE user_sessions TO service_role;
GRANT ALL ON TABLE user_sessions TO anon;

-- Grant USAGE and SELECT permissions on the sequence
GRANT USAGE, SELECT ON SEQUENCE user_sessions_session_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE user_sessions_session_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE user_sessions_session_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE user_sessions_session_id_seq TO postgres;

-- Verify permissions on table
SELECT 
    grantee, 
    privilege_type 
FROM information_schema.role_table_grants 
WHERE table_name='user_sessions';

-- Verify permissions on sequence
SELECT 
    grantee, 
    privilege_type 
FROM information_schema.role_usage_grants 
WHERE object_name='user_sessions_session_id_seq';

-- Additional check: Verify sequence permissions with SELECT
SELECT 
    grantee, 
    privilege_type 
FROM information_schema.role_table_grants 
WHERE table_name='user_sessions_session_id_seq';
