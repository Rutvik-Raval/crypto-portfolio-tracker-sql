-- Script Name: 02_04_current_asset_allocation.sql
-- Purpose: Calculates the current market value of each held asset and its percentage
--          of the total portfolio value.

WITH
    -- CTE 1: Calculate current holdings
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
                END) > 0.000000000000000001 -- Filter for positive holdings
    ),

    -- CTE 2: Get the most recent price for each cryptocurrency
    latest_prices AS (
        SELECT
            hp.crypto_id,
            hp.close_price_usd AS current_price_usd
        FROM
            public.historical_prices AS hp
        INNER JOIN (
            SELECT
                crypto_id,
                MAX(price_date) AS max_date
            FROM
                public.historical_prices
            GROUP BY
                crypto_id
        ) AS latest_dates ON hp.crypto_id = latest_dates.crypto_id AND hp.price_date = latest_dates.max_date
    ),

    -- CTE 3: Calculate current market value for each held asset
    asset_values AS (
        SELECT
            ch.crypto_id,
            c.symbol,
            c.name,
            ch.holding_quantity,
            COALESCE(lp.current_price_usd, 0) AS current_price_usd, -- COALESCE price to 0 if no recent price found
            (ch.holding_quantity * COALESCE(lp.current_price_usd, 0)) AS current_market_value_usd
        FROM
            current_holdings AS ch
        JOIN
            public.cryptocurrencies AS c ON ch.crypto_id = c.crypto_id
        LEFT JOIN -- Use LEFT JOIN for price in case it's missing, COALESCE handles NULL market value
            latest_prices AS lp ON ch.crypto_id = lp.crypto_id
    ),

    -- CTE 4: Calculate the total portfolio value
    total_portfolio_value AS (
        SELECT
            SUM(av.current_market_value_usd) AS total_value_usd
        FROM
            asset_values AS av
    )

-- Final Step: Show each asset's value and its percentage of the total portfolio
SELECT
    av.symbol,
    av.name,
    av.holding_quantity,
    av.current_price_usd,
    av.current_market_value_usd,
    -- Calculate allocation percentage: (asset_value / total_portfolio_value) * 100
    -- Handle division by zero if total_portfolio_value is 0 or NULL
    CASE
        WHEN tpv.total_value_usd IS NULL OR tpv.total_value_usd = 0 THEN 0
        ELSE ROUND((av.current_market_value_usd / tpv.total_value_usd) * 100, 2) -- Rounded to 2 decimal places
    END AS allocation_percentage
FROM
    asset_values AS av,
    total_portfolio_value AS tpv -- Cross join to make total_value_usd available for each row
ORDER BY
    av.current_market_value_usd DESC; -- Order by the most valuable asset