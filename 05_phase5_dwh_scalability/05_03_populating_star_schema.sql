-- Script Name: 05_03_etl_populate_star_schema.sql
-- Purpose: Populates the dimension and fact tables of the star schema.

-- Part 1: Populate dim_date
INSERT INTO public.dim_date (
    date_key,
    full_date,
    year_actual,
    quarter_actual,
    month_actual,
    month_name,
    day_of_month,
    day_of_week_iso,
    day_name,
    week_of_year_iso,
    is_weekday,
    is_weekend
)
SELECT
    TO_CHAR(generated_date, 'YYYYMMDD')::INTEGER AS date_key,
    generated_date AS full_date,
    EXTRACT(YEAR FROM generated_date) AS year_actual,
    EXTRACT(QUARTER FROM generated_date) AS quarter_actual,
    EXTRACT(MONTH FROM generated_date) AS month_actual,
    TRIM(TO_CHAR(generated_date, 'Month')) AS month_name,
    EXTRACT(DAY FROM generated_date) AS day_of_month,
    EXTRACT(ISODOW FROM generated_date) AS day_of_week_iso,
    TRIM(TO_CHAR(generated_date, 'Day')) AS day_name,
    EXTRACT(WEEK FROM generated_date) AS week_of_year_iso,
    CASE
        WHEN EXTRACT(ISODOW FROM generated_date) <= 5 THEN TRUE
        ELSE FALSE
    END AS is_weekday,
    CASE
        WHEN EXTRACT(ISODOW FROM generated_date) >= 6 THEN TRUE
        ELSE FALSE
    END AS is_weekend
FROM
    GENERATE_SERIES(
        '2018-01-01'::DATE,
        '2027-12-31'::DATE,
        '1 day'::INTERVAL
    ) AS generated_date -- Use this simpler alias for the function's output column name
ON CONFLICT (date_key) DO NOTHING;

-- Verify (optional, run separately after INSERT)
-- SELECT COUNT(*) FROM public.dim_date;
-- SELECT * FROM public.dim_date ORDER BY full_date LIMIT 10;

-- Part 2: Populate dim_cryptocurrency
INSERT INTO public.dim_cryptocurrency (
    crypto_id_original,
    symbol,
    name,
    is_stablecoin -- This column IS in dim_cryptocurrency
)
SELECT
    c.crypto_id,       -- This is the original ID
    c.symbol,
    c.name,
    FALSE AS is_stablecoin -- Provide a default value (e.g., FALSE) as it's not in the source
                           -- Alternatively, you could use NULL if dim_cryptocurrency.is_stablecoin allows NULLs
FROM
    public.cryptocurrencies AS c
ON CONFLICT (crypto_id_original) DO UPDATE SET
    symbol = EXCLUDED.symbol,
    name = EXCLUDED.name,
    is_stablecoin = EXCLUDED.is_stablecoin; -- This will update it with the value from EXCLUDED (which is FALSE in this case for new ones)
    
-- Part 3: Populate dim_exchange
-- Loads data from the operational exchanges table.
-- Handles updates to existing exchange details based on exchange_id_original.

INSERT INTO public.dim_exchange (
    exchange_id_original,
    exchange_name,          -- This is the column name in dim_exchange
    exchange_type
)
SELECT
    e.exchange_id,          -- This is original_id from public.exchanges
    e.name,                 -- Assuming 'name' is the column in public.exchanges for the exchange's name
                            -- If it's 'exchange_name' in public.exchanges, use e.exchange_name here.
    e.exchange_type
FROM
    public.exchanges AS e
ON CONFLICT (exchange_id_original) DO UPDATE SET
    exchange_name = EXCLUDED.exchange_name, -- EXCLUDED refers to the values that would have been inserted
    exchange_type = EXCLUDED.exchange_type;
    -- exchange_key is not updated as it's the PK of the dimension.

-- Verify (optional, run separately after INSERT)
-- SELECT COUNT(*) FROM public.dim_exchange;
-- SELECT * FROM public.dim_exchange LIMIT 10;

-- Part 4: Populate dim_transaction_category
-- Loads data from the operational transaction_categories table.
-- Handles updates to existing category details based on category_id_original.

