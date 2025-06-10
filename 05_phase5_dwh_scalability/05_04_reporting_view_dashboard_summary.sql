-- Script Name: 05_04_reporting_view_dashboard_summary.sql
-- Purpose: Creates a reporting view for a monthly summary of transaction
--          activity per cryptocurrency, using the star schema.

CREATE OR REPLACE VIEW public.view_monthly_crypto_transaction_summary AS
SELECT
    TO_CHAR(dd.full_date, 'YYYY-MM') AS year_month,
    dc.symbol AS crypto_symbol,
    dc.name AS crypto_name,

    -- Buy Metrics
    COALESCE(SUM(CASE WHEN ft.tx_type = 'BUY' THEN ft.quantity ELSE 0 END), 0) AS total_buy_quantity,
    COALESCE(SUM(CASE WHEN ft.tx_type = 'BUY' THEN ft.transaction_value_usd ELSE 0 END), 0) AS total_buy_value_usd,
    COUNT(CASE WHEN ft.tx_type = 'BUY' THEN ft.tx_id_original ELSE NULL END) AS number_of_buy_transactions,
    CASE
        WHEN COALESCE(SUM(CASE WHEN ft.tx_type = 'BUY' THEN ft.quantity ELSE 0 END), 0) = 0 THEN NULL
        ELSE COALESCE(SUM(CASE WHEN ft.tx_type = 'BUY' THEN ft.transaction_value_usd ELSE 0 END), 0) /
             SUM(CASE WHEN ft.tx_type = 'BUY' THEN ft.quantity ELSE 0 END)
    END AS average_buy_price_usd,

    -- Sell Metrics
    COALESCE(SUM(CASE WHEN ft.tx_type = 'SELL' THEN ft.quantity ELSE 0 END), 0) AS total_sell_quantity,
    COALESCE(SUM(CASE WHEN ft.tx_type = 'SELL' THEN ft.transaction_value_usd ELSE 0 END), 0) AS total_sell_value_usd,
    COUNT(CASE WHEN ft.tx_type = 'SELL' THEN ft.tx_id_original ELSE NULL END) AS number_of_sell_transactions,
    CASE
        WHEN COALESCE(SUM(CASE WHEN ft.tx_type = 'SELL' THEN ft.quantity ELSE 0 END), 0) = 0 THEN NULL
        ELSE COALESCE(SUM(CASE WHEN ft.tx_type = 'SELL' THEN ft.transaction_value_usd ELSE 0 END), 0) /
             SUM(CASE WHEN ft.tx_type = 'SELL' THEN ft.quantity ELSE 0 END)
    END AS average_sell_price_usd,

    -- Net Metrics for the month based on transactions
    (COALESCE(SUM(CASE WHEN ft.tx_type = 'BUY' THEN ft.quantity ELSE 0 END), 0) -
     COALESCE(SUM(CASE WHEN ft.tx_type = 'SELL' THEN ft.quantity ELSE 0 END), 0)) AS net_quantity_transacted_this_month,

    (COALESCE(SUM(CASE WHEN ft.tx_type = 'BUY' THEN ft.transaction_value_usd ELSE 0 END), 0) -
     COALESCE(SUM(CASE WHEN ft.tx_type = 'SELL' THEN ft.transaction_value_usd ELSE 0 END), 0)) AS net_value_transacted_this_month_usd,

    -- Fee Metrics
    COALESCE(SUM(ft.fee_usd), 0) AS total_fees_paid_for_asset_this_month_usd -- Sums all fees for transactions of this crypto this month

FROM
    public.fact_transactions AS ft
JOIN
    public.dim_date AS dd ON ft.date_key = dd.date_key
JOIN
    public.dim_cryptocurrency AS dc ON ft.crypto_key = dc.crypto_key
-- We could join dim_exchange or dim_transaction_category if we wanted to slice by those too in this view,
-- but for a per-crypto monthly summary, they aren't strictly needed in the GROUP BY.
GROUP BY
    TO_CHAR(dd.full_date, 'YYYY-MM'), -- Group by year-month string
    dc.symbol,
    dc.name
ORDER BY
    year_month DESC,
    crypto_symbol;

COMMENT ON VIEW public.view_monthly_crypto_transaction_summary IS 'Monthly summary of transaction activity (buys, sells, values, fees) per cryptocurrency, derived from the star schema.';

-- Example of how to query the view:
-- SELECT * FROM public.view_monthly_crypto_transaction_summary WHERE crypto_symbol = 'BTC';
-- SELECT * FROM public.view_monthly_crypto_transaction_summary WHERE year_month = '2023-01';