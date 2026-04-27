-- Test query to see what's being returned

-- Check what deliveries exist for a rider
SELECT 
  d.delivery_id,
  d.rider_id,
  d.status,
  o.order_number,
  o.order_received,
  o.order_status
FROM deliveries d
INNER JOIN orders o ON d.order_id = o.order_id
WHERE d.rider_id = 1  -- Replace with actual rider_id
ORDER BY d.assigned_at DESC;

-- Check specifically for delivered orders
SELECT 
  d.delivery_id,
  d.status,
  o.order_number,
  o.order_received,
  o.order_status
FROM deliveries d
INNER JOIN orders o ON d.order_id = o.order_id
WHERE d.rider_id = 1  -- Replace with actual rider_id
  AND d.status = 'delivered'
ORDER BY d.delivered_at DESC;

-- Test the exact filter logic
SELECT 
  d.delivery_id,
  d.status,
  o.order_number,
  o.order_received,
  o.order_status,
  CASE 
    WHEN d.status IN ('assigned', 'in_transit') THEN 'SHOULD SHOW'
    WHEN d.status = 'delivered' AND o.order_received = 0 THEN 'SHOULD SHOW'
    ELSE 'SHOULD NOT SHOW'
  END as should_show
FROM deliveries d
INNER JOIN orders o ON d.order_id = o.order_id
WHERE d.rider_id = 1  -- Replace with actual rider_id
  AND o.order_status != 'cancelled'
ORDER BY d.assigned_at DESC;
