SELECT COUNT(*) AS total_fact_rows FROM public.fact_transactions;

SELECT COUNT(*) AS dim_date_rows FROM public.dim_date;
SELECT COUNT(*) AS dim_cryptocurrency_rows FROM public.dim_cryptocurrency;
SELECT COUNT(*) AS dim_exchange_rows FROM public.dim_exchange;
SELECT COUNT(*) AS dim_transaction_category_rows FROM public.dim_transaction_category;

-- Check for NULL date_key (should be 0 rows if date_key is NOT NULL and ETL was successful)
SELECT COUNT(*) FROM public.fact_transactions WHERE date_key IS NULL;

-- Check for NULL crypto_key (should be 0 rows if crypto_key is NOT NULL and ETL was successful)
SELECT COUNT(*) FROM public.fact_transactions WHERE crypto_key IS NULL;

-- Check for NULL exchange_key (might have some if transactions can have NULL exchange_id)
SELECT COUNT(*) FROM public.fact_transactions WHERE exchange_key IS NULL AND tx_id_original IN (SELECT tx_id FROM public.transactions WHERE exchange_id IS NOT NULL);
-- The second part of the above query checks if there are NULL exchange_keys for transactions that DID have an exchange_id in the source.

-- Check for NULL category_key (might have some if transactions can have NULL category_id)
SELECT COUNT(*) FROM public.fact_transactions WHERE category_key IS NULL AND tx_id_original IN (SELECT tx_id FROM public.transactions WHERE category_id IS NOT NULL);




-- Simple Analytical Query on Star Schema:
-- Total transaction value by crypto symbol and year

SELECT
    dc.symbol AS crypto_symbol,
    dd.year_actual AS transaction_year,
    SUM(ft.transaction_value_usd) AS total_value_transacted_usd
FROM
    public.fact_transactions AS ft
JOIN
    public.dim_cryptocurrency AS dc ON ft.crypto_key = dc.crypto_key
JOIN
    public.dim_date AS dd ON ft.date_key = dd.date_key
WHERE
    ft.tx_type IN ('BUY', 'SELL') -- Or any other filter you like
GROUP BY
    dc.symbol,
    dd.year_actual
ORDER BY
    dc.symbol,
    dd.year_actual;