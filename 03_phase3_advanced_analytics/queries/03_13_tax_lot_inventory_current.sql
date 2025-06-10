-- Script Name: 03_13_tax_lot_inventory_current.sql
-- Purpose: Lists all current, unsold tax lots (original BUY transactions)
--          showing the remaining quantity from each purchase, based on FIFO consumption.

WITH
    -- 1. Get all BUY transactions for ALL cryptos
    buys AS (
        SELECT
            crypto_id,
            tx_id AS buy_tx_id,
            tx_timestamp AS buy_timestamp,
            quantity AS original_buy_quantity, -- Total quantity from this specific buy transaction
            price_per_unit_usd AS buy_price_usd,
            SUM(quantity) OVER (PARTITION BY crypto_id ORDER BY tx_timestamp, tx_id) AS cumulative_buy_quantity_overall
        FROM
            public.transactions
        WHERE
            tx_type = 'BUY'
            AND quantity > 0
            AND price_per_unit_usd IS NOT NULL
    ),

    -- 2a. Get all SELL transactions, calculate cumulative sell quantity per crypto.
    sells_cumulative AS (
        SELECT
            crypto_id,
            tx_id AS sell_tx_id,
            tx_timestamp AS sell_timestamp,
            quantity AS sell_quantity,
            price_per_unit_usd AS sell_price_usd,
            SUM(quantity) OVER (PARTITION BY crypto_id ORDER BY tx_timestamp, tx_id) AS cumulative_sell_quantity
        FROM
            public.transactions
        WHERE
            tx_type = 'SELL'
            AND quantity > 0
            AND price_per_unit_usd IS NOT NULL
    ),

    -- 2b. Apply LAG to get previous cumulative sell quantity per crypto.
    sells AS (
        SELECT
            crypto_id,
            sell_tx_id,
            sell_timestamp,
            sell_quantity,
            sell_price_usd,
            cumulative_sell_quantity,
            LAG(cumulative_sell_quantity, 1, 0) OVER (PARTITION BY crypto_id ORDER BY sell_timestamp, sell_tx_id) AS prev_cumulative_sell_quantity
        FROM
            sells_cumulative
    ),

    -- 3. For each SALE, match it against BUY lots (within the same crypto_id) using FIFO.
    -- This determines how much of each buy lot was "consumed" by sales.
    matched_lots_for_consumption AS (
        SELECT
            s.crypto_id,
            b.buy_tx_id,
            GREATEST(0,
                LEAST(b.cumulative_buy_quantity_overall, s.cumulative_sell_quantity) -
                GREATEST(b.cumulative_buy_quantity_overall - b.original_buy_quantity, s.prev_cumulative_sell_quantity)
            ) AS quantity_from_this_buy_lot_consumed_by_sales
        FROM
            sells s
        JOIN
            buys b -- Make sure to use the 'buys' CTE that has original_buy_quantity
            ON s.crypto_id = b.crypto_id
            AND b.buy_timestamp <= s.sell_timestamp
            AND b.cumulative_buy_quantity_overall > s.prev_cumulative_sell_quantity
            AND (b.cumulative_buy_quantity_overall - b.original_buy_quantity) < s.cumulative_sell_quantity
        WHERE
            GREATEST(0, LEAST(b.cumulative_buy_quantity_overall, s.cumulative_sell_quantity) - GREATEST(b.cumulative_buy_quantity_overall - b.original_buy_quantity, s.prev_cumulative_sell_quantity)) > 0.000000000000000001
    ),

    -- 4. Calculate total quantity consumed for each buy lot
    buy_lot_consumption AS (
        SELECT
            crypto_id,
            buy_tx_id,
            SUM(quantity_from_this_buy_lot_consumed_by_sales) AS total_quantity_consumed
        FROM
            matched_lots_for_consumption
        GROUP BY
            crypto_id, buy_tx_id
    )

-- 5. Final SELECT: Show original buy lots and their remaining (unsold) quantity
SELECT
    b.buy_tx_id,
    cy.symbol,
    b.buy_timestamp,
    b.original_buy_quantity,
    b.buy_price_usd AS purchase_price_per_unit_usd,
    COALESCE(blc.total_quantity_consumed, 0) AS quantity_sold_from_this_lot,
    (b.original_buy_quantity - COALESCE(blc.total_quantity_consumed, 0)) AS remaining_quantity_in_lot
FROM
    buys b
JOIN
    public.cryptocurrencies cy ON b.crypto_id = cy.crypto_id
LEFT JOIN
    buy_lot_consumption blc ON b.buy_tx_id = blc.buy_tx_id AND b.crypto_id = blc.crypto_id -- Match on buy_tx_id and crypto_id
WHERE
    -- Only show lots that still have some quantity remaining
    (b.original_buy_quantity - COALESCE(blc.total_quantity_consumed, 0)) > 0.000000000000000001
ORDER BY
    cy.symbol, b.buy_timestamp;