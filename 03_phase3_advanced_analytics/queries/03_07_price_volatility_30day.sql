-- Script Name: 03_07_price_volatility_30day.sql
-- Purpose: Calculates the 30-day rolling standard deviation of daily percentage returns
--          for the close_price_usd of each cryptocurrency, as a measure of volatility.

WITH
    -- Step 1: Calculate daily percentage returns
    daily_returns AS (
        SELECT
            hp.crypto_id,
            c.symbol,
            hp.price_date,
            hp.close_price_usd,
            -- Calculate previous day's close price using LAG()
            LAG(hp.close_price_usd, 1) OVER (PARTITION BY hp.crypto_id ORDER BY hp.price_date) AS prev_day_close_price_usd,
            -- Calculate daily return: (current_price - prev_price) / prev_price
            -- Handle cases where prev_day_close_price_usd is NULL (first day) or 0
            CASE
                WHEN LAG(hp.close_price_usd, 1) OVER (PARTITION BY hp.crypto_id ORDER BY hp.price_date) IS NOT NULL
                 AND LAG(hp.close_price_usd, 1) OVER (PARTITION BY hp.crypto_id ORDER BY hp.price_date) <> 0
                THEN (hp.close_price_usd - LAG(hp.close_price_usd, 1) OVER (PARTITION BY hp.crypto_id ORDER BY hp.price_date))
                     / LAG(hp.close_price_usd, 1) OVER (PARTITION BY hp.crypto_id ORDER BY hp.price_date)
                ELSE NULL -- No return can be calculated for the first day or if prev price is 0
            END AS daily_pct_return
        FROM
            public.historical_prices AS hp
        JOIN
            public.cryptocurrencies AS c ON hp.crypto_id = c.crypto_id
    )

-- Step 2: Calculate the 30-day rolling standard deviation of these daily returns
SELECT
    dr.symbol,
    dr.price_date,
    dr.close_price_usd,
    dr.daily_pct_return,
    -- Calculate 30-day rolling standard deviation of daily_pct_return
    -- STDDEV_SAMP for sample standard deviation, STDDEV_POP for population. Sample is common.
    CASE
        WHEN COUNT(dr.daily_pct_return) OVER (PARTITION BY dr.crypto_id ORDER BY dr.price_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) >= 30 -- Need at least 30 data points for a 30-day window
        THEN ROUND(STDDEV_SAMP(dr.daily_pct_return) OVER (
                        PARTITION BY dr.crypto_id
                        ORDER BY dr.price_date
                        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW -- Window of current day + 29 previous days
                     )::numeric, 6) -- Cast to numeric for ROUND, adjust precision as needed
        ELSE NULL -- Not enough data points for a 30-day volatility
    END AS volatility_30day_stddev_returns
FROM
    daily_returns AS dr
WHERE
    dr.daily_pct_return IS NOT NULL -- Only consider rows where a daily return could be calculated
-- Optional: Add a WHERE clause to focus on specific cryptos or a more recent date range
-- Example: WHERE dr.symbol = 'BTC' AND dr.price_date >= '2023-01-01'
ORDER BY
    dr.symbol, dr.price_date DESC;