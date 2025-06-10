-- Script Name: 03_04_realized_gains_losses_fifo_single_asset.sql
-- Purpose: Calculates realized gains/losses for a single cryptocurrency (Bitcoin, crypto_id = 1)
--          using the FIFO method.
-- WARNING: This is a complex query for illustrative purposes. Tax laws vary. Consult a tax professional.

WITH
    target_crypto AS (
        SELECT 1 AS id -- Assuming 1 is the crypto_id for Bitcoin (BTC)
    ),

    buys AS (
        SELECT
            tx_id AS buy_tx_id,
            tx_timestamp AS buy_timestamp,
            quantity AS buy_quantity,
            price_per_unit_usd AS buy_price_usd,
            SUM(quantity) OVER (PARTITION BY crypto_id ORDER BY tx_timestamp, tx_id) AS cumulative_buy_quantity
        FROM
            public.transactions
        WHERE
            crypto_id = (SELECT id FROM target_crypto)
            AND tx_type = 'BUY'
            AND quantity > 0
            AND price_per_unit_usd IS NOT NULL
    ),

    -- Step 2a: Calculate cumulative sell quantity first
    sells_cumulative AS (
        SELECT
            tx_id AS sell_tx_id,
            tx_timestamp AS sell_timestamp,
            quantity AS sell_quantity,
            price_per_unit_usd AS sell_price_usd,
            crypto_id, -- Keep crypto_id for partitioning in next step
            SUM(quantity) OVER (PARTITION BY crypto_id ORDER BY tx_timestamp, tx_id) AS cumulative_sell_quantity
        FROM
            public.transactions
        WHERE
            crypto_id = (SELECT id FROM target_crypto)
            AND tx_type = 'SELL'
            AND quantity > 0
            AND price_per_unit_usd IS NOT NULL
    ),

    -- Step 2b: Now apply LAG to the pre-calculated cumulative sell quantity
    sells AS (
        SELECT
            sell_tx_id,
            sell_timestamp,
            sell_quantity,
            sell_price_usd,
            cumulative_sell_quantity,
            LAG(cumulative_sell_quantity, 1, 0) OVER (PARTITION BY crypto_id ORDER BY sell_timestamp, sell_tx_id) AS prev_cumulative_sell_quantity
        FROM
            sells_cumulative
    ),

    matched_lots AS (
        SELECT
            s.sell_tx_id,
            s.sell_timestamp,
            s.sell_price_usd,
            b.buy_tx_id,
            b.buy_timestamp,
            b.buy_price_usd,
            GREATEST(0,
                LEAST(b.cumulative_buy_quantity, s.cumulative_sell_quantity) -
                GREATEST(b.cumulative_buy_quantity - b.buy_quantity, s.prev_cumulative_sell_quantity)
            ) AS quantity_sold_from_this_buy
        FROM
            sells s
        JOIN
            buys b
            ON b.buy_timestamp <= s.sell_timestamp
            AND b.cumulative_buy_quantity > s.prev_cumulative_sell_quantity
            AND (b.cumulative_buy_quantity - b.buy_quantity) < s.cumulative_sell_quantity
        WHERE
            GREATEST(0, LEAST(b.cumulative_buy_quantity, s.cumulative_sell_quantity) - GREATEST(b.cumulative_buy_quantity - b.buy_quantity, s.prev_cumulative_sell_quantity)) > 0.000000000000000001
    )

-- 4. Calculate gain/loss for each matched lot portion
SELECT
    ml.sell_tx_id,
    (SELECT symbol FROM public.cryptocurrencies WHERE crypto_id = (SELECT id FROM target_crypto)) AS symbol,
    ml.sell_timestamp,
    ml.quantity_sold_from_this_buy AS quantity_sold,
    ml.sell_price_usd,
    ml.buy_tx_id AS matched_buy_lot_tx_id,
    ml.buy_timestamp AS matched_buy_lot_timestamp,
    ml.buy_price_usd AS cost_basis_per_unit,
    (ml.quantity_sold_from_this_buy * ml.sell_price_usd) AS proceeds_from_this_lot_portion,
    (ml.quantity_sold_from_this_buy * ml.buy_price_usd) AS cost_of_this_lot_portion,
    (ml.quantity_sold_from_this_buy * ml.sell_price_usd) - (ml.quantity_sold_from_this_buy * ml.buy_price_usd) AS realized_gain_loss_usd
FROM
    matched_lots ml
WHERE ml.quantity_sold_from_this_buy > 0
ORDER BY
    ml.sell_timestamp, ml.sell_tx_id, ml.buy_timestamp;