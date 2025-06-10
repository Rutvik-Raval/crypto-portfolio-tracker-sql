-- Create tables for the cryptocurrency portfolio tracker
CREATE TABLE cryptocurrencies (
    crypto_id SERIAL PRIMARY KEY,
    symbol VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE exchanges (
    exchange_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    exchange_type VARCHAR(20) NOT NULL CHECK (exchange_type IN ('EXCHANGE', 'WALLET', 'OTHER'))
);

CREATE TABLE transaction_categories (
    category_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE transactions (
    tx_id SERIAL PRIMARY KEY,
    crypto_id INTEGER NOT NULL REFERENCES cryptocurrencies(crypto_id),
    exchange_id INTEGER REFERENCES exchanges(exchange_id),
    category_id INTEGER REFERENCES transaction_categories(category_id),
    tx_type VARCHAR(20) NOT NULL CHECK (tx_type IN ('BUY', 'SELL', 'DEPOSIT', 'WITHDRAWAL')),
    quantity DECIMAL(18, 8) NOT NULL,
    price_per_unit_usd DECIMAL(18, 8), -- NULL for transfers
    tx_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    fee_usd DECIMAL(10, 4),
    notes TEXT
);

CREATE TABLE historical_prices (
    price_id SERIAL PRIMARY KEY,
    crypto_id INTEGER NOT NULL REFERENCES cryptocurrencies(crypto_id),
    price_date DATE NOT NULL,
    close_price_usd DECIMAL(18, 8) NOT NULL,
    open_price_usd DECIMAL(18, 8),
    high_price_usd DECIMAL(18, 8),
    low_price_usd DECIMAL(18, 8),
    volume_usd DECIMAL(24, 2),
    UNIQUE (crypto_id, price_date)
);

-- Create indexes for better performance
CREATE INDEX idx_transactions_crypto_id ON transactions(crypto_id);
CREATE INDEX idx_transactions_tx_timestamp ON transactions(tx_timestamp);
CREATE INDEX idx_historical_prices_crypto_id_price_date ON historical_prices(crypto_id, price_date);



-- Check if we have data in our tables
-- This query counts the number of rows in each table to verify data was imported

SELECT 'cryptocurrencies' AS table_name, COUNT(*) AS row_count FROM cryptocurrencies
UNION ALL
SELECT 'exchanges' AS table_name, COUNT(*) AS row_count FROM exchanges
UNION ALL
SELECT 'transaction_categories' AS table_name, COUNT(*) AS row_count FROM transaction_categories
UNION ALL
SELECT 'transactions' AS table_name, COUNT(*) AS row_count FROM transactions
UNION ALL
SELECT 'historical_prices' AS table_name, COUNT(*) AS row_count FROM historical_prices;