-- Script Name: 00_intermediary_03_transactions_per_month.sql
-- Purpose: Counts the total number of transactions per calendar month.

SELECT
    TO_CHAR(DATE_TRUNC('month', tx_timestamp), 'YYYY-MM') AS transaction_year_month,
    COUNT(tx_id) AS total_transactions
FROM
    public.transactions
GROUP BY
    DATE_TRUNC('month', tx_timestamp)
ORDER BY
    transaction_year_month DESC; -- Show most recent months first, or ASC for chronological