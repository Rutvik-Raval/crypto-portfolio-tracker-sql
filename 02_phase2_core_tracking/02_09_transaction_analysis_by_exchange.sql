-- Script Name: 02_09_transaction_analysis_by_exchange.sql
-- Purpose: Analyzes transaction patterns by exchange, showing counts of
--          total transactions, BUYs, SELLs, and total USD value of BUYs/SELLs.

SELECT
    e.name AS exchange_name, -- Using e.name, aliased for clear output
    COUNT(t.tx_id) AS total_transactions,
    SUM(CASE WHEN t.tx_type = 'BUY' THEN 1 ELSE 0 END) AS count_buy_transactions,
    SUM(CASE WHEN t.tx_type = 'SELL' THEN 1 ELSE 0 END) AS count_sell_transactions,
    SUM(CASE WHEN t.tx_type NOT IN ('BUY', 'SELL') THEN 1 ELSE 0 END) AS count_other_transactions,

    -- Calculate total USD value for BUYs
    COALESCE(SUM(CASE
        WHEN t.tx_type = 'BUY' AND t.price_per_unit_usd IS NOT NULL AND t.quantity IS NOT NULL
        THEN t.quantity * t.price_per_unit_usd
        ELSE 0 -- Ensure a numeric value is summed even if conditions aren't met for a row
    END), 0) AS total_buy_value_usd,

    -- Calculate total USD value for SELLs
    COALESCE(SUM(CASE
        WHEN t.tx_type = 'SELL' AND t.price_per_unit_usd IS NOT NULL AND t.quantity IS NOT NULL
        THEN t.quantity * t.price_per_unit_usd
        ELSE 0 -- Ensure a numeric value is summed
    END), 0) AS total_sell_value_usd
FROM
    public.transactions AS t
JOIN
    public.exchanges AS e ON t.exchange_id = e.exchange_id -- INNER JOIN to only include transactions on known exchanges
GROUP BY
    e.name -- Group by the actual name column from the exchanges table
ORDER BY
    total_transactions DESC; -- Show most active exchanges first