"""Protect balanced process order independently of reversed lane scheduling."""
from __future__ import annotations

import unittest

from benchmark_native_object_cache import LANES, aggregate_observations, comparison_order


class CacheOrderTests(unittest.TestCase):
    def test_block_retains_raw_observations_and_worst_memory(self):
        raw = [{"sha256": "same", "measurement": {"elapsed_seconds": elapsed,
            "peak_private_bytes": private, "peak_working_set_bytes": private,
            "peak_job_private_bytes": private}} for elapsed, private in ((1, 3), (3, 7))]
        block = aggregate_observations(raw)
        self.assertEqual(block["measurement"]["elapsed_seconds"], 2)
        self.assertEqual(block["measurement"]["peak_private_bytes"], 7)
        self.assertEqual(block["observations"], raw)
        raw[1]["sha256"] = "different"
        with self.assertRaises(AssertionError):
            aggregate_observations(raw)
    def test_every_lane_alternates_and_is_balanced_for_eleven_pairs(self):
        observed = {lane: [] for lane in LANES}
        for pair in range(11):
            schedule = LANES if pair % 2 == 0 else tuple(reversed(LANES))
            for lane in schedule:
                observed[lane].append(comparison_order(pair, lane))
        for lane, orders in observed.items():
            with self.subTest(lane=lane):
                self.assertEqual(set(orders), {("direct", "candidate"), ("candidate", "direct")})
                self.assertTrue(all(a != b for a, b in zip(orders, orders[1:])))
                self.assertEqual(abs(sum(o[0] == "direct" for o in orders)
                                     - sum(o[0] == "candidate" for o in orders)), 1)

    def test_adjacent_null_and_real_lanes_use_both_process_orders(self):
        for lane in LANES:
            self.assertEqual({comparison_order(pair, lane) for pair in range(2)},
                             {("direct", "candidate"), ("candidate", "direct")})


if __name__ == "__main__":
    unittest.main()
