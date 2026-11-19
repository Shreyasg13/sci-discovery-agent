"""Local, content-addressed storage for experiment plans."""

import hashlib
import json
import sqlite3
from contextlib import closing
from pathlib import Path


def store_spec(database: Path, spec: dict) -> str:
    canonical = json.dumps(spec, sort_keys=True, separators=(",", ":"), allow_nan=False)
    experiment_id = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    with closing(sqlite3.connect(database)) as connection, connection:
        connection.execute(
            "CREATE TABLE IF NOT EXISTS experiment_specs "
            "(id TEXT PRIMARY KEY, canonical_json TEXT NOT NULL)"
        )
        connection.execute(
            "INSERT INTO experiment_specs (id, canonical_json) VALUES (?, ?) "
            "ON CONFLICT (id) DO NOTHING",
            (experiment_id, canonical),
        )
        stored, = connection.execute(
            "SELECT canonical_json FROM experiment_specs WHERE id = ?", (experiment_id,)
        ).fetchone()
        if stored != canonical:
            raise ValueError("stored experiment spec does not match its content hash")
    return experiment_id
