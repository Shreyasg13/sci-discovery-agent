#!/usr/bin/env python3
"""Describe a reproducible experiment plan without publishing fabricated results."""

import argparse
import hashlib
import json
import platform
import subprocess
from pathlib import Path


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


def experiment_plan(args: argparse.Namespace) -> dict:
    config = load_config(args.config)
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
    args = parser.parse_args()
    if not args.dry_run:
        parser.error("this runner has no implemented evaluator; use --dry-run")
    try:
        print(json.dumps(experiment_plan(args), sort_keys=True, indent=2))
    except (ValueError, TypeError, OSError, subprocess.CalledProcessError) as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    main()
