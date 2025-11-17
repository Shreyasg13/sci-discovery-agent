-- 1) Instruments (symbols / markets you trade)
CREATE TABLE IF NOT EXISTS instruments (
    id           SERIAL PRIMARY KEY,
    symbol       TEXT NOT NULL,
    venue        TEXT NOT NULL DEFAULT 'UNKNOWN',  -- e.g. BINANCE, NSE, CME
    asset_class  TEXT NOT NULL DEFAULT 'UNKNOWN',  -- e.g. EQUITY, FUTURE, CRYPTO
    currency     TEXT NOT NULL DEFAULT 'USD',
    tick_size    NUMERIC(18,8),
    metadata     JSONB DEFAULT '{}'::jsonb,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (symbol, venue)
);

-- 2) Time-series OHLCV (generic across timeframes)
CREATE TABLE IF NOT EXISTS ohlcv_series (
    id            BIGSERIAL PRIMARY KEY,
    instrument_id INTEGER NOT NULL REFERENCES instruments(id) ON DELETE CASCADE,
    timeframe     TEXT NOT NULL,                  -- e.g. '1m', '5m', '1h', '1d'
    ts            TIMESTAMPTZ NOT NULL,           -- bar start time
    open          NUMERIC(18,8) NOT NULL,
    high          NUMERIC(18,8) NOT NULL,
    low           NUMERIC(18,8) NOT NULL,
    close         NUMERIC(18,8) NOT NULL,
    volume        NUMERIC(30,8),
    vwap          NUMERIC(18,8),
    raw_source    TEXT,                           -- e.g. 'BINANCE_API', 'CSV_IMPORT'
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (instrument_id, timeframe, ts)
);

CREATE INDEX IF NOT EXISTS idx_ohlcv_instr_tf_ts
    ON ohlcv_series (instrument_id, timeframe, ts DESC);

-- 3) Experiments (a “discovery run” or research idea)
CREATE TABLE IF NOT EXISTS experiments (
    id            BIGSERIAL PRIMARY KEY,
    name          TEXT NOT NULL,
    description   TEXT,
    config_json   JSONB NOT NULL,                 -- hyperparams, universe, features, etc.
    created_by    TEXT DEFAULT 'shrey',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status        TEXT NOT NULL DEFAULT 'NEW',    -- NEW / RUNNING / DONE / FAILED
    UNIQUE (name)
);

-- 4) Experiment runs (multiple runs per experiment under different seeds, time ranges, etc.)
CREATE TABLE IF NOT EXISTS experiment_runs (
    id              BIGSERIAL PRIMARY KEY,
    experiment_id   BIGINT NOT NULL REFERENCES experiments(id) ON DELETE CASCADE,
    run_label       TEXT,                         -- e.g. 'seed=42', '2020-2022-eq-only'
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMPTZ,
    status          TEXT NOT NULL DEFAULT 'RUNNING',  -- RUNNING / DONE / FAILED
    params_json     JSONB NOT NULL DEFAULT '{}'::jsonb,
    metrics_json    JSONB NOT NULL DEFAULT '{}'::jsonb,  -- sr, max_dd, win_rate, etc.
    logs_ref        TEXT,                         -- pointer to S3 path or log file
    error_message   TEXT
);

CREATE INDEX IF NOT EXISTS idx_experiment_runs_experiment_id
    ON experiment_runs (experiment_id, started_at DESC);

-- 5) Backtest results (aggregated performance per strategy candidate)
CREATE TABLE IF NOT EXISTS backtest_results (
    id                BIGSERIAL PRIMARY KEY,
    experiment_run_id BIGINT NOT NULL REFERENCES experiment_runs(id) ON DELETE CASCADE,
    strategy_name     TEXT NOT NULL,
    asset_universe    TEXT,                             -- e.g. 'NIFTY_50', 'BTC_PERP'
    train_period      TSTZRANGE,                        -- [start, end)
    test_period       TSTZRANGE,
    sharpe_ratio      NUMERIC(18,8),
    sortino_ratio     NUMERIC(18,8),
    max_drawdown      NUMERIC(18,8),
    annual_return     NUMERIC(18,8),
    pnl_currency      TEXT DEFAULT 'USD',
    meta_json         JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_backtest_results_experiment_run
    ON backtest_results (experiment_run_id);

-- 6) Simple table for tracking raw imports (so agents can know what data exists)
CREATE TABLE IF NOT EXISTS data_import_log (
    id            BIGSERIAL PRIMARY KEY,
    source        TEXT NOT NULL,                   -- 'BINANCE', 'CSV', 'BACKFILL'
    instrument_id INTEGER REFERENCES instruments(id),
    timeframe     TEXT,
    ts_start      TIMESTAMPTZ,
    ts_end        TIMESTAMPTZ,
    s3_path       TEXT,                            -- where raw file is stored
    row_count     BIGINT,
    checksum      TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- 1) Instruments (symbols / markets you trade)
