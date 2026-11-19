# Reproducible discovery

Inspect a plan locally:

    python -B scripts/run_experiment.py --name btc --config configs/btc_1h_baseline.yaml --dry-run

YAML requires PyYAML. JSON configurations use the standard library. Repeat
with the same checkout, Python version and configuration to get the same
experiment ID. The plan records code and configuration provenance. It does
not run a backtest or write to PostgreSQL. The old runner emitted placeholder
metrics. Any historical results produced by that path need separate audit.

Dataset provenance, walk-forward evaluation, a ledger, and evidence gates
are required before a research champion can be selected. Roll back this
change with a local revert only if the placeholder runner stays disconnected
from any results database.
