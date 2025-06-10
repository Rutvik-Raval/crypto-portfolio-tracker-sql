-- Script Name: 03_02_relative_strength_index_14day.sql
-- Purpose: Calculates the 14-period Relative Strength Index (RSI)
--          for the close_price_usd of each cryptocurrency.
--          This version uses Simple Moving Averages for average gain/loss.

WITH
    -- Step 1: Calculate daily price changes (Gain or Loss)
    price_changes AS (
        SELECT
            hp.crypto_id,
            c.symbol,
            c.name,
            hp.price_date,
            hp.close_price_usd,
            -- Calculate the difference from the previous day's close price
            hp.close_price_usd - LAG(hp.close_price_usd, 1, hp.close_price_usd) OVER (PARTITION BY hp.crypto_id ORDER BY hp.price_date) AS price_diff,
            -- Identify if it's a gain (positive diff) or loss (negative diff for calculation, but we take absolute for avg loss)
            GREATEST(0, hp.close_price_usd - LAG(hp.close_price_usd, 1, hp.close_price_usd) OVER (PARTITION BY hp.crypto_id ORDER BY hp.price_date)) AS gain,
            GREATEST(0, LAG(hp.close_price_usd, 1, hp.close_price_usd) OVER (PARTITION BY hp.crypto_id ORDER BY hp.price_date) - hp.close_price_usd) AS loss
            -- LAG(..., 1, hp.close_price_usd) fills the first day's previous price with current price, making diff 0.
        FROM
            public.historical_prices AS hp
        JOIN
            public.cryptocurrencies AS c ON hp.crypto_id = c.crypto_id
    ),

    -- Step 2: Calculate Average Gain and Average Loss over the RSI period (e.g., 14 days)
    -- using a simple moving average for this implementation.
    avg_gains_losses AS (
        SELECT
            crypto_id,
            symbol,
            name,
            price_date,
            close_price_usd,
            price_diff,
            gain,
            loss,
            -- Calculate 14-period SMA of gains
            CASE
                WHEN ROW_NUMBER() OVER (PARTITION BY crypto_id ORDER BY price_date) >= 14
                THEN AVG(gain) OVER (PARTITION BY crypto_id ORDER BY price_date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW)
                ELSE NULL
            END AS avg_gain_14,
            -- Calculate 14-period SMA of losses
            CASE
                WHEN ROW_NUMBER() OVER (PARTITION BY crypto_id ORDER BY price_date) >= 14
                THEN AVG(loss) OVER (PARTITION BY crypto_id ORDER BY price_date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW)
                ELSE NULL
            END AS avg_loss_14
        FROM
            price_changes
    )

-- Step 3 & 4: Calculate Relative Strength (RS) and RSI
SELECT
    symbol,
    name,
    price_date,
    close_price_usd,
    price_diff,
    gain,
    loss,
    avg_gain_14,
    avg_loss_14,
    -- Calculate RS = Average Gain / Average Loss
    -- Handle cases where avg_loss_14 is 0 to avoid division by zero (RSI would be 100)
    CASE
        WHEN avg_loss_14 = 0 THEN NULL -- Or some indicator of very strong upward momentum, RSI will be 100
        ELSE avg_gain_14 / avg_loss_14
    END AS rs_14,
    -- Calculate RSI = 100 - (100 / (1 + RS))
    CASE
        WHEN avg_loss_14 = 0 THEN 100 -- If avg_loss is 0, RSI is 100
        WHEN avg_gain_14 IS NULL OR avg_loss_14 IS NULL THEN NULL -- Not enough data
        ELSE ROUND(100 - (100 / (1 + (avg_gain_14 / avg_loss_14))), 2)
    END AS rsi_14
FROM
    avg_gains_losses
WHERE
    -- Only show rows where RSI can be calculated (i.e., after the initial 14 periods)
    avg_gain_14 IS NOT NULL AND avg_loss_14 IS NOT NULL
-- Optional: Add a WHERE clause to focus on specific cryptos or a date range
-- Example: WHERE symbol = 'BTC' AND price_date >= '2023-01-01'
ORDER BY
    symbol, price_date DESC;