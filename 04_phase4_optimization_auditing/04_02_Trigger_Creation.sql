-- Script Name: 04_02_audit_trigger_transactions.sql (Part 3: Trigger Creation)
-- Purpose: Creates the trigger on the transactions table to call the audit function.

CREATE TRIGGER transactions_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.transactions -- Fire after these operations
FOR EACH ROW -- Fire for every row affected
EXECUTE FUNCTION public.log_transaction_changes();

COMMENT ON TRIGGER transactions_audit_trigger ON public.transactions IS 'Audits INSERT, UPDATE, and DELETE operations on each row of the transactions table.';