-- ============================================
-- CREATE RIDER WITHDRAWALS TABLE
-- ============================================
-- This table stores withdrawal requests from riders
-- Status flow: pending → completed (processed by admin)

CREATE TABLE IF NOT EXISTS rider_withdrawals (
    withdrawal_id BIGSERIAL PRIMARY KEY,
    rider_id BIGINT NOT NULL REFERENCES riders(rider_id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 100.00),
    withdrawal_method VARCHAR(50) DEFAULT 'Cash',
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
    requested_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP,
    notes TEXT
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_rider_withdrawals_rider_id ON rider_withdrawals(rider_id);
CREATE INDEX IF NOT EXISTS idx_rider_withdrawals_status ON rider_withdrawals(status);
CREATE INDEX IF NOT EXISTS idx_rider_withdrawals_requested_at ON rider_withdrawals(requested_at DESC);

-- Add comment to table
COMMENT ON TABLE rider_withdrawals IS 'Stores withdrawal requests from riders';
COMMENT ON COLUMN rider_withdrawals.amount IS 'Withdrawal amount (minimum 100.00)';
COMMENT ON COLUMN rider_withdrawals.status IS 'pending or completed';
COMMENT ON COLUMN rider_withdrawals.requested_at IS 'When rider requested withdrawal';
COMMENT ON COLUMN rider_withdrawals.processed_at IS 'When admin processed the withdrawal';

-- ============================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================
-- Uncomment below to insert sample data

/*
-- Example: Insert a completed withdrawal for rider_id 1
INSERT INTO rider_withdrawals (rider_id, amount, withdrawal_method, status, requested_at, processed_at, notes)
VALUES (1, 500.00, 'Cash', 'completed', NOW() - INTERVAL '5 days', NOW() - INTERVAL '3 days', 'First withdrawal');

-- Example: Insert a pending withdrawal for rider_id 1
INSERT INTO rider_withdrawals (rider_id, amount, withdrawal_method, status, requested_at, notes)
VALUES (1, 300.00, 'GCash', 'pending', NOW() - INTERVAL '1 day', 'Urgent withdrawal needed');
*/