CREATE TABLE IF NOT EXISTS instruments (
    id           SERIAL PRIMARY KEY,
    symbol       TEXT NOT NULL,
    venue        TEXT NOT NULL DEFAULT 'UNKNOWN',  -- e.g. BINANCE, NSE, CME
    asset_class  TEXT NOT NULL DEFAULT 'UNKNOWN',  -- e.g. EQUITY, FUTURE, CRYPTO
    currency     TEXT NOT NULL DEFAULT 'USD',
    tick_size    NUMERIC(18,8),
    metadata     JSONB DEFAULT '{}'::jsonb,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (symbol, venue)
);

-- 2) Time-series OHLCV (generic across timeframes)
CREATE TABLE IF NOT EXISTS ohlcv_series (
    id            BIGSERIAL PRIMARY KEY,
    instrument_id INTEGER NOT NULL REFERENCES instruments(id) ON DELETE CASCADE,
    timeframe     TEXT NOT NULL,                  -- e.g. '1m', '5m', '1h', '1d'
    ts            TIMESTAMPTZ NOT NULL,           -- bar start time
    open          NUMERIC(18,8) NOT NULL,
    high          NUMERIC(18,8) NOT NULL,
    low           NUMERIC(18,8) NOT NULL,
    close         NUMERIC(18,8) NOT NULL,
    volume        NUMERIC(30,8),
    vwap          NUMERIC(18,8),
    raw_source    TEXT,                           -- e.g. 'BINANCE_API', 'CSV_IMPORT'
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (instrument_id, timeframe, ts)
);

CREATE INDEX IF NOT EXISTS idx_ohlcv_instr_tf_ts
    ON ohlcv_series (instrument_id, timeframe, ts DESC);

-- 3) Experiments (a “discovery run” or research idea)
CREATE TABLE IF NOT EXISTS experiments (
    id            BIGSERIAL PRIMARY KEY,
    name          TEXT NOT NULL,
    description   TEXT,
    config_json   JSONB NOT NULL,                 -- hyperparams, universe, features, etc.
    created_by    TEXT DEFAULT 'shrey',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status        TEXT NOT NULL DEFAULT 'NEW',    -- NEW / RUNNING / DONE / FAILED
    UNIQUE (name)
);

-- 4) Experiment runs (multiple runs per experiment under different seeds, time ranges, etc.)
CREATE TABLE IF NOT EXISTS experiment_runs (
    id              BIGSERIAL PRIMARY KEY,
    experiment_id   BIGINT NOT NULL REFERENCES experiments(id) ON DELETE CASCADE,
    run_label       TEXT,                         -- e.g. 'seed=42', '2020-2022-eq-only'
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMPTZ,
    status          TEXT NOT NULL DEFAULT 'RUNNING',  -- RUNNING / DONE / FAILED
    params_json     JSONB NOT NULL DEFAULT '{}'::jsonb,
    metrics_json    JSONB NOT NULL DEFAULT '{}'::jsonb,  -- sr, max_dd, win_rate, etc.
    logs_ref        TEXT,                         -- pointer to S3 path or log file
    error_message   TEXT
);

CREATE INDEX IF NOT EXISTS idx_experiment_runs_experiment_id
    ON experiment_runs (experiment_id, started_at DESC);

-- 5) Backtest results (aggregated performance per strategy candidate)
CREATE TABLE IF NOT EXISTS backtest_results (
    id                BIGSERIAL PRIMARY KEY,
    experiment_run_id BIGINT NOT NULL REFERENCES experiment_runs(id) ON DELETE CASCADE,
    strategy_name     TEXT NOT NULL,
    asset_universe    TEXT,                             -- e.g. 'NIFTY_50', 'BTC_PERP'
    train_period      TSTZRANGE,                        -- [start, end)
    test_period       TSTZRANGE,
    sharpe_ratio      NUMERIC(18,8),
    sortino_ratio     NUMERIC(18,8),
    max_drawdown      NUMERIC(18,8),
    annual_return     NUMERIC(18,8),
    pnl_currency      TEXT DEFAULT 'USD',
    meta_json         JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_backtest_results_experiment_run
    ON backtest_results (experiment_run_id);

-- 6) Simple table for tracking raw imports (so agents can know what data exists)
CREATE TABLE IF NOT EXISTS data_import_log (
    id            BIGSERIAL PRIMARY KEY,
    source        TEXT NOT NULL,                   -- 'BINANCE', 'CSV', 'BACKFILL'
    instrument_id INTEGER REFERENCES instruments(id),
    timeframe     TEXT,
    ts_start      TIMESTAMPTZ,
    ts_end        TIMESTAMPTZ,
    s3_path       TEXT,                            -- where raw file is stored
    row_count     BIGINT,
    checksum      TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
