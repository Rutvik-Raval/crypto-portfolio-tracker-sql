EXPLAIN ANALYZE -- This applies to the ENTIRE statement that follows
WITH -- Start of the CTE definitions
    -- CTE 1: inflows
    inflows AS (
        SELECT
            t.crypto_id,
            SUM(t.quantity) AS total_quantity_in
        FROM
            public.transactions AS t
        WHERE
            t.tx_type IN (
                'BUY', 'TRANSFER_IN', 'DEPOSIT',
                'AIRDROP', 'STAKING_REWARD', 'MINING_REWARD',
                'INTEREST_REWARD', 'LENDING_REWARD', 'GIFT_RECEIVED',
                'OTHER_INCOME'
            )
        GROUP BY
            t.crypto_id
    ), -- Comma separating CTEs

    -- CTE 2: outflows
    outflows AS (
        SELECT
            t.crypto_id,
            SUM(t.quantity) AS total_quantity_out
        FROM
            public.transactions AS t
        WHERE
            t.tx_type IN (
                'SELL', 'TRANSFER_OUT', 'WITHDRAWAL',
                'FEE_PAYMENT', 'GIFT_SENT',
                'OTHER_EXPENSE'
            )
        GROUP BY
            t.crypto_id
    ) -- End of CTE definitions

-- The main SELECT statement that USES the CTEs defined above
SELECT
    c.crypto_id,
    c.symbol,
    c.name,
    COALESCE(i.total_quantity_in, 0) - COALESCE(o.total_quantity_out, 0) AS current_holding_quantity
FROM
    public.cryptocurrencies AS c
LEFT JOIN
    inflows AS i ON c.crypto_id = i.crypto_id -- 'inflows' CTE is used here
LEFT JOIN
    outflows AS o ON c.crypto_id = o.crypto_id -- 'outflows' CTE is used here
WHERE
    COALESCE(i.total_quantity_in, 0) - COALESCE(o.total_quantity_out, 0) > 0.000000000000000001
ORDER BY
    c.symbol; -- Semicolon ends the entire EXPLAIN ANALYZE statement