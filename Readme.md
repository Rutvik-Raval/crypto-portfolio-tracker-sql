# Comprehensive Crypto Portfolio Tracker & Analyzer (PostgreSQL Project)

## Project Overview
This project implements a PostgreSQL-based system to track cryptocurrency transactions, analyze portfolio performance, and gain insights into investment strategies. The system provides accurate tracking of crypto holdings, calculates performance metrics, assists with tax preparation (FIFO method demonstrated), and offers sophisticated analytics capabilities.

**Why This Matters:**
*   **Financial Insight:** Gain clear visibility into crypto investments, performance, and tax implications.
*   **Data-Driven Decisions:** Use historical analysis to improve future investment strategies.
*   **SQL Skill Development:** Build expertise in PostgreSQL from basic to advanced concepts.
*   **Portfolio Management:** Maintain a single source of truth for all crypto assets.

## Technology Stack
*   **Database:** PostgreSQL
*   **Language:** SQL (including PL/pgSQL for functions and triggers)
*   **Tooling (for development/interaction):** DBeaver (or any preferred SQL client)

## Directory Structure
The project's SQL scripts are organized into folders corresponding to the development phases and utility types:
*   `00_setup_ddl/`: Contains DDL scripts for initial table, index, and function creation.
*   `01_utils/`: Utility scripts for tasks like setting sequences post-import.
*   `02_phase2_core_tracking/`: SQL queries for core portfolio tracking and basic metrics.
*   `03_phase3_advanced_analytics/`: SQL queries and function DDL for advanced analytics (technical indicators, tax calculations, performance).
    *   `functions/`: Stores DDL for reusable SQL functions.
    *   `queries/`: Stores advanced analytical SQL queries.
*   `04_phase4_optimization_auditing/`: Scripts related to query optimization, auditing, data quality, and materialized views.
    *   `optimization_notes/`: Contains files documenting the query optimization process.
*   `05_phase5_dwh_scalability/`: Scripts for creating and populating the analytical data warehouse (star schema) and reporting views.
*   `misc/`: Contains intermediary analysis scripts, ad-hoc test queries, and verification snippets.
    *   `intermediary_analysis/`
    *   `tests/`
*   `data/`: (User-created folder) Intended for storing sample CSV data files used for initial data import.

## Setup Instructions

1.  **Create PostgreSQL Database:**
    *   Create a new PostgreSQL database (e.g., `crypto_portfolio`).
2.  **Run Schema and Core DDL Scripts:** Execute the following scripts from the `00_setup_ddl/` folder in order:
    *   `00_schema_core_tables.sql` (Creates main operational tables and their basic indexes)
    *   `00b_optimized_indexes.sql` (Creates additional indexes identified during optimization)
    *   `00c_create_functions.sql` (Creates `fn_get_historical_holdings` and `fn_get_portfolio_value_at_date`)
3.  **Import Initial Data:**
    *   Populate the core operational tables (`cryptocurrencies`, `exchanges`, `transaction_categories`, `transactions`, `historical_prices`) with your data. This project assumes data is imported from CSV files.
    *   You can use a tool like DBeaver's CSV import wizard or PostgreSQL's `COPY` command.
    *   Sample CSVs should be placed in a `data/` directory (not included in this Git repo, user provides their own).
4.  **Set Table Sequences:** After importing data with explicit IDs into tables with `SERIAL` primary keys, run:
    *   `01_utils/01_utils_set_sequences.sql`
5.  **Setup Audit System & Materialized View (Phase 4):**
    *   `04_phase4_optimization_auditing/04_02_setup_audit_system.sql` (Creates audit table, trigger function, and trigger)
    *   `04_phase4_optimization_auditing/04_03_create_materialized_view_holdings_summary.sql`
    *   `(Optional) 04_phase4_optimization_auditing/04_04_create_user_annotations_table.sql`
6.  **Setup Analytical Data Warehouse (Phase 5):**
    *   `05_phase5_dwh_scalability/05_02_create_analytics_star_schema_ddl.sql` (Creates empty DWH dimension and fact tables)
    *   `05_phase5_dwh_scalability/05_03_etl_populate_star_schema.sql` (Populates `dim_date`, other dimensions, and `fact_transactions`)
7.  **Create Reporting View (Phase 5):**
    *   `05_phase5_dwh_scalability/05_04_reporting_view_dashboard_summary.sql`

## SQL Scripts Overview & Purpose

### Phase 1: Foundation (Covered by `00_setup_ddl/` scripts)
This phase established the core database structure.

