-- Script Name: 03_01_moving_averages.sql
-- Purpose: Calculates 7-day and 30-day simple moving averages (SMA)
--          for the close_price_usd of each cryptocurrency.

SELECT
    c.symbol,
    c.name,
    hp.price_date,
    hp.close_price_usd,
    -- Calculate 7-day SMA
    -- AVG(hp.close_price_usd) OVER (PARTITION BY hp.crypto_id ORDER BY hp.price_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS sma_7_day,
    -- The above is more precise for a rolling window. A simpler way if your data is dense:
    CASE
        WHEN COUNT(hp.close_price_usd) OVER (PARTITION BY hp.crypto_id ORDER BY hp.price_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) = 7
        THEN AVG(hp.close_price_usd) OVER (PARTITION BY hp.crypto_id ORDER BY hp.price_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
        ELSE NULL -- Don't calculate SMA if there aren't enough preceding days
    END AS sma_7_day,

    -- Calculate 30-day SMA
    CASE
        WHEN COUNT(hp.close_price_usd) OVER (PARTITION BY hp.crypto_id ORDER BY hp.price_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) = 30
        THEN AVG(hp.close_price_usd) OVER (PARTITION BY hp.crypto_id ORDER BY hp.price_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)
        ELSE NULL -- Don't calculate SMA if there aren't enough preceding days
    END AS sma_30_day
FROM
    public.historical_prices AS hp
JOIN
    public.cryptocurrencies AS c ON hp.crypto_id = c.crypto_id
-- Optional: Add a WHERE clause to focus on specific cryptos or a date range
-- Example: WHERE c.symbol = 'BTC' AND hp.price_date >= '2023-01-01'
ORDER BY
    c.symbol, hp.price_date DESC; -- Show latest dates first for each crypto