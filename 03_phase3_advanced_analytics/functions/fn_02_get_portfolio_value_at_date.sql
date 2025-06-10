-- Script Name: fn_02_get_portfolio_value_at_date.sql
-- Purpose: Creates a PostgreSQL function to calculate the total portfolio value (USD)
--          as of the end of a specified target date.

CREATE OR REPLACE FUNCTION get_portfolio_value_at_date(p_target_date DATE)
RETURNS NUMERIC(30, 2) -- Return a single numeric value for the total portfolio value
AS $$
DECLARE
    v_total_portfolio_value NUMERIC(30, 2);
BEGIN
    -- Calculate total portfolio value by summing (holding_quantity * price)
    -- for all assets held on p_target_date, using prices from that date.
    WITH
        -- Get holdings as of the target date using our previously created function
        holdings_on_date AS (
            SELECT * FROM get_historical_holdings(p_target_date) -- Call our function
        ),

        -- Get prices for all assets on the target date
        prices_on_date AS (
            SELECT
                hp.crypto_id,
                hp.close_price_usd
            FROM
                public.historical_prices AS hp
            WHERE
                hp.price_date = p_target_date
        ),

        -- Calculate value of each asset held on the target date
        asset_values_on_date AS (
            SELECT
                hod.crypto_id,
                (hod.historical_holding_quantity * COALESCE(pod.close_price_usd, 0)) AS asset_value_usd
            FROM
                holdings_on_date AS hod
            LEFT JOIN
                prices_on_date AS pod ON hod.crypto_id = pod.crypto_id
        )

    -- Sum the individual asset values to get the total portfolio value
    SELECT
        COALESCE(SUM(avod.asset_value_usd), 0) INTO v_total_portfolio_value
    FROM
        asset_values_on_date AS avod;

    RETURN v_total_portfolio_value;

END;
$$ LANGUAGE plpgsql;

-- Example of how to call the function:
-- SELECT get_portfolio_value_at_date('2023-03-15');
-- SELECT get_portfolio_value_at_date(CURRENT_DATE - INTERVAL '1 month');