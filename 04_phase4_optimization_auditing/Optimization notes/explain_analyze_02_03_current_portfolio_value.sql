EXPLAIN ANALYZE -- This applies to the ENTIRE statement that follows
WITH
    -- CTE 1: Calculate current holdings (same as our previous query)
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
            -- Subquery to find the maximum (latest) price_date for each crypto_id
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
            lp.current_price_usd,
            (ch.holding_quantity * lp.current_price_usd) AS current_market_value_usd
        FROM
            current_holdings AS ch
        JOIN
            public.cryptocurrencies AS c ON ch.crypto_id = c.crypto_id
        LEFT JOIN -- Use LEFT JOIN in case a held asset has no recent price (though ideally it should)
            latest_prices AS lp ON ch.crypto_id = lp.crypto_id
    )

-- Final Step: Calculate the total portfolio value and show individual asset values
-- We can show both individual asset values and the grand total.
-- For just the grand total:
SELECT
    SUM(av.current_market_value_usd) AS total_portfolio_value_usd
FROM
    asset_values AS av;

-- If you want to see the breakdown by asset AND the total, we can use a window function or just run two queries.
-- For now, let's also show the breakdown:
/*
SELECT
    symbol,
    name,
    holding_quantity,
    current_price_usd,
    current_market_value_usd
FROM
    asset_values
ORDER BY
    current_market_value_usd DESC; -- Order by highest value asset
*/