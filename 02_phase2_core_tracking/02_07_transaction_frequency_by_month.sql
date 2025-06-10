-- Script Name: 02_07_transaction_frequency_by_month.sql
-- Purpose: Calculates the frequency of transactions (total, buys, sells) per month.

WITH
    -- Extract year and month from transaction timestamps
    monthly_transactions AS (
        SELECT
            tx_id,
            tx_type,
            DATE_TRUNC('month', tx_timestamp) AS transaction_month -- Truncates to the first day of the month
        FROM
            public.transactions
    )

-- Aggregate counts per month
SELECT
    TO_CHAR(mt.transaction_month, 'YYYY-MM') AS year_month, -- Format month for readability
    COUNT(mt.tx_id) AS total_transactions_in_month,
    SUM(CASE WHEN mt.tx_type = 'BUY' THEN 1 ELSE 0 END) AS buy_transactions,
    SUM(CASE WHEN mt.tx_type = 'SELL' THEN 1 ELSE 0 END) AS sell_transactions,
    SUM(CASE WHEN mt.tx_type NOT IN ('BUY', 'SELL') THEN 1 ELSE 0 END) AS other_transactions
FROM
    monthly_transactions AS mt
GROUP BY
    mt.transaction_month
ORDER BY
    mt.transaction_month DESC; -- Show most recent months first