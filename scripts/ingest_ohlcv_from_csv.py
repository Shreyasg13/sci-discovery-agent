#!/usr/bin/env python3
"""
Ingest OHLCV data from a local CSV file into the ohlcv_series table.

Assumes a CSV with at least these columns:
    timestamp, open, high, low, close
Optional columns:
    volume, vwap

Example:
    python scripts/ingest_ohlcv_from_csv.py \
        --symbol BTCUSDT \
        --venue BINANCE \
        --timeframe 1h \
        --csv-path data/btcusdt_1h.csv \
        --source BINANCE_SPOT
"""

import argparse
import hashlib
import logging
from datetime import timezone
import sys
import os
import pandas as pd
import yaml

from db.connection import db_cursor

# Add project root to sys.path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from db.connection import db_cursor

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)


def upsert_instrument(symbol: str, venue: str, asset_class: str, currency: str) -> int:
    """Insert or update an instrument and return its id."""
    with db_cursor() as cur:
        cur.execute(
            """
            INSERT INTO instruments (symbol, venue, asset_class, currency)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (symbol, venue)
            DO UPDATE SET
                asset_class = EXCLUDED.asset_class,
                currency    = EXCLUDED.currency
            RETURNING id;
            """,
            (symbol, venue, asset_class, currency),
        )
        row = cur.fetchone()
        return row["id"]


def compute_checksum(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def ingest_csv(
    csv_path: str,
    symbol: str,
    venue: str,
    timeframe: str,
    source: str,
    asset_class: str = "UNKNOWN",
    currency: str = "USD",
    time_column: str = "timestamp",
):
    logging.info("Reading CSV from %s", csv_path)
    df = pd.read_csv(csv_path)

    required_cols = {"open", "high", "low", "close"}
    missing = required_cols - set(df.columns)
    if missing:
        raise ValueError(f"CSV missing required columns: {missing}")

    if time_column not in df.columns:
        raise ValueError(f"CSV missing time column '{time_column}'")

    # Normalize timestamp to timezone-aware UTC
    df[time_column] = pd.to_datetime(df[time_column], utc=True)
    df = df.sort_values(time_column)

    # Fill optional columns if missing
    for col in ["volume", "vwap"]:
        if col not in df.columns:
            df[col] = None

    instrument_id = upsert_instrument(symbol, venue, asset_class, currency)
    logging.info("Using instrument_id=%s", instrument_id)

    rows = []
    for _, row in df.iterrows():
        rows.append(
            (
                instrument_id,
                timeframe,
                row[time_column].to_pydatetime().astimezone(timezone.utc),
                float(row["open"]),
                float(row["high"]),
                float(row["low"]),
                float(row["close"]),
                None if pd.isna(row["volume"]) else float(row["volume"]),
                None if pd.isna(row["vwap"]) else float(row["vwap"]),
                source,
            )
        )

    logging.info("Prepared %d OHLCV rows", len(rows))

    # Insert in chunks to avoid huge statements
    chunk_size = 1000
    inserted = 0
    with db_cursor() as cur:
        for i in range(0, len(rows), chunk_size):
            chunk = rows[i : i + chunk_size]
            cur.executemany(
                """
                INSERT INTO ohlcv_series
                    (instrument_id, timeframe, ts, open, high, low, close, volume, vwap, raw_source)
                VALUES
                    (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (instrument_id, timeframe, ts)
                DO NOTHING;
                """,
                chunk,
            )
            inserted += cur.rowcount

    logging.info("Inserted %d new rows into ohlcv_series", inserted)

    # Log import
    checksum = compute_checksum(csv_path)
    ts_start = df[time_column].iloc[0].to_pydatetime().astimezone(timezone.utc)
    ts_end = df[time_column].iloc[-1].to_pydatetime().astimezone(timezone.utc)

    with db_cursor() as cur:
        cur.execute(
            """
            INSERT INTO data_import_log
                (source, instrument_id, timeframe, ts_start, ts_end, s3_path, row_count, checksum)
            VALUES
                (%s, %s, %s, %s, %s, %s, %s, %s);
            """,
            (source, instrument_id, timeframe, ts_start, ts_end, csv_path, len(df), checksum),
        )

    logging.info("Recorded import in data_import_log")


def main():
    parser = argparse.ArgumentParser(description="Ingest OHLCV CSV into Postgres")
    parser.add_argument("--csv-path", required=True, help="Path to local CSV file")
    parser.add_argument("--symbol", required=True, help="Instrument symbol, e.g. BTCUSDT")
    parser.add_argument("--venue", required=True, help="Venue, e.g. BINANCE, NSE")
    parser.add_argument("--timeframe", required=True, help="Timeframe label, e.g. 1m, 1h, 1d")
    parser.add_argument("--source", required=True, help="Data source label for raw_source & import log")
    parser.add_argument("--asset-class", default="UNKNOWN", help="Asset class, e.g. EQUITY, FUTURE, CRYPTO")
    parser.add_argument("--currency", default="USD", help="Currency, default USD")
    parser.add_argument("--time-column", default="timestamp", help="Name of timestamp column in CSV")

    args = parser.parse_args()

    ingest_csv(
        csv_path=args.csv_path,
        symbol=args.symbol,
        venue=args.venue,
        timeframe=args.timeframe,
        source=args.source,
        asset_class=args.asset_class,
        currency=args.currency,
        time_column=args.time_column,
    )


if __name__ == "__main__":
    main()
