-- Script Name: 02_05_portfolio_value_change_daily.sql
-- Purpose: Calculates current portfolio value, portfolio value as of end of yesterday,
--          and the absolute and percentage change.

WITH
    -- Define relevant dates
    dates AS (
        SELECT
            (CURRENT_DATE - INTERVAL '1 day') AS yesterday_date, -- End of yesterday
            CURRENT_DATE AS today_for_latest_prices -- To define "current" consistently
            -- NOTE: If historical_prices are only updated once daily with previous day's close,
            -- then "current price" might actually be yesterday's close.
            -- Adjust `today_for_latest_prices` if your "current" price data point is different.
    ),

    -- CTE for holdings calculations (can be reused for current and historical)
    -- Parameters: p_target_date DATE
    -- This is a conceptual representation; for a single query, we'll call it for each date.

    -- Section A: Calculate holdings and value for YESTERDAY
    holdings_yesterday AS (
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
            public.transactions AS t, dates AS d
        WHERE
            DATE(t.tx_timestamp) <= d.yesterday_date -- Holdings up to end of yesterday
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

    prices_yesterday AS (
        SELECT
            hp.crypto_id,
            hp.close_price_usd
        FROM
            public.historical_prices AS hp, dates AS d
        WHERE hp.price_date = d.yesterday_date -- Prices exactly on yesterday's date
    ),

    value_yesterday AS (
        SELECT
            SUM(hy.holding_quantity * COALESCE(py.close_price_usd, 0)) AS total_value_usd
        FROM
            holdings_yesterday hy
        LEFT JOIN
            prices_yesterday py ON hy.crypto_id = py.crypto_id
    ),

    -- Section B: Calculate holdings and value for CURRENT state
    current_holdings AS (
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
            public.transactions AS t -- No date restriction for all transactions
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

    latest_prices_for_current_value AS (
        SELECT
            hp.crypto_id,
            hp.close_price_usd AS current_price_usd
        FROM
            public.historical_prices AS hp
        INNER JOIN (
            SELECT
                crypto_id,
                MAX(price_date) AS max_date -- Use the absolute latest price available
            FROM
                public.historical_prices
            GROUP BY
                crypto_id
        ) AS latest_dates ON hp.crypto_id = latest_dates.crypto_id AND hp.price_date = latest_dates.max_date
    ),

    current_value AS (
        SELECT
            SUM(ch.holding_quantity * COALESCE(lp.current_price_usd, 0)) AS total_value_usd
        FROM
            current_holdings ch
        LEFT JOIN
            latest_prices_for_current_value lp ON ch.crypto_id = lp.crypto_id
    )

-- Final Calculation: Compare current value with yesterday's value
SELECT
    COALESCE(cv.total_value_usd, 0) AS current_portfolio_value,
    COALESCE(vy.total_value_usd, 0) AS yesterday_portfolio_value,
    COALESCE(cv.total_value_usd, 0) - COALESCE(vy.total_value_usd, 0) AS absolute_change_usd,
    CASE
        WHEN COALESCE(vy.total_value_usd, 0) = 0 THEN NULL -- Avoid division by zero; show NULL if yesterday's value was 0
        ELSE ROUND(((COALESCE(cv.total_value_usd, 0) - COALESCE(vy.total_value_usd, 0)) / vy.total_value_usd) * 100, 2)
    END AS percentage_change
FROM
    current_value cv, value_yesterday vy; -- Cross join as they each produce one row