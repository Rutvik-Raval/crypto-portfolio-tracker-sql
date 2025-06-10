-- Script Name: 00_intermediary_04_most_active_cryptos_by_tx_count.sql
-- Purpose: Identifies the most frequently transacted cryptocurrencies
--          based on the total count of transactions for each.

SELECT
    c.symbol,                               -- The symbol of the cryptocurrency (e.g., BTC)
    c.name,                                 -- The full name of the cryptocurrency (e.g., Bitcoin)
    COUNT(t.tx_id) AS total_transaction_count -- Counts how many transactions exist for this crypto
FROM
    public.transactions AS t                -- Start with the transactions table (aliased as t)
JOIN
    public.cryptocurrencies AS c ON t.crypto_id = c.crypto_id -- Join with cryptocurrencies table (aliased as c)
                                         -- to get the symbol and name using the crypto_id
GROUP BY
    c.crypto_id,                            -- Group by crypto_id to count transactions for each unique crypto
    c.symbol,                               -- Include symbol in GROUP BY because it's in the SELECT
    c.name                                  -- Include name in GROUP BY because it's in the SELECT
ORDER BY
    total_transaction_count DESC;           -- Order the results so that the crypto with the most transactions appears first