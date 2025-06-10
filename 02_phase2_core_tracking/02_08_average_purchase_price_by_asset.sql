-- Script Name: 02_08_average_purchase_price_by_asset.sql
-- Purpose: Calculates the weighted average purchase price for each cryptocurrency
--          based on all 'BUY' transactions.

WITH
    -- Calculate total quantity purchased and total cost for those purchases for each crypto
    purchase_summary AS (
        SELECT
            t.crypto_id,
            SUM(t.quantity) AS total_quantity_purchased,
            SUM(t.quantity * t.price_per_unit_usd) AS total_cost_of_purchases_usd
        FROM
            public.transactions AS t
        WHERE
            t.tx_type = 'BUY'       -- Only consider BUY transactions
            AND t.price_per_unit_usd IS NOT NULL -- Ensure price is available for the calculation
            AND t.quantity > 0              -- Ensure quantity is positive
        GROUP BY
            t.crypto_id
    )

-- Calculate the weighted average purchase price and join with cryptocurrency details
SELECT
    c.crypto_id,
    c.symbol,
    c.name,
    ps.total_quantity_purchased,
    ps.total_cost_of_purchases_usd,
    -- Calculate Weighted Average Price: Total Cost / Total Quantity
    -- Handle division by zero if total_quantity_purchased is 0 (though filtered by HAVING below)
    CASE
        WHEN ps.total_quantity_purchased IS NULL OR ps.total_quantity_purchased = 0 THEN NULL
        ELSE ps.total_cost_of_purchases_usd / ps.total_quantity_purchased
    END AS weighted_average_purchase_price_usd
FROM
    public.cryptocurrencies AS c
JOIN -- Use JOIN because we only care about cryptos that have purchases
    purchase_summary AS ps ON c.crypto_id = ps.crypto_id
WHERE
    ps.total_quantity_purchased > 0 -- Ensure we only show assets with actual purchases
ORDER BY
    c.symbol;