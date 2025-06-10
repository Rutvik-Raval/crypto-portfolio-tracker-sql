-- Script Name: 00_intermediary_01_transaction_value_distribution.sql
-- Purpose: Analyzes the distribution of BUY and SELL transaction values (USD).

WITH transaction_values AS (
    SELECT
        tx_id,
        tx_type,
        (quantity * price_per_unit_usd) AS transaction_value_usd
    FROM
        public.transactions
    WHERE
        tx_type IN ('BUY', 'SELL')
        AND price_per_unit_usd IS NOT NULL
        AND quantity IS NOT NULL
        AND quantity > 0
        AND price_per_unit_usd > 0 -- Consider only transactions with a positive value
),

-- Define value buckets
-- This can be adjusted based on your typical transaction sizes
value_buckets AS (
    SELECT
        tx_id,
        tx_type,
        transaction_value_usd,
        CASE
            WHEN transaction_value_usd >= 0 AND transaction_value_usd <= 100    THEN '000 - $0 - $100'
            WHEN transaction_value_usd > 100 AND transaction_value_usd <= 500   THEN '001 - $101 - $500'
            WHEN transaction_value_usd > 500 AND transaction_value_usd <= 1000  THEN '002 - $501 - $1,000'
            WHEN transaction_value_usd > 1000 AND transaction_value_usd <= 5000 THEN '003 - $1,001 - $5,000'
            WHEN transaction_value_usd > 5000 AND transaction_value_usd <= 10000 THEN '004 - $5,001 - $10,000'
            WHEN transaction_value_usd > 10000                                 THEN '005 - > $10,000'
            ELSE 'Other'
        END AS value_range
    FROM
        transaction_values
)

-- Count transactions in each bucket for BUYs and SELLs
SELECT
    vb.value_range,
    SUM(CASE WHEN vb.tx_type = 'BUY' THEN 1 ELSE 0 END) AS count_buy_transactions,
    SUM(CASE WHEN vb.tx_type = 'SELL' THEN 1 ELSE 0 END) AS count_sell_transactions
FROM
    value_buckets AS vb
GROUP BY
    vb.value_range
ORDER BY
    vb.value_range;