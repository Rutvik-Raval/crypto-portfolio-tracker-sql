-- Script Name: 04_05_data_quality_checks.sql
-- Purpose: Contains various SQL queries to check for potential data quality issues
--          in the portfolio tracker database. Run these queries individually.

-- DQ Check 1: Transactions with Potentially Missing or Zero Prices
-- Description: Identifies BUY/SELL/FEE_PAYMENT transactions that are missing a price
--              or have a zero/negative price, which might indicate data entry errors
--              or missing price information.
SELECT
    t.tx_id,
    t.tx_type,
    c.symbol,
    t.tx_timestamp,
    t.quantity,
    t.price_per_unit_usd,
    t.notes
FROM
    public.transactions t
JOIN
    public.cryptocurrencies c ON t.crypto_id = c.crypto_id
WHERE
    t.tx_type IN ('BUY', 'SELL', 'FEE_PAYMENT') -- Add other types if price is always expected
    AND (t.price_per_unit_usd IS NULL OR t.price_per_unit_usd <= 0)
ORDER BY
    t.tx_timestamp DESC;


-- DQ Check 2: Transactions with Unusually High or Low Transaction Values
-- Description: Flags transactions with extremely high or unusually small (but non-zero)
--              USD values, which could be typos or outliers needing review.
--              Thresholds are examples and should be adjusted.
WITH transaction_values AS (
    SELECT
        tx_id,
        tx_type,
        crypto_id,
        tx_timestamp,
        notes,
        (quantity * price_per_unit_usd) AS transaction_value_usd
    FROM
        public.transactions
    WHERE
        price_per_unit_usd IS NOT NULL AND quantity IS NOT NULL
)
SELECT
    tv.tx_id,
    tv.tx_type,
    c.symbol,
    tv.tx_timestamp,
    tv.transaction_value_usd,
    tv.notes
FROM
    transaction_values tv
JOIN
    public.cryptocurrencies c ON tv.crypto_id = c.crypto_id
WHERE
    tv.transaction_value_usd > 1000000 -- Example: Flag transactions over $1M
    OR (tv.transaction_value_usd > 0 AND tv.transaction_value_usd < 0.01) -- Example: Flag very small positive value transactions
ORDER BY
    ABS(tv.transaction_value_usd) DESC;


-- DQ Check 3: Cryptocurrencies in `transactions` but missing from `cryptocurrencies` table
-- Description: Lists crypto_ids found in the transactions table that do not have a
--              corresponding entry in the cryptocurrencies table. This indicates an
--              orphan record and a data integrity issue if the FK is not enforced or was disabled.
SELECT DISTINCT
    t.crypto_id AS missing_crypto_id_in_transactions
FROM
    public.transactions t
LEFT JOIN
    public.cryptocurrencies c ON t.crypto_id = c.crypto_id
WHERE
    c.crypto_id IS NULL;


-- DQ Check 4: Exchanges in `transactions` but missing from `exchanges` table
-- Description: Lists exchange_ids found in the transactions table that do not have a
--              corresponding entry in the exchanges table. Indicates an orphan record if FK is not enforced.
SELECT DISTINCT
    t.exchange_id AS missing_exchange_id_in_transactions
FROM
    public.transactions t
LEFT JOIN
    public.exchanges e ON t.exchange_id = e.exchange_id
WHERE
    e.exchange_id IS NULL
    AND t.exchange_id IS NOT NULL; -- Only show if exchange_id was actually set in transactions


-- DQ Check 5: Assets held (positive current balance) but with no recent price data
-- Description: Identifies assets currently held in the portfolio for which there is no price data
--              at all in historical_prices, or the latest price data is older than a defined
--              threshold (e.g., 7 days). This impacts valuation accuracy.
WITH current_holdings_simple AS (
    SELECT
        t.crypto_id,
        SUM(CASE
                WHEN t.tx_type IN ('BUY', 'TRANSFER_IN', 'DEPOSIT', 'AIRDROP', 'STAKING_REWARD', 'MINING_REWARD', 'INTEREST_REWARD', 'LENDING_REWARD', 'GIFT_RECEIVED', 'OTHER_INCOME') THEN t.quantity
                ELSE 0
            END) -
        SUM(CASE
                WHEN t.tx_type IN ('SELL', 'TRANSFER_OUT', 'WITHDRAWAL', 'FEE_PAYMENT', 'GIFT_SENT', 'OTHER_EXPENSE') THEN t.quantity
                ELSE 0
            END) AS holding_quantity
    FROM
        public.transactions AS t
    GROUP BY
        t.crypto_id
    HAVING
        SUM(CASE
                WHEN t.tx_type IN ('BUY', 'TRANSFER_IN', 'DEPOSIT', 'AIRDROP', 'STAKING_REWARD', 'MINING_REWARD', 'INTEREST_REWARD', 'LENDING_REWARD', 'GIFT_RECEIVED', 'OTHER_INCOME') THEN t.quantity
                ELSE 0
            END) -
        SUM(CASE
                WHEN t.tx_type IN ('SELL', 'TRANSFER_OUT', 'WITHDRAWAL', 'FEE_PAYMENT', 'GIFT_SENT', 'OTHER_EXPENSE') THEN t.quantity
                ELSE 0
            END) > 0.000000000000000001
),
last_price_date_per_asset AS (
    SELECT
        crypto_id,
        MAX(price_date) AS last_price_update
    FROM
        public.historical_prices
    GROUP BY
        crypto_id
)
SELECT
    c.symbol,
    c.name,
    ch.holding_quantity,
    lpd.last_price_update
FROM
    current_holdings_simple ch
JOIN
    public.cryptocurrencies c ON ch.crypto_id = c.crypto_id
LEFT JOIN
    last_price_date_per_asset lpd ON ch.crypto_id = lpd.crypto_id
WHERE
    lpd.last_price_update IS NULL -- No price data at all
    OR lpd.last_price_update < (CURRENT_DATE - INTERVAL '7 days') -- Or last price is older than 7 days (adjust interval as needed)
ORDER BY
    c.symbol;

-- DQ Check 6: Gaps in daily historical price data for an asset
-- Description: For a specific crypto_id, lists dates for which price data is missing
--              between its earliest and latest recorded price date. This requires
--              changing the crypto_id in the query manually.
WITH RECURSIVE
  expected_dates(dt) AS (
    SELECT MIN(price_date) FROM public.historical_prices WHERE crypto_id = 1 -- <<-- Set target crypto_id. Output is DATE.
    UNION ALL
    SELECT (dt + INTERVAL '1 day')::DATE FROM expected_dates -- Cast result of DATE + INTERVAL back to DATE
    WHERE (dt + INTERVAL '1 day')::DATE <= (SELECT MAX(price_date) FROM public.historical_prices WHERE crypto_id = 1) -- <<-- Set target crypto_id, ensure comparison is also DATE
  )
SELECT
  (SELECT symbol FROM public.cryptocurrencies WHERE crypto_id = 1) AS symbol, -- <<-- Set target crypto_id
  ed.dt AS missing_price_date
FROM expected_dates ed
LEFT JOIN public.historical_prices hp
  ON ed.dt = hp.price_date AND hp.crypto_id = 1 -- <<-- Set target crypto_id
WHERE hp.price_date IS NULL
ORDER BY ed.dt;