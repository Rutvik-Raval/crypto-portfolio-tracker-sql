WITH
    -- Step 1: Calculate total quantities from transactions that INCREASE holdings for each crypto
    inflows AS (
        SELECT
            t.crypto_id,
            SUM(t.quantity) AS total_quantity_in
        FROM
            public.transactions AS t
        WHERE
            t.tx_type IN (
                'BUY', 'TRANSFER_IN', 'DEPOSIT', -- Standard inflows
                'AIRDROP', 'STAKING_REWARD', 'MINING_REWARD', -- Income types
                'INTEREST_REWARD', 'LENDING_REWARD', 'GIFT_RECEIVED',
                'OTHER_INCOME' -- Assuming OTHER_INCOME means asset quantity increase
            )
        GROUP BY
            t.crypto_id
    ),

    -- Step 2: Calculate total quantities from transactions that DECREASE holdings for each crypto
    outflows AS (
        SELECT
            t.crypto_id,
            SUM(t.quantity) AS total_quantity_out
        FROM
            public.transactions AS t
        WHERE
            t.tx_type IN (
                'SELL', 'TRANSFER_OUT', 'WITHDRAWAL', -- Standard outflows
                'FEE_PAYMENT', -- If fees are recorded as a quantity reduction of the primary crypto
                'GIFT_SENT',
                'OTHER_EXPENSE' -- Assuming OTHER_EXPENSE means asset quantity decrease
            )
        GROUP BY
            t.crypto_id
    )

-- Step 3 & 4: Calculate net holdings and join with cryptocurrency details
SELECT
    c.crypto_id,                                 -- The ID of the cryptocurrency
    c.symbol,                                    -- The symbol (e.g., BTC, ETH)
    c.name,                                      -- The full name (e.g., Bitcoin, Ethereum)
    COALESCE(i.total_quantity_in, 0) - COALESCE(o.total_quantity_out, 0) AS current_holding_quantity
                                                 -- Calculate net quantity:
                                                 -- COALESCE(..., 0) is used in case a crypto has only inflows or only outflows,
                                                 -- ensuring that if one side is NULL (no transactions of that type), it's treated as 0.
FROM
    public.cryptocurrencies AS c                 -- Start with the cryptocurrencies table to list all potential cryptos
LEFT JOIN
    inflows AS i ON c.crypto_id = i.crypto_id    -- Join with our calculated inflows
LEFT JOIN
    outflows AS o ON c.crypto_id = o.crypto_id   -- Join with our calculated outflows
WHERE
    -- Only show cryptocurrencies where there's a net holding greater than a very small number
    -- This avoids showing cryptos with exactly zero balance due to perfect in/out or dust amounts.
    -- You can adjust the threshold (e.g., 0.00000001) or remove this WHERE clause
    -- if you want to see cryptos with zero or even negative (if possible due to data issues) balances.
    -- A common precision for quantity is NUMERIC(28,18), so 18 decimal places.
    COALESCE(i.total_quantity_in, 0) - COALESCE(o.total_quantity_out, 0) > 0.000000000000000001 -- Example: 1 satoshi for BTC like precision
ORDER BY
    c.symbol;                                    -- Display the results ordered by symbol