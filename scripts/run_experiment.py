#!/usr/bin/env python3
"""Describe a reproducible experiment plan without publishing fabricated results."""

import argparse
import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path
from datetime import datetime, timezone

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from db.local_specs import store_spec


def load_config(path: Path) -> dict:
    with path.open(encoding="utf-8") as stream:
        if path.suffix.lower() in (".yaml", ".yml"):
            import yaml
            config = yaml.safe_load(stream)
        else:
            config = json.load(stream)
    if not isinstance(config, dict):
        raise ValueError("experiment configuration must be a mapping")
    return config


def partition_plan(config: dict) -> dict | None:
    partitions = config.get("partitions")
    if partitions is None:
        return None
    order = ("train", "validation", "test")
    if type(partitions) is not dict or set(partitions) != set(order):
        raise ValueError("partitions must contain train, validation, and test")
    result = {}
    previous_end = None
    for name in order:
        interval = partitions[name]
        if type(interval) is not dict or set(interval) != {"start", "end"}:
            raise ValueError(f"{name} requires start and end timestamps")
        bounds = []
        for value in (interval["start"], interval["end"]):
            if type(value) is not str:
                raise ValueError(f"{name} boundaries must be quoted ISO timestamps")
            bound = datetime.fromisoformat(value)
            if bound.utcoffset() is None:
                raise ValueError(f"{name} boundaries must include a timezone")
            bounds.append(bound.astimezone(timezone.utc))
        start, end = bounds
        if start >= end or (previous_end is not None and start < previous_end):
            raise ValueError("partitions must be nonempty, chronological, and disjoint")
        result[name] = {"start": start.isoformat(), "end": end.isoformat()}
        previous_end = end
    return result



def experiment_plan(args: argparse.Namespace) -> dict:
    config = load_config(args.config)
    partitions = partition_plan(config)
    repo = Path(__file__).resolve().parents[1]
    revision = subprocess.check_output(
        ["git", "-C", str(repo), "rev-parse", "HEAD"], text=True
    ).strip()
    spec = {
        "schema_version": 1,
        "name": args.name,
        "description": args.description,
        "strategy": args.strategy_name,
        "config": config,
        "partitions_utc": partitions,
        "seed": config.get("seed", 42),
        "code_commit": revision,
        "runner_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "python": platform.python_version(),
    }
    canonical = json.dumps(spec, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return {
        "experiment_id": hashlib.sha256(canonical.encode("utf-8")).hexdigest(),
        "spec": spec,
        "run_label": args.run_label,
        "status": "insufficient",
        "reason": "No evaluator ran and no metrics were produced.",
    }


def main():
    parser = argparse.ArgumentParser(description="Inspect an experiment plan")
    parser.add_argument("--name", required=True)
    parser.add_argument("--description", default="")
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--run-label", default="")
    parser.add_argument("--strategy-name", default="baseline_strategy")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--ledger", type=Path, help="Optional local SQLite spec ledger")
    args = parser.parse_args()
    if not args.dry_run:
        parser.error("this runner has no implemented evaluator; use --dry-run")
    try:
        plan = experiment_plan(args)
        if args.ledger is not None:
            store_spec(args.ledger, plan["spec"])
        print(json.dumps(plan, sort_keys=True, indent=2))
    except (ValueError, TypeError, OSError, subprocess.CalledProcessError) as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    main()
