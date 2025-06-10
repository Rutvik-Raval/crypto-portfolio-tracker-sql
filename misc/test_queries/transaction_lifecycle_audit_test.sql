-- File: transaction_lifecycle_audit_test.sql
-- Author: Rutvik Raval
-- Date: 2023-10-27 (or current date)
--
-- Description:
-- This script tests the full lifecycle (INSERT, UPDATE, DELETE) of a transaction
-- in the 'public.transactions' table and observes the corresponding entries
-- in the 'public.transactions_audit_history' table.
--
-- !!! IMPORTANT !!!
-- Execute these statements/blocks ONE AFTER ANOTHER sequentially from top to bottom.
-- Each block may depend on the previous one, or is designed to show the state
-- of the database after a specific operation.
-- For example, the SELECTs from the audit history are meant to be run
-- immediately after the preceding DML operation.
-- -----------------------------------------------------------------------------

-- 1. INSERT a new transaction and get its ID
INSERT INTO public.transactions (
    crypto_id, exchange_id, category_id, tx_type, quantity,
    price_per_unit_usd, tx_timestamp, fee_usd, notes
) VALUES (
    1, 1, 1, 'BUY', 0.005,
    60000.00, NOW() - INTERVAL '30 minutes', 0.50, 'Test audit INSERT ' || NOW()::TEXT
)
RETURNING tx_id; -- This will show you the tx_id of the inserted row (e.g., in the DBeaver output panel)

-- 2. CHECK audit history after INSERT
SELECT *
FROM public.transactions_audit_history
ORDER BY operation_timestamp DESC
LIMIT 5;

-- 3. UPDATE the newly inserted transaction (or a specific one)
--    NOTE: For this example, tx_id = 1 is hardcoded.
--    If you want to use the ID from the INSERT above, you'd typically
--    capture it in a variable or manually use the returned tx_id.
UPDATE public.transactions
SET notes = 'Test audit UPDATE - notes changed ' || NOW()::TEXT,
    fee_usd = 0.75
WHERE tx_id = 1; -- Use the actual tx_id from your insert if testing that specific row

-- 4. CHECK audit history after UPDATE
SELECT *
FROM public.transactions_audit_history
ORDER BY operation_timestamp DESC
LIMIT 5;

-- 5. DELETE a transaction
--    NOTE: For this example, tx_id = 180 is hardcoded.
DELETE FROM public.transactions
WHERE tx_id = 180; -- Use the tx_id you want to delete (e.g., 180, or the one inserted)

-- 6. CHECK audit history after DELETE
SELECT *
FROM public.transactions_audit_history
ORDER BY operation_timestamp DESC
LIMIT 5;