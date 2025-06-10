-- Script Name: 02_06_portfolio_value_change_between_dates.sql
-- Purpose: Calculates portfolio value at a specified start date and end date,
--          and the absolute and percentage change between them.

WITH
    -- Define the start and end dates for the analysis period
    analysis_period AS (
        SELECT
            '2024-11-04'::DATE AS start_date, -- Value at the END of this day
            '2024-11-07'::DATE AS end_date    -- Value at the END of this day
    ),

    -- Function to calculate holdings as of a specific date
    -- (This is conceptual for a CTE; in reality, we repeat the logic or use a real SQL function)
    -- For this query, we'll define two sets of CTEs for holdings and prices for each date.

    -- Section A: Calculate holdings and value for START_DATE
    holdings_at_start_date AS (
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
            public.transactions AS t, analysis_period AS ap
        WHERE
            DATE(t.tx_timestamp) <= ap.start_date -- Holdings up to end of start_date
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

    prices_at_start_date AS (
        SELECT
            hp.crypto_id,
            hp.close_price_usd
        FROM
            public.historical_prices AS hp, analysis_period AS ap
        WHERE hp.price_date = ap.start_date -- Prices exactly on start_date
    ),

    value_at_start_date AS (
        SELECT
            SUM(h_start.holding_quantity * COALESCE(p_start.close_price_usd, 0)) AS total_value_usd
        FROM
            holdings_at_start_date h_start
        LEFT JOIN
            prices_at_start_date p_start ON h_start.crypto_id = p_start.crypto_id
    ),

    -- Section B: Calculate holdings and value for END_DATE
    holdings_at_end_date AS (
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
            public.transactions AS t, analysis_period AS ap
        WHERE
            DATE(t.tx_timestamp) <= ap.end_date -- Holdings up to end of end_date
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

    prices_at_end_date AS (
        SELECT
            hp.crypto_id,
            hp.close_price_usd
        FROM
            public.historical_prices AS hp, analysis_period AS ap
        WHERE hp.price_date = ap.end_date -- Prices exactly on end_date
    ),

    value_at_end_date AS (
        SELECT
            SUM(h_end.holding_quantity * COALESCE(p_end.close_price_usd, 0)) AS total_value_usd
        FROM
            holdings_at_end_date h_end
        LEFT JOIN
            prices_at_end_date p_end ON h_end.crypto_id = p_end.crypto_id
    )

-- Final Calculation: Compare end_date value with start_date value
SELECT
    ap.start_date,
    ap.end_date,
    COALESCE(v_start.total_value_usd, 0) AS portfolio_value_at_start_date,
    COALESCE(v_end.total_value_usd, 0) AS portfolio_value_at_end_date,
    COALESCE(v_end.total_value_usd, 0) - COALESCE(v_start.total_value_usd, 0) AS absolute_change_usd,
    CASE
        WHEN COALESCE(v_start.total_value_usd, 0) = 0 THEN NULL -- Avoid division by zero
        ELSE ROUND(((COALESCE(v_end.total_value_usd, 0) - COALESCE(v_start.total_value_usd, 0)) / v_start.total_value_usd) * 100, 2)
    END AS percentage_change
FROM
    analysis_period ap,
    value_at_start_date v_start,
    value_at_end_date v_end; -- Cross join all as they each produce one row