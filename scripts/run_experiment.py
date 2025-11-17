#!/usr/bin/env python3
"""
Minimal experiment runner skeleton.

Usage:
    python scripts/run_experiment.py \
      --name btc_1h_baseline \
      --description "BTCUSDT 1h baseline test" \
      --config configs/btc_1h_baseline.yaml \
      --run-label "seed=42"
"""

import argparse
import json
import logging
import os
import sys
from datetime import datetime, timezone

import yaml
# Ensure project root is on sys.path so "db" can be imported when running as a script
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from db.connection import db_cursor

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)


def load_config(path: str) -> dict:
    with open(path, "r") as f:
        if path.endswith((".yaml", ".yml")):
            return yaml.safe_load(f)
        return json.load(f)


def create_or_update_experiment(name: str, description: str, config: dict) -> int:
    with db_cursor() as cur:
        cur.execute(
            """
            INSERT INTO experiments (name, description, config_json)
            VALUES (%s, %s, %s::jsonb)
            ON CONFLICT (name)
            DO UPDATE SET
                description = EXCLUDED.description,
                config_json = EXCLUDED.config_json
            RETURNING id;
            """,
            (name, description, json.dumps(config)),
        )
        row = cur.fetchone()
        experiment_id = row["id"]
        logging.info("Using experiment_id=%s", experiment_id)
        return experiment_id


def start_experiment_run(experiment_id: int, run_label: str, params: dict) -> int:
    with db_cursor() as cur:
        cur.execute(
            """
            INSERT INTO experiment_runs (experiment_id, run_label, status, params_json)
            VALUES (%s, %s, 'RUNNING', %s::jsonb)
            RETURNING id;
            """,
            (experiment_id, run_label, json.dumps(params)),
        )
        row = cur.fetchone()
        run_id = row["id"]
        logging.info("Started experiment_run_id=%s", run_id)
        return run_id


def complete_experiment_run(run_id: int, status: str, metrics: dict, logs_ref: str | None = None, error_message: str | None = None):
    finished_at = datetime.now(timezone.utc)
    with db_cursor() as cur:
        cur.execute(
            """
            UPDATE experiment_runs
            SET status = %s,
                finished_at = %s,
                metrics_json = %s::jsonb,
                logs_ref = %s,
                error_message = %s
            WHERE id = %s;
            """,
            (status, finished_at, json.dumps(metrics), logs_ref, error_message, run_id),
        )
    logging.info("Marked run %s as %s", run_id, status)


def insert_backtest_result(run_id: int, strategy_name: str, metrics: dict):
    with db_cursor() as cur:
        cur.execute(
            """
            INSERT INTO backtest_results (
                experiment_run_id,
                strategy_name,
                asset_universe,
                train_period,
                test_period,
                sharpe_ratio,
                sortino_ratio,
                max_drawdown,
                annual_return,
                pnl_currency,
                meta_json
            )
            VALUES (
                %s,
                %s,
                %s,
                tstzrange(%s, %s, '[)'),
                tstzrange(%s, %s, '[)'),
                %s,
                %s,
                %s,
                %s,
                %s,
                %s::jsonb
            )
            RETURNING id;
            """,
            (
                run_id,
                strategy_name,
                metrics.get("asset_universe", "UNKNOWN"),
                metrics.get("train_start"),
                metrics.get("train_end"),
                metrics.get("test_start"),
                metrics.get("test_end"),
                metrics.get("sharpe_ratio"),
                metrics.get("sortino_ratio"),
                metrics.get("max_drawdown"),
                metrics.get("annual_return"),
                metrics.get("pnl_currency", "USD"),
                json.dumps(metrics),
            ),
        )
        row = cur.fetchone()
        result_id = row["id"]
        logging.info("Inserted backtest_results.id=%s", result_id)
        return result_id


def main():
    parser = argparse.ArgumentParser(description="Run a single experiment + backtest")
    parser.add_argument("--name", required=True, help="Experiment name (unique)")
    parser.add_argument("--description", default="", help="Experiment description")
    parser.add_argument("--config", required=True, help="Path to JSON/YAML config file")
    parser.add_argument("--run-label", default="", help="Label for this run (e.g. seed=42)")
    parser.add_argument("--strategy-name", default="baseline_strategy", help="Strategy name label")

    args = parser.parse_args()

    config = load_config(args.config)

    # Example: derive some params from config
    params = {
        "config_path": os.path.abspath(args.config),
        "timeframe": config.get("timeframe"),
        "universe": config.get("universe"),
        "seed": config.get("seed", 42),
    }

    experiment_id = create_or_update_experiment(args.name, args.description, config)
    run_id = start_experiment_run(experiment_id, args.run_label, params)

    try:
        # TODO: here you plug in the real backtest / discovery logic
        # For now we fake some metrics so the pipeline end-to-end works.

        now = datetime.now(timezone.utc)
        metrics = {
            "sharpe_ratio": 1.23,
            "sortino_ratio": 1.80,
            "max_drawdown": -0.15,
            "annual_return": 0.32,
            "pnl_currency": "USD",
            "asset_universe": ",".join(config.get("universe", ["BTCUSDT"])),
            "train_start": now.replace(year=now.year - 2),
            "train_end": now.replace(year=now.year - 1),
            "test_start": now.replace(year=now.year - 1),
            "test_end": now,
            "timeframe": config.get("timeframe", "1h"),
        }

        insert_backtest_result(run_id, args.strategy_name, metrics)
        complete_experiment_run(run_id, "DONE", metrics, logs_ref=None)

    except Exception as e:
        logging.exception("Experiment run failed")
        complete_experiment_run(run_id, "FAILED", metrics={}, logs_ref=None, error_message=str(e))
        raise


if __name__ == "__main__":
    main()
