import unittest

from scripts.run_experiment import partition_plan


class PartitionTests(unittest.TestCase):
    def setUp(self):
        self.config = {"partitions": {
            "train": {"start": "2025-01-01T00:00Z", "end": "2025-02-01T00:00Z"},
            "validation": {"start": "2025-02-01T00:00Z", "end": "2025-03-01T00:00Z"},
            "test": {"start": "2025-03-01T00:00Z", "end": "2025-04-01T00:00Z"},
        }}

    def test_adjacent_half_open_intervals(self):
        result = partition_plan(self.config)
        self.assertEqual(result["validation"]["end"], result["test"]["start"])

    def test_overlap_across_timezones(self):
        self.config["partitions"]["test"]["start"] = "2025-03-01T00:00+01:00"
        with self.assertRaisesRegex(ValueError, "disjoint"):
            partition_plan(self.config)

    def test_naive_boundary_is_invalid(self):
        self.config["partitions"]["train"]["start"] = "2025-01-01T00:00"
        with self.assertRaisesRegex(ValueError, "timezone"):
            partition_plan(self.config)
