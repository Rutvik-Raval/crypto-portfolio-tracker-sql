-- Script Name: 03_03_price_correlation_with_btc.sql
-- Purpose: Calculates the Pearson correlation coefficient for daily close prices
--          between Bitcoin (BTC) and every other cryptocurrency,
--          over their common available date range.

WITH
    -- Get BTC's daily prices
    btc_prices AS (
        SELECT
            hp.price_date,
            hp.close_price_usd AS btc_price_usd
        FROM
            public.historical_prices AS hp
        JOIN
            public.cryptocurrencies AS c ON hp.crypto_id = c.crypto_id
        WHERE
            c.symbol = 'BTC' -- Assuming 'BTC' is the symbol for Bitcoin
    ),

    -- Get daily prices for all other assets and join with BTC prices on common dates
    other_asset_prices_paired_with_btc AS (
        SELECT
            c_other.crypto_id AS other_crypto_id,
            c_other.symbol AS other_symbol,
            bp.price_date,
            hp_other.close_price_usd AS other_asset_price_usd,
            bp.btc_price_usd
        FROM
            btc_prices AS bp
        JOIN
            public.historical_prices AS hp_other ON bp.price_date = hp_other.price_date -- Join on common date
        JOIN
            public.cryptocurrencies AS c_other ON hp_other.crypto_id = c_other.crypto_id
        WHERE
            c_other.symbol <> 'BTC' -- Exclude BTC from being correlated with itself
    )

-- Calculate the correlation for each "other asset" with BTC
SELECT
    oap.other_symbol AS asset_symbol,
    COUNT(oap.price_date) AS common_data_points_with_btc, -- Number of days both had prices
    ROUND(CORR(oap.other_asset_price_usd, oap.btc_price_usd)::numeric, 4) AS correlation_with_btc
FROM
    other_asset_prices_paired_with_btc AS oap
GROUP BY
    oap.other_crypto_id, -- Group by the ID of the other asset
    oap.other_symbol
HAVING
    COUNT(oap.price_date) > 30 -- Only calculate if there are at least N common data points (e.g., 30 days)
ORDER BY
    -- Order by strength of correlation (absolute value), or by symbol
    ABS(CORR(oap.other_asset_price_usd, oap.btc_price_usd)) DESC NULLS LAST,
    oap.other_symbol;