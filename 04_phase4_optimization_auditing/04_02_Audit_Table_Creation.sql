DROP TABLE IF EXISTS public.transactions_audit_history;
-- Paste and run the CORRECTED CREATE TABLE statement for transactions_audit_history from my previous message
CREATE TABLE IF NOT EXISTS public.transactions_audit_history (
    audit_id BIGSERIAL PRIMARY KEY,
    operation_type CHAR(1) NOT NULL,
    operation_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tx_id BIGINT,
    crypto_id INTEGER,
    exchange_id INTEGER,
    category_id INTEGER,
    tx_type VARCHAR(50),
    quantity NUMERIC(28, 18),
    price_per_unit_usd NUMERIC(24, 8),
    tx_timestamp TIMESTAMPTZ,
    fee_usd NUMERIC(18, 8),
    notes TEXT
);