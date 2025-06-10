-- Script Name: fn_01_get_historical_holdings.sql
-- Purpose: Creates a PostgreSQL function to retrieve historical holdings
--          of all cryptocurrencies as of a specified target date.

CREATE OR REPLACE FUNCTION get_historical_holdings(p_target_date DATE)
RETURNS TABLE (
    crypto_id INTEGER,
    symbol VARCHAR(20),
    name VARCHAR(100),
    historical_holding_quantity NUMERIC(28, 18) -- Match precision with transactions.quantity
)
AS $$
BEGIN
    -- The body of the function uses the same logic as script 02_02...
    -- with the hardcoded date replaced by the p_target_date parameter.
    RETURN QUERY
    WITH
        -- No separate 'params' CTE needed here as p_target_date is a function argument.

        -- Calculate total quantities from transactions that INCREASE holdings
        -- for each crypto, up to and including the p_target_date.
        historical_inflows AS (
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
                AND DATE(t.tx_timestamp) <= p_target_date -- Use the function parameter
            GROUP BY
                t.crypto_id
        ),

        -- Calculate total quantities from transactions that DECREASE holdings
        -- for each crypto, up to and including the p_target_date.
        historical_outflows AS (
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
                AND DATE(t.tx_timestamp) <= p_target_date -- Use the function parameter
            GROUP BY
                t.crypto_id
        )

    -- Calculate net historical holdings and join with cryptocurrency details
    SELECT
        c.crypto_id,
        c.symbol,
        c.name,
        (COALESCE(hi.total_quantity_in, 0) - COALESCE(ho.total_quantity_out, 0))::NUMERIC(28,18) AS historical_holding_quantity
    FROM
        public.cryptocurrencies AS c
    LEFT JOIN
        historical_inflows AS hi ON c.crypto_id = hi.crypto_id
    LEFT JOIN
        historical_outflows AS ho ON c.crypto_id = ho.crypto_id
    WHERE
        -- Only show cryptocurrencies where there was a net positive holding on that historical date.
        -- You can adjust this threshold or remove this WHERE clause.
        (COALESCE(hi.total_quantity_in, 0) - COALESCE(ho.total_quantity_out, 0)) > 0.000000000000000001
    ORDER BY
        c.symbol;

END;
$$ LANGUAGE plpgsql;

-- Example of how to call the function:
-- SELECT * FROM get_historical_holdings('2023-03-15');
-- SELECT * FROM get_historical_holdings(CURRENT_DATE - INTERVAL '1 year');