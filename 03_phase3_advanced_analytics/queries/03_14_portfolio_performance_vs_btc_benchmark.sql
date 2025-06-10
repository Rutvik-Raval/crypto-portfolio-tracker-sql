-- Script Name: 03_14_portfolio_performance_vs_btc_benchmark.sql
-- Purpose: Compares the portfolio's value growth over a period against
--          the growth of a hypothetical investment in Bitcoin (BTC) made
--          with the portfolio's initial value at the start of the period.

WITH
    -- Define the analysis period and BTC's crypto_id
    params AS (
        SELECT
            '2023-01-01'::DATE AS start_date, -- <<<<<< CHANGE: Your desired start date
            CURRENT_DATE AS end_date,      -- <<<<<< CHANGE: Or a specific end date 'YYYY-MM-DD'::DATE
            1 AS btc_crypto_id             -- <<<<<< CHANGE: If BTC's crypto_id is not 1
    ),

    -- Function-like CTE to get holdings at a specific date (reused logic)
    -- We'll define it once and use it for both start and end date holdings for portfolio
    get_holdings_at_date AS (
        SELECT
            p.eval_date, -- Parameterized date
            t.crypto_id,
            SUM(CASE
                    WHEN t.tx_type IN ('BUY', 'TRANSFER_IN', 'DEPOSIT', 'AIRDROP', 'STAKING_REWARD', 'MINING_REWARD', 'INTEREST_REWARD', 'LENDING_REWARD', 'GIFT_RECEIVED', 'OTHER_INCOME') THEN t.quantity
                    ELSE 0
                END) -
            SUM(CASE
                    WHEN t.tx_type IN ('SELL', 'TRANSFER_OUT', 'WITHDRAWAL', 'FEE_PAYMENT', 'GIFT_SENT', 'OTHER_EXPENSE') THEN t.quantity
                    ELSE 0
                END) AS holding_quantity
        FROM
            public.transactions AS t,
            (SELECT start_date AS eval_date FROM params UNION ALL SELECT end_date AS eval_date FROM params) AS p -- Generate rows for start and end dates
        WHERE
            DATE(t.tx_timestamp) <= p.eval_date
        GROUP BY
            p.eval_date, t.crypto_id
        HAVING
            SUM(CASE
                    WHEN t.tx_type IN ('BUY', 'TRANSFER_IN', 'DEPOSIT', 'AIRDROP', 'STAKING_REWARD', 'MINING_REWARD', 'INTEREST_REWARD', 'LENDING_REWARD', 'GIFT_RECEIVED', 'OTHER_INCOME') THEN t.quantity
                    ELSE 0
                END) -
            SUM(CASE
                    WHEN t.tx_type IN ('SELL', 'TRANSFER_OUT', 'WITHDRAWAL', 'FEE_PAYMENT', 'GIFT_SENT', 'OTHER_EXPENSE') THEN t.quantity
                    ELSE 0
                END) > 0.000000000000000001
    ),

    -- Get prices for all assets at start_date
    prices_at_start_date AS (
        SELECT
            hp.crypto_id,
            hp.close_price_usd
        FROM
            public.historical_prices hp, params p
        WHERE
            hp.price_date = p.start_date
    ),

    -- Get prices for all assets at end_date (or latest if end_date is current)
    prices_at_end_date AS (
        SELECT
            hp.crypto_id,
            hp.close_price_usd
        FROM
            public.historical_prices hp, params p
        WHERE
            hp.price_date = (CASE WHEN p.end_date = CURRENT_DATE THEN (SELECT MAX(price_date) FROM public.historical_prices WHERE crypto_id = hp.crypto_id) ELSE p.end_date END)
            -- This sub-select for MAX(price_date) needs to be more careful if end_date = CURRENT_DATE and prices are not yet available for CURRENT_DATE
            -- A simpler approach for now: assume prices are available for p.end_date if it's not CURRENT_DATE,
            -- or use absolute latest for CURRENT_DATE. The original latest_prices CTE from portfolio value is better for "current".
            -- Let's refine this part for end_date prices.
    ),
    -- Refined prices_at_end_date to handle CURRENT_DATE more robustly for latest price
    refined_prices_at_end_date AS (
        SELECT
            hp.crypto_id,
            hp.close_price_usd
        FROM public.historical_prices hp
        INNER JOIN (
            SELECT p.end_date_to_use, hpin.crypto_id, MAX(hpin.price_date) as max_eff_date
            FROM public.historical_prices hpin, (SELECT CASE WHEN end_date = CURRENT_DATE THEN (SELECT MAX(price_date) FROM public.historical_prices) ELSE end_date END as end_date_to_use FROM params) p
            WHERE hpin.price_date <= p.end_date_to_use -- Get latest price ON OR BEFORE the desired end_date
            GROUP BY p.end_date_to_use, hpin.crypto_id
        ) AS effective_dates ON hp.crypto_id = effective_dates.crypto_id AND hp.price_date = effective_dates.max_eff_date
    ),


    -- Calculate portfolio value at start_date
    portfolio_value_start AS (
        SELECT
            SUM(ghd.holding_quantity * COALESCE(pasd.close_price_usd, 0)) AS value_usd
        FROM
            get_holdings_at_date ghd
        JOIN params p ON ghd.eval_date = p.start_date
        LEFT JOIN
            prices_at_start_date pasd ON ghd.crypto_id = pasd.crypto_id
    ),

    -- Calculate portfolio value at end_date
    portfolio_value_end AS (
        SELECT
            SUM(ghd.holding_quantity * COALESCE(rped.close_price_usd, 0)) AS value_usd
        FROM
            get_holdings_at_date ghd
        JOIN params p ON ghd.eval_date = p.end_date
        LEFT JOIN
            refined_prices_at_end_date rped ON ghd.crypto_id = rped.crypto_id
    ),

    -- Get BTC price at start_date and end_date
    btc_benchmark_prices AS (
        SELECT
            (SELECT close_price_usd FROM public.historical_prices WHERE crypto_id = p.btc_crypto_id AND price_date = p.start_date) AS btc_price_start,
            (SELECT close_price_usd FROM refined_prices_at_end_date WHERE crypto_id = p.btc_crypto_id) AS btc_price_end -- Uses the same logic as portfolio end price
        FROM params p
    )