### Phase 2: Core Portfolio Tracking (Scripts in `02_phase2_core_tracking/`)
*(Here, we'll paste the short descriptions we made for each `02_...` script)*
*   **`02_01_current_holdings.sql`**: (Total Crypto In) - (Total Crypto Out) = How much of each crypto I own NOW.
*   **`02_02_historical_holdings_by_date.sql`**: (Total Crypto In by X Date) - (Total Crypto Out by X Date) = How much of each crypto I owned ON X Date. *(This logic is now primarily in `fn_01_get_historical_holdings.sql`)*
*   **`02_03_current_portfolio_value.sql`**: (How much I own of Crypto A NOW * Its Current Price) + (Crypto B NOW * Its Current Price) + ... = Total $ value of my crypto NOW.
*   **`02_04_current_asset_allocations.sql`**: ($ Value of Crypto A) / (Total $ Value of All Crypto) * 100 = What % of my portfolio is Crypto A NOW.
*   **`02_05_portfolio_value_change_daily.sql`**: (Total $ Value NOW) - (Total $ Value Yesterday) = How much my portfolio value changed since yesterday.
*   **`02_06_portfolio_value_change_between_dates.sql`**: (Total $ Value on End Date) - (Total $ Value on Start Date) = How much my portfolio value changed between two specific dates.
*   **`02_07_transaction_frequency_by_month.sql`**: Counts how many transactions (total, buys, sells) I made each month.
*   **`02_08_average_purchase_price_by_asset.sql`**: (Total $ I spent buying Crypto A) / (Total amount of Crypto A I bought) = Average $ price I paid for each unit of Crypto A.
*   **`02_09_transaction_analysis_by_exchange.sql`**: Shows which exchanges I use most for buys/sells and the $ value traded there.

### Phase 3: Advanced Analytics (Scripts in `03_phase3_advanced_analytics/queries/` and `.../functions/`)
*(Paste short descriptions for `03_...` scripts and functions)*
*   **`functions/fn_01_get_historical_holdings.sql`**: Creates a reusable function `get_historical_holdings(date)` to get asset quantities on a specific past date.
*   **`functions/fn_02_get_portfolio_value_at_date.sql`**: Creates a reusable function `get_portfolio_value_at_date(date)` to get total portfolio USD value on a specific past date.
*   **`queries/03_01_moving_averages.sql`**: Calculates 7-day and 30-day simple moving averages for asset prices.
*   **`queries/03_02_relative_strength_index_14day.sql`**: Calculates the 14-period RSI momentum indicator for asset prices.
*   **`queries/03_03_price_correlation_with_btc.sql`**: Calculates price correlation of other crypto assets with Bitcoin.
*   **`queries/03_04_realized_gains_losses_fifo_single_asset_detailed.sql`**: Detailed FIFO calculation showing how specific buy lots cover sales for one asset.
*   **`queries/03_05_realized_gains_losses_fifo_summary_per_sale.sql`**: Summarizes FIFO gains/losses to one line per sale event for a single asset.
*   **`queries/03_06_annual_realized_gains_losses_fifo_single_asset.sql`**: Annual summary of FIFO realized gains/losses for a single asset.
*   **`queries/03_07_price_volatility_30day.sql`**: Calculates 30-day rolling standard deviation of daily returns (volatility).
*   **`queries/03_08_realized_gains_losses_fifo_all_assets_summary.sql`**: FIFO summary of realized gains/losses per sale event, for ALL assets.
*   **`queries/03_09_annual_realized_gains_losses_fifo_all_assets.sql`**: Annual summary of FIFO realized gains/losses for ALL assets.
*   **`queries/03_13_tax_lot_inventory_current.sql`**: Shows current unsold tax lots (original BUYs) based on FIFO consumption.
*   **`queries/03_14_portfolio_performance_vs_btc_benchmark.sql`**: Compares portfolio growth against a hypothetical BTC investment.

### Phase 4: Optimization & Auditing (Scripts in `04_phase4_optimization_auditing/`)
*(Paste short descriptions for `04_...` scripts)*
*   **`optimization_notes/04_01a_optimize_current_holdings.sql` & `04_01b_optimize_current_portfolio_value.sql`**: Contain `EXPLAIN ANALYZE` commands and notes documenting the query optimization process and impact of new indexes.
*   **`04_02_setup_audit_system.sql`**: Creates the `transactions_audit_history` table, trigger function, and trigger to log all DML operations on the `transactions` table.
*   **`04_03_create_materialized_view_holdings_summary.sql`**: Creates a materialized view (`mv_current_holdings`) to pre-calculate current holdings for faster read access.
*   **`04_04_create_user_annotations_table.sql`**: (If implemented) DDL for a table to allow user-added notes to transactions.
*   **`04_05_data_quality_checks.sql`**: A collection of queries to identify potential data quality issues (e.g., missing prices, orphaned records, stale price data).

### Phase 5: Data Architecture & Scalability (Scripts in `05_phase5_dwh_scalability/`)
*(Paste short descriptions for `05_...` scripts)*
*   **`05_02_create_analytics_star_schema_ddl.sql`**: DDL to create the dimension (`dim_date`, `dim_cryptocurrency`, etc.) and fact (`fact_transactions`) tables for the analytical data warehouse.
*   **`05_03_etl_populate_star_schema.sql`**: SQL script containing `INSERT` statements to populate the dimension tables and then the `fact_transactions` table from the operational data.
*   **`05_04_reporting_view_dashboard_summary.sql`**: Creates `view_monthly_crypto_transaction_summary` on top of the star schema for easy monthly reporting per asset.

### Intermediary & Test Scripts (In `misc/` folder)
The `misc/` folder contains various ad-hoc exploratory analysis scripts (`intermediary_analysis/`) and queries used for testing specific functionalities (`tests/`). These are not part of the main setup or analytical workflow but provide useful utilities and verification methods.

## Future Enhancements (Deferred Items)
*   Implementation of Time-Weighted Return (TWR) for more precise performance measurement.
*   LIFO (Last-In, First-Out) tax calculation methods.
*   Table partitioning for very large `transactions` and `historical_prices` tables.
*   More sophisticated ETL automation and error handling.
*   Advanced "what-if" scenario analysis functions.

## Conclusion
This project provides a comprehensive SQL-based framework for cryptocurrency portfolio tracking and analysis. It demonstrates database design, complex querying for financial metrics, tax calculations, performance optimization, and foundational data warehousing concepts.
