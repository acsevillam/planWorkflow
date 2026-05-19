#!/usr/bin/env python3
"""Tests for planWorkflow Python postprocessing helpers."""

from __future__ import annotations

import math
import sys
import unittest
from pathlib import Path


POSTPROCESSING_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(POSTPROCESSING_ROOT))

from planworkflow_postprocessing import robust_analysis as analysis  # noqa: E402


def row(ri1: float, rectum: float, bladder: float, label: str = "plan"):
    return {
        "ri1": ri1,
        "por_rectum_v40_pp": rectum,
        "por_bladder_v60_pp": bladder,
        "mean_rectum_v40_percent": rectum,
        "mean_bladder_v60_percent": bladder,
        "max_rectum_v40_percent": rectum,
        "max_bladder_v60_percent": bladder,
        "label": label,
        "approach": "Synthetic",
    }


class PureUtilityTests(unittest.TestCase):
    def test_dvh_volume_at_dose_interpolates_and_clamps(self):
        self.assertAlmostEqual(
            analysis.dvh_volume_at_dose([0.0, 2.0, 4.0], [100.0, 50.0, 0.0], 1.0),
            0.75,
        )
        self.assertEqual(
            analysis.dvh_volume_at_dose([0.0, 2.0, 4.0], [100.0, 50.0, 0.0], -1.0),
            1.0,
        )
        self.assertEqual(
            analysis.dvh_volume_at_dose([0.0, 2.0, 4.0], [100.0, 50.0, 0.0], 5.0),
            0.0,
        )

    def test_dominance_maximizes_ri1_and_minimizes_endpoints(self):
        candidate = row(0.5, 10.0, 10.0)
        challenger = row(0.6, 9.0, 10.0)

        self.assertTrue(analysis.is_dominated(candidate, challenger, "por"))
        self.assertFalse(analysis.is_dominated(challenger, candidate, "por"))

    def test_mark_pareto_dominance_sets_all_modes(self):
        rows = [
            row(0.5, 10.0, 10.0, "dominated"),
            row(0.6, 9.0, 10.0, "dominant"),
            row(0.4, 2.0, 20.0, "tradeoff"),
        ]

        marked = analysis.mark_pareto_dominance(rows)
        by_label = {item["label"]: item for item in marked}

        self.assertFalse(by_label["dominated"]["dominant_por"])
        self.assertTrue(by_label["dominant"]["dominant_por"])
        self.assertTrue(by_label["tradeoff"]["dominant_por"])
        self.assertIn("dominant_mean", by_label["dominant"])
        self.assertIn("dominant_max", by_label["dominant"])

    def test_filter_aliases_and_wildcards(self):
        rows = [
            {
                "patient": "3482",
                "robustness": "INTERVAL2",
                "scen_mode": "impScen5",
                "dose_pulling_2": "off",
                "approach": "INTERVAL2",
            },
            {
                "patient": "3482",
                "robustness": "c-COWC",
                "scen_mode": "wcScen",
                "dose_pulling_2": "on",
                "approach": "c-Minimax",
            },
        ]
        specs = analysis.parse_filter_specs(
            ["patient=3482", "scen_mode=impScen*", "dose_pulling2=false"],
            ["robutsness=c-COWC"],
        )

        filtered = analysis.apply_row_filters(rows, specs)

        self.assertEqual(len(filtered), 1)
        self.assertEqual(filtered[0]["robustness"], "INTERVAL2")

    def test_approach_labels_are_canonicalized(self):
        self.assertEqual(analysis.approach_from_label("Reference (Nominal)"), "Reference")
        self.assertEqual(analysis.approach_from_label("COWC"), "Minimax")
        self.assertEqual(analysis.approach_from_label("Interval2 (theta1=1)"), "INTERVAL2")
        self.assertEqual(
            analysis.approach_from_label("Interval3 (theta1=1, theta2=1)"),
            "INTERVAL3",
        )

    def test_approaches_use_global_legend_order(self):
        approaches = [
            "INTERVAL3",
            "PTV",
            "Reference",
            "MeanVariance",
            "Minimax",
            "INTERVAL2",
            "Stochastic",
            "c-Minimax",
        ]

        self.assertEqual(
            analysis.ordered_approaches(approaches),
            [
                "Reference",
                "PTV",
                "Minimax",
                "Stochastic",
                "c-Minimax",
                "MeanVariance",
                "INTERVAL2",
                "INTERVAL3",
            ],
        )

    def test_rows_use_global_legend_order(self):
        rows = [
            {"approach": "MeanVariance"},
            {"approach": "PTV"},
            {"approach": "Reference"},
            {"approach": "INTERVAL2"},
        ]

        self.assertEqual(
            analysis.row_approaches_in_legend_order(rows),
            ["Reference", "PTV", "MeanVariance", "INTERVAL2"],
        )

    def test_selected_modes(self):
        self.assertEqual(analysis.selected_stat_modes("all"), ["por", "mean", "max"])
        self.assertEqual(analysis.selected_filter_modes("both"), ["all", "dominant"])
        self.assertEqual(analysis.selected_figure_modes("all"), ["endpoint", "time", "dij"])
        self.assertEqual(
            analysis.selected_time_modes(["all"]),
            ["precompute_dij_time", "optimization_rtpi"],
        )
        self.assertEqual(analysis.selected_value_modes("both"), ["absolute", "relative"])
        self.assertEqual(analysis.selected_value_modes("absolute"), ["absolute"])

    def test_metric_output_stem_preserves_default_absolute_names(self):
        self.assertEqual(
            analysis.metric_output_stem("precompute_dij_time", "absolute"),
            "precompute_dij_time",
        )
        self.assertEqual(
            analysis.metric_output_stem("precompute_dij_time", "relative"),
            "precompute_dij_time_relative",
        )

    def test_time_and_size_value_configs_use_explicit_fields(self):
        self.assertEqual(
            analysis.PRECOMPUTE_TIME_VALUE_CONFIG["absolute"]["value_key"],
            "precompute_dij_time_seconds",
        )
        self.assertEqual(
            analysis.PRECOMPUTE_TIME_VALUE_CONFIG["relative"]["value_key"],
            "precompute_relative_dij_time",
        )
        self.assertEqual(
            analysis.PRECOMPUTE_SIZE_VALUE_CONFIG["absolute"]["value_key"],
            "precompute_dij_size_gib",
        )
        self.assertEqual(
            analysis.PRECOMPUTE_SIZE_VALUE_CONFIG["relative"]["value_key"],
            "precompute_relative_dij_size",
        )

    def test_precompute_number_of_scenarios_reads_nested_detail(self):
        detail = '{"dij_interval":{"numberOfScenarios":13,"totalSize":{"bytes":10}}}'

        self.assertEqual(analysis.precompute_number_of_scenarios_from_detail(detail), 13)
        self.assertTrue(math.isnan(analysis.precompute_number_of_scenarios_from_detail("{}")))

    def test_precompute_dij_fieldnames_use_user_facing_metrics(self):
        fields = analysis.precompute_dij_fieldnames()

        self.assertIn("precompute_dij_time_seconds", fields)
        self.assertIn("precompute_dij_size_bytes", fields)
        self.assertIn("precompute_relative_dij_time", fields)
        self.assertIn("precompute_relative_dij_size", fields)
        self.assertNotIn("nominal_dij_size_bytes", fields)

    def test_aggregate_by_approach(self):
        summary = analysis.aggregate_by_approach(
            [
                {"approach": "INTERVAL2", "rtpi": 2.0},
                {"approach": "INTERVAL2", "rtpi": 4.0},
                {"approach": "PTV", "rtpi": 1.0},
            ],
            "rtpi",
            "rtpi",
        )

        by_approach = {row["approach"]: row for row in summary}
        self.assertEqual(by_approach["INTERVAL2"]["count"], 2)
        self.assertAlmostEqual(by_approach["INTERVAL2"]["mean_rtpi"], 3.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
