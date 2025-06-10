-- Dimension Table: dim_date
-- This table should be pre-populated with a range of dates relevant to your data.
CREATE TABLE IF NOT EXISTS public.dim_date (
    date_key INTEGER PRIMARY KEY,       -- Example: 20230115 for January 15, 2023
    full_date DATE NOT NULL UNIQUE,
    year_actual INTEGER NOT NULL,
    quarter_actual INTEGER NOT NULL,    -- 1, 2, 3, 4
    month_actual INTEGER NOT NULL,      -- 1 through 12
    month_name VARCHAR(20) NOT NULL,    -- e.g., 'January', 'February'
    day_of_month INTEGER NOT NULL,      -- 1 through 31
    day_of_week_iso INTEGER NOT NULL,   -- 1 for Monday through 7 for Sunday (ISO 8601 standard)
    day_name VARCHAR(20) NOT NULL,      -- e.g., 'Monday', 'Tuesday'
    week_of_year_iso INTEGER NOT NULL,  -- ISO 8601 week number
    is_weekday BOOLEAN NOT NULL,
    is_weekend BOOLEAN NOT NULL
);

COMMENT ON TABLE public.dim_date IS 'Date dimension table for analytics, storing various date attributes.';

-- Dimension Table: dim_cryptocurrency
CREATE TABLE IF NOT EXISTS public.dim_cryptocurrency (
    crypto_key SERIAL PRIMARY KEY, -- New surrogate key
    crypto_id_original INTEGER UNIQUE, -- Original ID from OLTP for joining during ETL
    symbol VARCHAR(20) NOT NULL,
    name VARCHAR(100) NOT NULL,
    -- Add other attributes you want to analyze by, e.g., is_stablecoin
    is_stablecoin BOOLEAN
);

COMMENT ON TABLE public.dim_cryptocurrency IS 'Cryptocurrency dimension table.';

-- Dimension Table: dim_exchange
CREATE TABLE IF NOT EXISTS public.dim_exchange (
    exchange_key SERIAL PRIMARY KEY,
    exchange_id_original INTEGER UNIQUE,
    exchange_name VARCHAR(100) NOT NULL, -- Assuming 'name' is the column in your source exchanges table
    exchange_type VARCHAR(50)
);

COMMENT ON TABLE public.dim_exchange IS 'Exchange/Wallet dimension table.';

-- Dimension Table: dim_transaction_category
CREATE TABLE IF NOT EXISTS public.dim_transaction_category (
    category_key SERIAL PRIMARY KEY,
    category_id_original INTEGER UNIQUE,
    category_name VARCHAR(100) NOT NULL, -- Assuming 'name' or 'category_name' in your source
    category_description TEXT
);

COMMENT ON TABLE public.dim_transaction_category IS 'Transaction category dimension table.';

CREATE TABLE IF NOT EXISTS public.fact_transactions (
-- Fact Table: fact_transactions
    transaction_key BIGSERIAL PRIMARY KEY, -- Surrogate key for the fact table
    tx_id_original BIGINT NOT NULL UNIQUE,  -- Original transaction ID for traceability

    -- Dimension Foreign Keys
    date_key INTEGER NOT NULL REFERENCES public.dim_date(date_key),
    time_of_day TIME, -- Optional: Extracted from original tx_timestamp if needed for intra-day analysis
    crypto_key INTEGER NOT NULL REFERENCES public.dim_cryptocurrency(crypto_key),
    exchange_key INTEGER REFERENCES public.dim_exchange(exchange_key), -- Nullable if source can be null
    category_key INTEGER REFERENCES public.dim_transaction_category(category_key), -- Nullable

    -- Degenerate Dimension (attributes directly in fact table that don't warrant their own dim)
    tx_type VARCHAR(50) NOT NULL,

    -- Measures (Numeric Facts)
    quantity NUMERIC(28, 18) NOT NULL,
    price_per_unit_usd NUMERIC(24, 8),
    transaction_value_usd NUMERIC(30, 8), -- Pre-calculated: quantity * price_per_unit_usd
    fee_usd NUMERIC(18, 8)
);

COMMENT ON TABLE public.fact_transactions IS 'Fact table storing transactional data with measures and links to dimensions.';
COMMENT ON COLUMN public.fact_transactions.tx_id_original IS 'Original tx_id from the operational transactions table.';
COMMENT ON COLUMN public.fact_transactions.date_key IS 'FK to dim_date, representing the date of the transaction.';
COMMENT ON COLUMN public.fact_transactions.time_of_day IS 'Optional: The time component of the original transaction timestamp.';
COMMENT ON COLUMN public.fact_transactions.transaction_value_usd IS 'Pre-calculated during ETL as quantity * price_per_unit_usd.';

-- Optional: Indexes on Fact Table Foreign Keys for join performance (often very beneficial)
CREATE INDEX IF NOT EXISTS idx_fact_transactions_date_key ON public.fact_transactions(date_key);
CREATE INDEX IF NOT EXISTS idx_fact_transactions_crypto_key ON public.fact_transactions(crypto_key);
CREATE INDEX IF NOT EXISTS idx_fact_transactions_exchange_key ON public.fact_transactions(exchange_key);
CREATE INDEX IF NOT EXISTS idx_fact_transactions_category_key ON public.fact_transactions(category_key);