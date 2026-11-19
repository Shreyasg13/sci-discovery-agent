import sqlite3
import unittest
from contextlib import closing
from pathlib import Path
from tempfile import TemporaryDirectory

from db.local_specs import store_spec


class LocalSpecTests(unittest.TestCase):
    def test_replay_and_revision(self):
        with TemporaryDirectory() as directory:
            ledger = Path(directory) / "ledger.db"
            first = store_spec(ledger, {"seed": 42, "name": "sample"})
            self.assertEqual(first, store_spec(ledger, {"name": "sample", "seed": 42}))
            second = store_spec(ledger, {"name": "sample", "seed": 43})
            self.assertNotEqual(first, second)
            with closing(sqlite3.connect(ledger)) as connection:
                self.assertEqual(connection.execute(
                    "SELECT canonical_json FROM experiment_specs WHERE id = ?", (first,)
                ).fetchone(), ('{"name":"sample","seed":42}',))
                self.assertEqual(connection.execute(
                    "SELECT COUNT(*) FROM experiment_specs"
                ).fetchone(), (2,))