-- Final Comparison
SELECT
    p.start_date,
    p.end_date,
    COALESCE(pvs.value_usd, 0) AS portfolio_start_value,
    COALESCE(pve.value_usd, 0) AS portfolio_end_value,
    (COALESCE(pve.value_usd, 0) - COALESCE(pvs.value_usd, 0)) AS portfolio_absolute_gain_loss,
    CASE
        WHEN COALESCE(pvs.value_usd, 0) = 0 THEN NULL
        ELSE ROUND(((COALESCE(pve.value_usd, 0) - COALESCE(pvs.value_usd, 0)) / pvs.value_usd) * 100, 2)
    END AS portfolio_percentage_growth,

    -- BTC Benchmark Calculation
    COALESCE(pvs.value_usd, 0) AS btc_hypothetical_initial_investment, -- Same as portfolio start value
    bbp.btc_price_start,
    bbp.btc_price_end,
    CASE
        WHEN bbp.btc_price_start IS NULL OR bbp.btc_price_start = 0 THEN NULL
        ELSE COALESCE(pvs.value_usd, 0) / bbp.btc_price_start -- Units of BTC bought
    END AS btc_units_hypothetically_bought,
    CASE
        WHEN bbp.btc_price_start IS NULL OR bbp.btc_price_start = 0 OR bbp.btc_price_end IS NULL THEN NULL
        ELSE (COALESCE(pvs.value_usd, 0) / bbp.btc_price_start) * bbp.btc_price_end
    END AS btc_hypothetical_end_value,
    CASE
        WHEN bbp.btc_price_start IS NULL OR bbp.btc_price_start = 0 OR bbp.btc_price_end IS NULL THEN NULL
        ELSE ((COALESCE(pvs.value_usd, 0) / bbp.btc_price_start) * bbp.btc_price_end) - COALESCE(pvs.value_usd, 0)
    END AS btc_hypothetical_absolute_gain_loss,
    CASE
        WHEN COALESCE(pvs.value_usd, 0) = 0 OR bbp.btc_price_start IS NULL OR bbp.btc_price_start = 0 OR bbp.btc_price_end IS NULL THEN NULL
        ELSE ROUND(((((COALESCE(pvs.value_usd, 0) / bbp.btc_price_start) * bbp.btc_price_end) - COALESCE(pvs.value_usd, 0)) / COALESCE(pvs.value_usd, 0)) * 100, 2)
    END AS btc_hypothetical_percentage_growth,

    -- Difference in Performance
    (CASE
        WHEN COALESCE(pvs.value_usd, 0) = 0 THEN NULL
        ELSE ROUND(((COALESCE(pve.value_usd, 0) - COALESCE(pvs.value_usd, 0)) / pvs.value_usd) * 100, 2)
    END) -
    (CASE
        WHEN COALESCE(pvs.value_usd, 0) = 0 OR bbp.btc_price_start IS NULL OR bbp.btc_price_start = 0 OR bbp.btc_price_end IS NULL THEN NULL
        ELSE ROUND(((((COALESCE(pvs.value_usd, 0) / bbp.btc_price_start) * bbp.btc_price_end) - COALESCE(pvs.value_usd, 0)) / COALESCE(pvs.value_usd, 0)) * 100, 2)
    END) AS outperformance_vs_btc_pct_points

FROM
    params p,
    portfolio_value_start pvs,
    portfolio_value_end pve,
    btc_benchmark_prices bbp; -- Cross join all, as they should produce one row each