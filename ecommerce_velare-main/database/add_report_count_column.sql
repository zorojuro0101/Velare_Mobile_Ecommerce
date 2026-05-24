-- Add report_count column to buyers, sellers, and riders tables for efficient tracking

-- Add report_count to buyers table
ALTER TABLE buyers 
ADD COLUMN IF NOT EXISTS report_count INT DEFAULT 0;

-- Add report_count to sellers table
ALTER TABLE sellers 
ADD COLUMN IF NOT EXISTS report_count INT DEFAULT 0;

-- Add report_count to riders table
ALTER TABLE riders 
ADD COLUMN IF NOT EXISTS report_count INT DEFAULT 0;

-- Update existing report counts for buyers
UPDATE buyers b
SET report_count = (
    SELECT COUNT(*) 
    FROM user_reports ur 
    WHERE ur.reported_user_id = b.user_id 
    AND ur.reported_user_type = 'buyer'
);

-- Update existing report counts for sellers
UPDATE sellers s
SET report_count = (
    SELECT COUNT(*) 
    FROM user_reports ur 
    WHERE ur.reported_user_id = s.user_id 
    AND ur.reported_user_type = 'seller'
);

-- Update existing report counts for riders
UPDATE riders r
SET report_count = (
    SELECT COUNT(*) 
    FROM user_reports ur 
    WHERE ur.reported_user_id = r.user_id 
    AND ur.reported_user_type = 'rider'
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_reports_reported_user 
ON user_reports(reported_user_id, reported_user_type);

SELECT 'Report count columns added and updated successfully!' as status;
