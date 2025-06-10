SELECT setval(
    pg_get_serial_sequence('public.cryptocurrencies', 'crypto_id'),
    COALESCE(MAX(crypto_id), 1),
    MAX(crypto_id) IS NOT NULL
)
FROM public.cryptocurrencies;

SELECT setval(
    pg_get_serial_sequence('public.exchanges', 'exchange_id'),
    COALESCE(MAX(exchange_id), 1),
    MAX(exchange_id) IS NOT NULL
)
FROM public.exchanges;

SELECT setval(
    pg_get_serial_sequence('public.transaction_categories', 'category_id'),
    COALESCE(MAX(category_id), 1),
    MAX(category_id) IS NOT NULL
)
FROM public.transaction_categories;

SELECT setval(
    pg_get_serial_sequence('public.transactions', 'tx_id'),
    COALESCE(MAX(tx_id), 1),
    MAX(tx_id) IS NOT NULL
)
FROM public.transactions;