INSERT INTO public.dim_transaction_category (
    category_id_original,
    category_name,          -- This is the column name in dim_transaction_category
    category_description    -- This is the column name in dim_transaction_category
)
SELECT
    tc.category_id,         -- This is original_id from public.transaction_categories
    tc.name,                -- Assuming 'name' is the column in public.transaction_categories for the category's name
                            -- If it's 'category_name', use tc.category_name here.
    tc.description          -- Assuming 'description' is the column in public.transaction_categories
                            -- If it's 'category_description', use tc.category_description here.
FROM
    public.transaction_categories AS tc -- Use your actual source table name
ON CONFLICT (category_id_original) DO UPDATE SET
    category_name = EXCLUDED.category_name,
    category_description = EXCLUDED.category_description;
    -- category_key is not updated as it's the PK of the dimension.

-- Verify (optional, run separately after INSERT)
-- SELECT COUNT(*) FROM public.dim_transaction_category;
-- SELECT * FROM public.dim_transaction_category LIMIT 10;

-- Part 5: Populate fact_transactions
-- This is the main ETL step, loading data from the operational transactions table
-- and linking to the dimension tables using their surrogate keys.

-- For a clean run if repopulating, you might TRUNCATE public.fact_transactions; first.
-- The ON CONFLICT here handles updates if a transaction is somehow modified in the source
-- and you re-run the ETL (based on tx_id_original).

INSERT INTO public.fact_transactions (
    tx_id_original,
    date_key,
    time_of_day,
    crypto_key,
    exchange_key,
    category_key,
    tx_type,
    quantity,
    price_per_unit_usd,
    transaction_value_usd,
    fee_usd
)
SELECT
    t.tx_id AS tx_id_original,
    -- Lookup date_key from dim_date based on the transaction's date part
    -- The TO_CHAR and ::INTEGER conversion for date_key must match how dim_date.date_key was populated
    (SELECT dd.date_key FROM public.dim_date dd WHERE dd.full_date = DATE(t.tx_timestamp)),
    t.tx_timestamp::TIME AS time_of_day, -- Extract time component

    -- Lookup crypto_key from dim_cryptocurrency
    (SELECT dc.crypto_key FROM public.dim_cryptocurrency dc WHERE dc.crypto_id_original = t.crypto_id),

    -- Lookup exchange_key from dim_exchange (handles NULL exchange_id in transactions)
    (SELECT de.exchange_key FROM public.dim_exchange de WHERE de.exchange_id_original = t.exchange_id),

    -- Lookup category_key from dim_transaction_category (handles NULL category_id in transactions)
    (SELECT dtc.category_key FROM public.dim_transaction_category dtc WHERE dtc.category_id_original = t.category_id),

    t.tx_type,
    t.quantity,
    t.price_per_unit_usd,
    -- Pre-calculate transaction_value_usd
    (t.quantity * t.price_per_unit_usd) AS transaction_value_usd,
    t.fee_usd
FROM
    public.transactions AS t
ON CONFLICT (tx_id_original) DO UPDATE SET
    date_key = EXCLUDED.date_key,
    time_of_day = EXCLUDED.time_of_day,
    crypto_key = EXCLUDED.crypto_key,
    exchange_key = EXCLUDED.exchange_key,
    category_key = EXCLUDED.category_key,
    tx_type = EXCLUDED.tx_type,
    quantity = EXCLUDED.quantity,
    price_per_unit_usd = EXCLUDED.price_per_unit_usd,
    transaction_value_usd = EXCLUDED.transaction_value_usd,
    fee_usd = EXCLUDED.fee_usd;
    -- transaction_key is auto-generated by SERIAL for new inserts.

-- Verify (optional, run separately after INSERT)
-- SELECT COUNT(*) FROM public.fact_transactions;
-- SELECT * FROM public.fact_transactions LIMIT 10;

-- Check for transactions that didn't get a date_key (potential issue with dim_date range or tx_timestamp values)
-- SELECT t.tx_id, t.tx_timestamp
-- FROM public.transactions t
-- LEFT JOIN public.dim_date dd ON dd.full_date = DATE(t.tx_timestamp)
-- WHERE dd.date_key IS NULL;