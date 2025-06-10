-- Script Name: 00_intermediary_05_key_asset_price_range_check.sql
-- Purpose: Shows the earliest and latest recorded price for cryptocurrencies
--          from the historical_prices table, and the percentage change.

WITH
    -- CTE to find the first (earliest) recorded price for each crypto
    first_price AS (
        SELECT
            hp.crypto_id,
            hp.price_date AS first_date,
            hp.close_price_usd AS first_price_usd
        FROM
            public.historical_prices AS hp
        INNER JOIN (
            -- Subquery to determine the minimum (earliest) date for each crypto_id
            SELECT
                crypto_id,
                MIN(price_date) AS min_p_date
            FROM
                public.historical_prices
            GROUP BY
                crypto_id
        ) AS min_dates ON hp.crypto_id = min_dates.crypto_id AND hp.price_date = min_dates.min_p_date
        -- Optional filter if you only want this for specific cryptos and historical_prices is huge:
        -- WHERE hp.crypto_id IN (1, 2, 3) -- Example: IDs for BTC, ETH, SOL
    ),

    -- CTE to find the last (latest) recorded price for each crypto
    last_price AS (
        SELECT
            hp.crypto_id,
            hp.price_date AS last_date,
            hp.close_price_usd AS last_price_usd
        FROM
            public.historical_prices AS hp
        INNER JOIN (
            -- Subquery to determine the maximum (latest) date for each crypto_id
            SELECT
                crypto_id,
                MAX(price_date) AS max_p_date
            FROM
                public.historical_prices
            GROUP BY
                crypto_id
        ) AS max_dates ON hp.crypto_id = max_dates.crypto_id AND hp.price_date = max_dates.max_p_date
        -- Optional filter if you only want this for specific cryptos:
        -- WHERE hp.crypto_id IN (1, 2, 3)
    )

-- Final SELECT to combine the first and last price information
SELECT
    c.symbol,
    c.name,
    fp.first_date,
    fp.first_price_usd,
    lp.last_date,
    lp.last_price_usd,
    -- Calculate percentage change from first price to last price
    CASE
        WHEN fp.first_price_usd IS NOT NULL AND fp.first_price_usd <> 0 AND lp.last_price_usd IS NOT NULL
        THEN ROUND(((lp.last_price_usd - fp.first_price_usd) / fp.first_price_usd) * 100, 2) -- Calculate and round
        ELSE NULL -- Return NULL if first price is 0, NULL, or last price is NULL, to avoid errors or meaningless percentages
    END AS percentage_change
FROM
    public.cryptocurrencies AS c
JOIN
    first_price AS fp ON c.crypto_id = fp.crypto_id -- Join to get first price details
JOIN
    last_price AS lp ON c.crypto_id = lp.crypto_id  -- Join to get last price details
-- Optional: Add a WHERE clause here if you only want to see this for specific cryptos by symbol or ID
-- Example: WHERE c.symbol IN ('BTC', 'ETH', 'SOL')
ORDER BY
    c.symbol; -- Order results by symbol