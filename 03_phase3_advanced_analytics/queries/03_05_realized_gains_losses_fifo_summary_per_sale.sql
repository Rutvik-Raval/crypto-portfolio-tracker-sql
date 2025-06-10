WITH
    target_crypto AS (
        SELECT 1 AS id
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
            AND tx_type = 'BUY' AND quantity > 0 AND price_per_unit_usd IS NOT NULL
    ),
    sells_cumulative AS (
        SELECT
            tx_id AS sell_tx_id,
            tx_timestamp AS sell_timestamp,
            quantity AS sell_quantity,
            price_per_unit_usd AS sell_price_usd,
            crypto_id,
            SUM(quantity) OVER (PARTITION BY crypto_id ORDER BY tx_timestamp, tx_id) AS cumulative_sell_quantity
        FROM
            public.transactions
        WHERE
            crypto_id = (SELECT id FROM target_crypto)
            AND tx_type = 'SELL' AND quantity > 0 AND price_per_unit_usd IS NOT NULL
    ),
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
SELECT
    sell_tx_id,
    (SELECT symbol FROM public.cryptocurrencies WHERE crypto_id = (SELECT id FROM target_crypto)) AS symbol,
    sell_timestamp,
    SUM(quantity_sold_from_this_buy) AS total_quantity_sold_in_sale,
    SUM(quantity_sold_from_this_buy * sell_price_usd) AS total_proceeds_for_sale,
    SUM(quantity_sold_from_this_buy * buy_price_usd) AS total_cost_basis_for_sale,
    SUM((quantity_sold_from_this_buy * sell_price_usd) - (quantity_sold_from_this_buy * buy_price_usd)) AS total_realized_gain_loss_for_sale
FROM
    matched_lots
WHERE quantity_sold_from_this_buy > 0
GROUP BY
    sell_tx_id, sell_timestamp -- Removed symbol from GROUP BY as it's now a subquery in SELECT
ORDER BY
    sell_timestamp;