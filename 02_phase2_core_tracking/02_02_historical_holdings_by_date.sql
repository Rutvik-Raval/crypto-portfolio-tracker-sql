WITH
    -- Define the target historical date.
    -- In a real application, this might be a parameter.
    params AS (
        SELECT '2022-03-31'::DATE AS target_date
    ),

    -- Step 1: Calculate total quantities from transactions that INCREASE holdings
    -- for each crypto, up to and including the target_date.
    historical_inflows AS (
        SELECT
            t.crypto_id,
            SUM(t.quantity) AS total_quantity_in
        FROM
            public.transactions AS t, params -- Cross join to get access to target_date
        WHERE
            t.tx_type IN (
                'BUY', 'TRANSFER_IN', 'DEPOSIT',
                'AIRDROP', 'STAKING_REWARD', 'MINING_REWARD',
                'INTEREST_REWARD', 'LENDING_REWARD', 'GIFT_RECEIVED',
                'OTHER_INCOME'
            )
            AND DATE(t.tx_timestamp) <= params.target_date -- Filter by transaction date
        GROUP BY
            t.crypto_id
    ),

    -- Step 2: Calculate total quantities from transactions that DECREASE holdings
    -- for each crypto, up to and including the target_date.
    historical_outflows AS (
        SELECT
            t.crypto_id,
            SUM(t.quantity) AS total_quantity_out
        FROM
            public.transactions AS t, params -- Cross join to get access to target_date
        WHERE
            t.tx_type IN (
                'SELL', 'TRANSFER_OUT', 'WITHDRAWAL',
                'FEE_PAYMENT', 'GIFT_SENT',
                'OTHER_EXPENSE'
            )
            AND DATE(t.tx_timestamp) <= params.target_date -- Filter by transaction date
        GROUP BY
            t.crypto_id
    )

-- Step 3 & 4: Calculate net historical holdings and join with cryptocurrency details
SELECT
    p.target_date,                               -- Show the date for which holdings are calculated
    c.crypto_id,
    c.symbol,
    c.name,
    COALESCE(hi.total_quantity_in, 0) - COALESCE(ho.total_quantity_out, 0) AS historical_holding_quantity
FROM
    params p, -- Makes target_date available to the final SELECT
    public.cryptocurrencies AS c
LEFT JOIN
    historical_inflows AS hi ON c.crypto_id = hi.crypto_id
LEFT JOIN
    historical_outflows AS ho ON c.crypto_id = ho.crypto_id
WHERE
    -- Only show cryptocurrencies where there was a net positive holding on that historical date.
    -- Adjust or remove as needed.
    COALESCE(hi.total_quantity_in, 0) - COALESCE(ho.total_quantity_out, 0) > 0.000000000000000001
ORDER BY
    c.symbol;

