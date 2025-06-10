-- Script Name: 03_08_realized_gains_losses_fifo_all_assets_summary.sql
-- Purpose: Calculates a summary of realized gains/losses for EACH sale event
--          across ALL cryptocurrencies using the FIFO method.


WITH
    -- 1. Get all BUY transactions for ALL cryptos, ordered by time per crypto,
    --    with a running total of quantity bought per crypto.
    buys AS (
        SELECT
            crypto_id,
            tx_id AS buy_tx_id,
            tx_timestamp AS buy_timestamp,
            quantity AS buy_quantity,
            price_per_unit_usd AS buy_price_usd,
            SUM(quantity) OVER (PARTITION BY crypto_id ORDER BY tx_timestamp, tx_id) AS cumulative_buy_quantity
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
    matched_lots AS (
        SELECT
            s.crypto_id, -- Crucial to carry this through for joining and grouping
            s.sell_tx_id,
            s.sell_timestamp,
            s.sell_price_usd,
            b.buy_tx_id,
            b.buy_timestamp,
            b.buy_price_usd,
            -- Calculate the quantity from this specific buy lot that is consumed by this specific sell lot portion
            GREATEST(0,
                LEAST(b.cumulative_buy_quantity, s.cumulative_sell_quantity) -
                GREATEST(b.cumulative_buy_quantity - b.buy_quantity, s.prev_cumulative_sell_quantity)
            ) AS quantity_sold_from_this_buy
        FROM
            sells s
        JOIN
            buys b
            ON s.crypto_id = b.crypto_id -- Ensure we only match buys and sells of the SAME crypto
            AND b.buy_timestamp <= s.sell_timestamp
            AND b.cumulative_buy_quantity > s.prev_cumulative_sell_quantity
            AND (b.cumulative_buy_quantity - b.buy_quantity) < s.cumulative_sell_quantity
        WHERE
            GREATEST(0, LEAST(b.cumulative_buy_quantity, s.cumulative_sell_quantity) - GREATEST(b.cumulative_buy_quantity - b.buy_quantity, s.prev_cumulative_sell_quantity)) > 0.000000000000000001
    )

-- 4. Aggregate results per sale event for all cryptos
SELECT
    ml.sell_tx_id,
    cy.symbol,
    ml.sell_timestamp,
    SUM(ml.quantity_sold_from_this_buy) AS total_quantity_sold_in_sale,
    SUM(ml.quantity_sold_from_this_buy * ml.sell_price_usd) AS total_proceeds_for_sale,
    SUM(ml.quantity_sold_from_this_buy * ml.buy_price_usd) AS total_cost_basis_for_sale,
    SUM((ml.quantity_sold_from_this_buy * ml.sell_price_usd) - (ml.quantity_sold_from_this_buy * ml.buy_price_usd)) AS total_realized_gain_loss_for_sale
FROM
    matched_lots ml
JOIN
    public.cryptocurrencies cy ON ml.crypto_id = cy.crypto_id -- Join to get symbol
WHERE ml.quantity_sold_from_this_buy > 0
GROUP BY
    ml.sell_tx_id,
    cy.symbol, -- Include symbol in GROUP BY as it's selected
    ml.sell_timestamp
ORDER BY
    cy.symbol, ml.sell_timestamp;