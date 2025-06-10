-- Paste and run the CORRECTED CREATE OR REPLACE FUNCTION statement for log_transaction_changes() from my previous message
CREATE OR REPLACE FUNCTION public.log_transaction_changes()
RETURNS TRIGGER
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.transactions_audit_history (
            operation_type, tx_id, crypto_id, exchange_id, category_id, tx_type,
            quantity, price_per_unit_usd, tx_timestamp, fee_usd, notes
        )
        VALUES (
            'I', NEW.tx_id, NEW.crypto_id, NEW.exchange_id, NEW.category_id, NEW.tx_type,
            NEW.quantity, NEW.price_per_unit_usd, NEW.tx_timestamp, NEW.fee_usd, NEW.notes
        );
        RETURN NEW;

    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO public.transactions_audit_history (
            operation_type, tx_id, crypto_id, exchange_id, category_id, tx_type,
            quantity, price_per_unit_usd, tx_timestamp, fee_usd, notes
        )
        VALUES (
            'U', OLD.tx_id, OLD.crypto_id, OLD.exchange_id, OLD.category_id, OLD.tx_type,
            OLD.quantity, OLD.price_per_unit_usd, OLD.tx_timestamp, OLD.fee_usd, OLD.notes
        );
        RETURN NEW;

    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO public.transactions_audit_history (
            operation_type, tx_id, crypto_id, exchange_id, category_id, tx_type,
            quantity, price_per_unit_usd, tx_timestamp, fee_usd, notes
        )
        VALUES (
            'D', OLD.tx_id, OLD.crypto_id, OLD.exchange_id, OLD.category_id, OLD.tx_type,
            OLD.quantity, OLD.price_per_unit_usd, OLD.tx_timestamp, OLD.fee_usd, OLD.notes
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;