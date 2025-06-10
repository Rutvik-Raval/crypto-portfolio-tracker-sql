-- Script Name: 04_03_create_materialized_view_holdings_summary.sql
-- Purpose: Creates a materialized view to pre-calculate current cryptocurrency holdings.

-- Step 1: Create the Materialized View
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_current_holdings AS
WITH
    inflows AS (
        SELECT
            t.crypto_id,
            SUM(t.quantity) AS total_quantity_in
        FROM
            public.transactions AS t
        WHERE
            t.tx_type IN (
                'BUY', 'TRANSFER_IN', 'DEPOSIT',
                'AIRDROP', 'STAKING_REWARD', 'MINING_REWARD',
                'INTEREST_REWARD', 'LENDING_REWARD', 'GIFT_RECEIVED',
                'OTHER_INCOME'
            )
        GROUP BY
            t.crypto_id
    ),
    outflows AS (
        SELECT
            t.crypto_id,
            SUM(t.quantity) AS total_quantity_out
        FROM
            public.transactions AS t
        WHERE
            t.tx_type IN (
                'SELL', 'TRANSFER_OUT', 'WITHDRAWAL',
                'FEE_PAYMENT', 'GIFT_SENT',
                'OTHER_EXPENSE'
            )
        GROUP BY
            t.crypto_id
    )
SELECT
    c.crypto_id,
    c.symbol,
    c.name,
    (COALESCE(i.total_quantity_in, 0) - COALESCE(o.total_quantity_out, 0))::NUMERIC(28,18) AS current_holding_quantity -- Added explicit cast
FROM
    public.cryptocurrencies AS c
LEFT JOIN
    inflows AS i ON c.crypto_id = i.crypto_id
LEFT JOIN
    outflows AS o ON c.crypto_id = o.crypto_id
WHERE
    (COALESCE(i.total_quantity_in, 0) - COALESCE(o.total_quantity_out, 0)) > 0.000000000000000001
    
    
    
    --Test querying it (Run Seperately)
    SELECT * FROM public.mv_current_holdings ORDER BY symbol;
    
    