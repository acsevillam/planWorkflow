#!/usr/bin/env python3
"""Postprocess planWorkflow robust-analysis result files.

The module reads MATLAB v7.3/HDF5 ``workflow_results.mat`` files and writes
CSV tables plus publication-oriented figures for:

* RI1 vs clinical endpoint PoR/mean/max scatter plots.
* Precompute Dij-time boxplots.
* Optimization rTPI boxplots.
* Precompute Dij-size boxplots.

Heavy dependencies are imported lazily so unit tests for pure helpers can run
without a scientific Python environment. Reading ``.mat`` files and plotting
requires ``h5py``, ``numpy``, and ``matplotlib``.
"""

from __future__ import annotations

import argparse
import csv
import fnmatch
import json
import math
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


os.environ.setdefault("MPLBACKEND", "Agg")
os.environ.setdefault("HDF5_USE_FILE_LOCKING", "FALSE")
os.environ.setdefault(
    "MPLCONFIGDIR",
    str(Path(os.environ.get("TMPDIR", "/tmp")) / "planworkflow_postprocessing_mplconfig"),
)
os.environ.setdefault(
    "XDG_CACHE_HOME",
    str(Path(os.environ.get("TMPDIR", "/tmp")) / "planworkflow_postprocessing_cache"),
)

BYTES_PER_GIB = 1024.0 ** 3
MARKER_EDGE_WIDTH = 0.8
DOMINANT_MARKER_EDGE_WIDTH = 1.5
DOMINANT_MARKER_EDGE_COLOR = "#000000"
SHOW_GRID = False
RI1_X_LIMITS = (0.0, 1.0)

APPROACH_COLORS = {
    "Reference": "#4d4d4d",
    "PTV": "#d62728",
    "Minimax": "#1f77b4",
    "Stochastic": "#f2c94c",
    "c-Minimax": "#2ca02c",
    "MeanVariance": "#9467bd",
    "INTERVAL2": "#17becf",
    "INTERVAL3": "#ff7f0e",
}
APPROACH_ORDER = [
    "Reference",
    "PTV",
    "Minimax",
    "Stochastic",
    "c-Minimax",
    "MeanVariance",
    "INTERVAL2",
    "INTERVAL3",
]
APPROACH_DISPLAY_LABELS = {
    "INTERVAL2": r"Interval ($\theta_{2}=0$)",
    "INTERVAL3": r"Interval ($\theta_{2}=1$)",
}
APPROACH_ALIASES = {
    "reference": "Reference",
    "reference (nominal)": "Reference",
    "cowc": "Minimax",
    "cheap-minimax": "c-Minimax",
    "cheapminimax": "c-Minimax",
    "cminimax": "c-Minimax",
    "c-minimax": "c-Minimax",
    "interval2": "INTERVAL2",
    "interval3": "INTERVAL3",
}
FIELD_ALIASES = {
    "caseid": "patient",
    "case_id": "patient",
    "patient_id": "patient",
    "robutsness": "robustness",
    "robustness_mode": "robustness",
    "optimization_scen_mode": "scen_mode",
    "scenario_mode": "scen_mode",
    "dose_pulling2": "dose_pulling_2",
    "dosepulling2": "dose_pulling_2",
}

RECTUM_V40_LABEL = r"$V_{40\mathrm{Gy}}$ Rectum [%]"
BLADDER_V60_LABEL = r"$V_{60\mathrm{Gy}}$ Bladder [%]"

METADATA_FIELDS = [
    "patient",
    "case_id",
    "site",
    "radiation_mode",
    "workflow",
    "series_id",
    "comparison_id",
    "beam_set",
    "run_folder",
    "sampling_scen_mode",
    "scen_mode",
    "optimization_scen_mode",
    "dose_pulling_1",
    "dose_pulling_2",
    "precompute_num_scenarios",
    "robustness",
    "robustness_mode",
    "robust_plan_id",
    "robust_plan_label",
    "requires_nominal_dij",
    "requires_scenario_dij",
    "requires_prob2_dij",
    "requires_interval_dij",
]

@dataclass(frozen=True)
class Endpoint:
    structure: str
    threshold_total_gy: float


@dataclass(frozen=True)
class FilterSpec:
    field: str
    values: tuple[str, ...]
    include: bool


ENDPOINTS = {
    "rectum_v40": Endpoint("RECTUM", 40.0),
    "bladder_v60": Endpoint("BLADDER", 60.0),
}
STAT_CONFIG = {
    "por": {
        "title": "RI1 vs clinical endpoint PoR",
        "rectum_key": "por_rectum_v40_pp",
        "bladder_key": "por_bladder_v60_pp",
        "rectum_ylabel": r"PoR $V_{40\mathrm{Gy}}$ Rectum [%]",
        "bladder_ylabel": r"PoR $V_{60\mathrm{Gy}}$ Bladder [%]",
    },
    "mean": {
        "title": "RI1 vs clinical endpoint mean",
        "rectum_key": "mean_rectum_v40_percent",
        "bladder_key": "mean_bladder_v60_percent",
        "rectum_ylabel": RECTUM_V40_LABEL,
        "bladder_ylabel": BLADDER_V60_LABEL,
    },
    "max": {
        "title": "RI1 vs clinical endpoint max",
        "rectum_key": "max_rectum_v40_percent",
        "bladder_key": "max_bladder_v60_percent",
        "rectum_ylabel": RECTUM_V40_LABEL,
        "bladder_ylabel": BLADDER_V60_LABEL,
    },
}
PRECOMPUTE_TIME_VALUE_CONFIG = {
    "absolute": {
        "value_key": "precompute_dij_time_seconds",
        "prefix": "precompute_dij_time_seconds",
        "title": "Precompute dij time",
        "ylabel": "Precompute dij time [s]",
        "reference_y": None,
    },
    "relative": {
        "value_key": "precompute_relative_dij_time",
        "prefix": "precompute_relative_dij_time",
        "title": "Relative precompute dij time",
        "ylabel": "Relative precompute dij time",
        "reference_y": 1.0,
    },
}
PRECOMPUTE_SIZE_VALUE_CONFIG = {
    "absolute": {
        "value_key": "precompute_dij_size_gib",
        "prefix": "precompute_dij_size_gib",
        "title": "Precompute dij size",
        "ylabel": "Precompute dij size [GiB]",
        "reference_y": None,
    },
    "relative": {
        "value_key": "precompute_relative_dij_size",
        "prefix": "precompute_relative_dij_size",
        "title": "Relative precompute dij size",
        "ylabel": "Relative precompute dij size",
        "reference_y": 1.0,
    },
}


def require_numpy():
    try:
        import numpy as np  # type: ignore
    except ModuleNotFoundError as exc:
        raise RuntimeError("planWorkflow postprocessing requires numpy.") from exc
    return np


def require_h5py():
    try:
        import h5py  # type: ignore
    except ModuleNotFoundError as exc:
        raise RuntimeError("Reading workflow_results.mat requires h5py.") from exc
    return h5py


def require_plotting():
    np = require_numpy()
    try:
        import matplotlib  # type: ignore

        matplotlib.use("Agg")
        import matplotlib.colors as mcolors  # type: ignore
        import matplotlib.pyplot as plt  # type: ignore
        from matplotlib.lines import Line2D  # type: ignore
    except ModuleNotFoundError as exc:
        raise RuntimeError("Plot generation requires matplotlib.") from exc
    return np, mcolors, plt, Line2D


def finite_float(value: Any, default: float = math.nan) -> float:
    try:
        result = float(value)
    except (TypeError, ValueError):
        return default
    return result if math.isfinite(result) else default


def as_list(value: Any) -> list[Any]:
    if value is None or value == "":
        return []
    return value if isinstance(value, list) else [value]


def nth(values: list[Any], index: int, default: Any = "") -> Any:
    return values[index] if index < len(values) else default


def on_off(value: Any) -> str:
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"1", "true", "on", "yes", "y"}:
            return "on"
        if normalized in {"0", "false", "off", "no", "n", ""}:
            return "off"
        return normalized
    if isinstance(value, bool):
        return "on" if value else "off"
    if isinstance(value, (int, float)):
        return "on" if float(value) != 0.0 else "off"
    return "off"


def approach_from_label(label: str) -> str:
    label = str(label).strip()
    rules = [
        (r"^Reference\b", "Reference"),
        (r"^MeanVariance\b", "MeanVariance"),
        (r"^Interval2\b", "INTERVAL2"),
        (r"^Interval3\b", "INTERVAL3"),
        (r"^c-Minimax\b", "c-Minimax"),
        (r"^Minimax\b", "Minimax"),
        (r"^COWC\b", "Minimax"),
        (r"^Stochastic\b", "Stochastic"),
        (r"^PTV$", "PTV"),
    ]
    for pattern, approach in rules:
        if re.search(pattern, label, flags=re.IGNORECASE):
            return approach
    return canonical_approach_name(label)


def variant_from_label(label: str) -> str:
    match = re.search(r"\((.*)\)", label)
    return match.group(1) if match else ""


def canonical_approach_name(value: str) -> str:
    stripped = str(value).strip()
    return APPROACH_ALIASES.get(stripped.lower(), stripped)


def canonical_field_name(field: str) -> str:
    normalized = field.strip().lower().replace("-", "_")
    return FIELD_ALIASES.get(normalized, normalized)


def normalize_filter_value(field: str, value: str) -> str:
    canonical = canonical_field_name(field)
    if canonical == "approach":
        return canonical_approach_name(value)
    if canonical in {"dose_pulling_1", "dose_pulling_2"}:
        return on_off(value)
    return value.strip()


def parse_filter_spec(raw: str, include: bool) -> FilterSpec:
    if "=" not in raw:
        raise ValueError(f"Filter must be FIELD=VALUE[,VALUE]: {raw}")
    field, raw_values = raw.split("=", 1)
    values = tuple(
        normalize_filter_value(field, value)
        for value in raw_values.split(",")
        if value.strip()
    )
    if not values:
        raise ValueError(f"Filter has no values: {raw}")
    return FilterSpec(canonical_field_name(field), values, include)


def parse_filter_specs(include_filters: list[str], exclude_filters: list[str]) -> list[FilterSpec]:
    specs = [parse_filter_spec(raw, True) for raw in include_filters]
    specs.extend(parse_filter_spec(raw, False) for raw in exclude_filters)
    return specs


def value_matches_filter(row_value: Any, field: str, expected_values: tuple[str, ...]) -> bool:
    normalized_row_value = normalize_filter_value(field, str(row_value))
    for expected in expected_values:
        expected = normalize_filter_value(field, expected)
        if any(char in expected for char in "*?[]"):
            if fnmatch.fnmatchcase(normalized_row_value, expected):
                return True
        elif normalized_row_value == expected:
            return True
    return False


def row_matches_filter(row: dict[str, Any], spec: FilterSpec) -> bool:
    matched = value_matches_filter(row.get(spec.field, ""), spec.field, spec.values)
    return matched if spec.include else not matched


def apply_row_filters(rows: list[dict[str, Any]], specs: list[FilterSpec]) -> list[dict[str, Any]]:
    if not specs:
        return rows
    return [row for row in rows if all(row_matches_filter(row, spec) for spec in specs)]


def ordered_approaches(approaches: list[str]) -> list[str]:
    seen = list(dict.fromkeys(approaches))
    ordered = [approach for approach in APPROACH_ORDER if approach in seen]
    ordered.extend(approach for approach in seen if approach not in ordered)
    return ordered


def row_approaches_in_legend_order(rows: list[dict[str, Any]]) -> list[str]:
    return ordered_approaches(list(dict.fromkeys(str(row["approach"]) for row in rows)))


def approach_display_label(approach: str) -> str:
    return APPROACH_DISPLAY_LABELS.get(approach, approach)


def approach_colors(approaches: list[str]) -> dict[str, Any]:
    np, mcolors, plt, _ = require_plotting()
    colors: dict[str, Any] = {
        approach: APPROACH_COLORS[approach]
        for approach in approaches
        if approach in APPROACH_COLORS
    }
    cmap = plt.get_cmap("tab10")
    for index, approach in enumerate(approach for approach in approaches if approach not in colors):
        colors[approach] = cmap(index % 10)
    return colors


def darkened_color(color: Any, factor: float = 0.55) -> Any:
    _, mcolors, _, _ = require_plotting()
    rgb = mcolors.to_rgb(color)
    return tuple(max(min(component * factor, 1.0), 0.0) for component in rgb)


def padded_limits(values: list[float], padding_fraction: float = 0.06) -> tuple[float, float]:
    finite_values = [float(value) for value in values if math.isfinite(float(value))]
    if not finite_values:
        return 0.0, 1.0
    lower = min(finite_values)
    upper = max(finite_values)
    if lower == upper:
        pad = max(abs(lower), 1.0) * padding_fraction
    else:
        pad = (upper - lower) * padding_fraction
    return lower - pad, upper + pad


def matlab_class(dataset: Any) -> str:
    value = dataset.attrs.get("MATLAB_class", b"")
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="ignore")
    if hasattr(value, "item"):
        value = value.item()
        if isinstance(value, bytes):
            return value.decode("utf-8", errors="ignore")
    return str(value)


def decode_matlab_char(dataset: Any) -> str:
    np = require_numpy()
    values = np.array(dataset).flatten(order="F")
    return "".join(chr(int(value)) for value in values if int(value) != 0)


def deref_cell(file: Any, dataset: Any) -> list[Any | None]:
    np = require_numpy()
    values = []
    for ref in np.array(dataset).flatten(order="F"):
        values.append(file[ref] if ref else None)
    return values


def read_cell_strings(file: Any, dataset: Any) -> list[str]:
    return [decode_matlab_char(obj) if obj is not None else "" for obj in deref_cell(file, dataset)]


def read_scalar(dataset: Any) -> float:
    np = require_numpy()
    values = np.array(dataset).flatten(order="F")
    return float(values[0]) if values.size else math.nan


def read_matlab_value(file: Any, obj: Any) -> Any:
    h5py = require_h5py()
    np = require_numpy()
    if obj is None:
        return ""
    if isinstance(obj, h5py.Group):
        return {key: read_matlab_value(file, obj[key]) for key in obj.keys()}

    values = np.array(obj)
    if values.dtype == h5py.ref_dtype or values.dtype.kind == "O":
        refs = values.flatten(order="F")
        decoded = [read_matlab_value(file, file[ref]) if ref else "" for ref in refs]
        return decoded[0] if values.shape == (1, 1) and decoded else decoded

    cls = matlab_class(obj)
    flat = values.flatten(order="F")
    if cls == "char":
        return decode_matlab_char(obj)
    if cls == "logical":
        decoded = [bool(value) for value in flat]
        return decoded[0] if len(decoded) == 1 else decoded
    if flat.size == 0:
        return ""
    if flat.size == 1:
        value = flat[0]
        return value.item() if hasattr(value, "item") else value
    return [value.item() if hasattr(value, "item") else value for value in flat]


def read_optional_value(file: Any, path: str, default: Any = "") -> Any:
    return read_matlab_value(file, file[path]) if path in file else default


def read_optional_char(file: Any, path: str, default: str = "") -> str:
    if path not in file:
        return default
    return decode_matlab_char(file[path])


def path_metadata(mat_path: Path) -> dict[str, str]:
    parts = mat_path.resolve().parts
    metadata = {
        "patient": "",
        "case_id": "",
        "site": "",
        "radiation_mode": "",
        "workflow": "",
        "series_id": "",
        "comparison_id": "",
        "beam_set": "",
        "run_folder": mat_path.parent.name,
    }
    if "output" not in parts:
        return metadata
    index = parts.index("output")
    if len(parts) > index + 4:
        metadata.update(
            {
                "radiation_mode": parts[index + 1],
                "site": parts[index + 2],
                "patient": parts[index + 3],
                "case_id": parts[index + 3],
                "workflow": parts[index + 4],
            }
        )
    if len(parts) > index + 5:
        metadata["series_id"] = parts[index + 5]
    if len(parts) > index + 6:
        metadata["comparison_id"] = parts[index + 6]
    if len(parts) > index + 7:
        metadata["beam_set"] = parts[index + 7]
    return metadata


def source_metadata(file: Any, mat_path: Path) -> dict[str, str]:
    metadata = path_metadata(mat_path)
    patient = str(read_optional_value(file, "/results/runConfig/caseID", metadata["patient"]))
    site = str(read_optional_value(file, "/results/runConfig/description", metadata["site"]))
    metadata.update(
        {
            "patient": patient,
            "case_id": patient,
            "site": site,
            "sampling_scen_mode": str(read_optional_value(file, "/results/runConfig/sampling_scen_mode", "")),
            "dose_pulling_1": on_off(read_optional_value(file, "/results/runConfig/dose_pulling1", "off")),
            "dose_pulling_2": on_off(read_optional_value(file, "/results/runConfig/dose_pulling2", "off")),
        }
    )
    return metadata


def scenario_counts_in_value(value: Any) -> list[float]:
    if isinstance(value, dict):
        counts = []
        for key, child in value.items():
            if key == "numberOfScenarios":
                count = finite_float(child)
                if math.isfinite(count):
                    counts.append(count)
            else:
                counts.extend(scenario_counts_in_value(child))
        return counts
    if isinstance(value, list):
        counts: list[float] = []
        for child in value:
            counts.extend(scenario_counts_in_value(child))
        return counts
    return []


def precompute_number_of_scenarios_from_detail(detail: str) -> float:
    if not detail:
        return math.nan
    try:
        data = json.loads(detail)
    except (json.JSONDecodeError, TypeError):
        return math.nan
    counts = scenario_counts_in_value(data)
    return max(counts) if counts else math.nan


def precompute_count_key(value: Any) -> str:
    return canonical_approach_name(str(value)).strip().lower()


def set_precompute_scenario_count(counts: dict[str, float], key: Any, count: float) -> None:
    normalized = precompute_count_key(key)
    if normalized and math.isfinite(count):
        counts[normalized] = max(counts.get(normalized, count), count)


def lookup_precompute_scenario_count(counts: dict[str, float], *keys: Any) -> str:
    for key in keys:
        for lookup_key in (precompute_count_key(key), precompute_count_key(approach_from_label(str(key)))):
            if lookup_key in counts:
                value = counts[lookup_key]
                return str(int(value)) if float(value).is_integer() else f"{value:g}"
    return ""


def precompute_scenario_counts(file: Any) -> dict[str, float]:
    if "/results/performance/planTimings" not in file:
        return {}
    timings = read_matlab_value(file, file["/results/performance/planTimings"])
    if not isinstance(timings, dict):
        return {}
    counts: dict[str, float] = {}
    labels = as_list(timings.get("label", []))
    plan_ids = as_list(timings.get("robustPlanId", []))
    stages = as_list(timings.get("stage", []))
    details = as_list(timings.get("detail", []))
    for index, label in enumerate(labels):
        if str(nth(stages, index, "")) != "precompute":
            continue
        count = precompute_number_of_scenarios_from_detail(str(nth(details, index, "")))
        if not math.isfinite(count):
            continue
        label = str(label)
        plan_id = str(nth(plan_ids, index, ""))
        set_precompute_scenario_count(counts, label, count)
        set_precompute_scenario_count(counts, plan_id, count)
        set_precompute_scenario_count(counts, approach_from_label(label), count)
    return counts


def robust_plan_metadata(file: Any) -> list[dict[str, str]]:
    base = "/results/runConfig/precompute/robustPlans"
    if base not in file:
        return []
    precompute_counts = precompute_scenario_counts(file)
    labels = as_list(read_optional_value(file, f"{base}/label", []))
    ids = as_list(read_optional_value(file, f"{base}/id", []))
    modes = as_list(read_optional_value(file, f"{base}/robustnessMode", []))
    scenarios = as_list(read_optional_value(file, f"{base}/scenario", []))
    requires_nominal = as_list(read_optional_value(file, f"{base}/requiresNominalDij", []))
    requires_scenario = as_list(read_optional_value(file, f"{base}/requiresScenarioDij", []))
    requires_prob2 = as_list(read_optional_value(file, f"{base}/requiresProb2Dij", []))
    requires_interval = as_list(read_optional_value(file, f"{base}/requiresIntervalDij", []))
    rows = []
    for index, label in enumerate(labels):
        scenario = nth(scenarios, index, {})
        if not isinstance(scenario, dict):
            scenario = {}
        plan_id = str(nth(ids, index, ""))
        robustness = str(nth(modes, index, ""))
        requires_nominal_dij = on_off(nth(requires_nominal, index, False))
        requires_scenario_dij = on_off(nth(requires_scenario, index, False))
        requires_prob2_dij = on_off(nth(requires_prob2, index, False))
        requires_interval_dij = on_off(nth(requires_interval, index, False))
        precompute_num_scenarios = lookup_precompute_scenario_count(precompute_counts, label, plan_id)
        if (
            not precompute_num_scenarios
            and requires_nominal_dij == "on"
            and all(value != "on" for value in (requires_scenario_dij, requires_prob2_dij, requires_interval_dij))
        ):
            precompute_num_scenarios = "1"
        scen_mode = str(scenario.get("mode", scenario.get("scenarioMode", "")))
        rows.append(
            {
                "robust_plan_id": plan_id,
                "robust_plan_label": str(label),
                "robustness": robustness,
                "robustness_mode": robustness,
                "scen_mode": scen_mode,
                "optimization_scen_mode": scen_mode,
                "precompute_num_scenarios": precompute_num_scenarios,
                "requires_nominal_dij": requires_nominal_dij,
                "requires_scenario_dij": requires_scenario_dij,
                "requires_prob2_dij": requires_prob2_dij,
                "requires_interval_dij": requires_interval_dij,
            }
        )
    return rows


def match_robust_plan_metadata(label: str, approach: str, metadata: list[dict[str, str]]) -> dict[str, str]:
    if canonical_approach_name(approach) == "Reference":
        return reference_plan_metadata(label)
    normalized_approach = canonical_approach_name(approach).lower()
    candidates = sorted(metadata, key=lambda item: len(item.get("robust_plan_label", "")), reverse=True)
    for item in candidates:
        plan_label = item.get("robust_plan_label", "")
        normalized_plan_label = canonical_approach_name(plan_label).lower()
        if label == plan_label or label.startswith(f"{plan_label} ") or normalized_approach == normalized_plan_label:
            return item
    return {
        "robust_plan_id": "",
        "robust_plan_label": "",
        "robustness": "",
        "robustness_mode": "",
        "scen_mode": "",
        "optimization_scen_mode": "",
        "precompute_num_scenarios": "",
        "requires_nominal_dij": "",
        "requires_scenario_dij": "",
        "requires_prob2_dij": "",
        "requires_interval_dij": "",
    }


def reference_plan_metadata(label: str = "Reference (Nominal)") -> dict[str, str]:
    return {
        "robust_plan_id": "Reference",
        "robust_plan_label": label,
        "robustness": "reference",
        "robustness_mode": "reference",
        "scen_mode": "nomScen",
        "optimization_scen_mode": "nomScen",
        "precompute_num_scenarios": "1",
        "requires_nominal_dij": "on",
        "requires_scenario_dij": "off",
        "requires_prob2_dij": "off",
        "requires_interval_dij": "off",
    }


def dvh_volume_at_dose(dose_grid: Any, volume_points: Any, dose: float) -> float:
    if not math.isfinite(dose):
        return math.nan
    pairs = []
    for x, y in zip(list(dose_grid), list(volume_points), strict=False):
        x_value = finite_float(x)
        y_value = finite_float(y)
        if math.isfinite(x_value) and math.isfinite(y_value):
            pairs.append((x_value, y_value))
    if len(pairs) < 2:
        return math.nan
    unique: dict[float, float] = {}
    for x_value, y_value in sorted(pairs):
        unique.setdefault(x_value, y_value)
    xs = list(unique)
    ys = [unique[x] for x in xs]
    if dose < xs[0]:
        return 1.0
    if dose > xs[-1]:
        return 0.0
    for index in range(1, len(xs)):
        if dose <= xs[index]:
            x0, x1 = xs[index - 1], xs[index]
            y0, y1 = ys[index - 1], ys[index]
            if x1 == x0:
                return max(min(y1 / 100.0, 1.0), 0.0)
            fraction = (dose - x0) / (x1 - x0)
            volume = y0 + fraction * (y1 - y0)
            return max(min(volume / 100.0, 1.0), 0.0)
    return 0.0


def endpoint_stats_percent(file: Any, plan_group: Any, endpoint: Endpoint) -> dict[str, float]:
    np = require_numpy()
    names = [name.upper() for name in read_cell_strings(file, plan_group["cstStat/name"])]
    try:
        structure_index = names.index(endpoint.structure.upper())
    except ValueError:
        return {"mean": math.nan, "max": math.nan}
    num_fractions = read_scalar(plan_group["numOfFractions"])
    threshold = endpoint.threshold_total_gy / num_fractions
    dvh_refs = np.array(plan_group["cstStat/dvhStat"]).flatten(order="F")
    dvh = file[dvh_refs[structure_index]]
    dose_grid = np.array(dvh["mean/doseGrid"], dtype=float).reshape(-1)
    volume_points = np.array(dvh["mean/volumePoints"], dtype=float).reshape(-1)
    mean_value = 100.0 * dvh_volume_at_dose(dose_grid, volume_points, threshold)
    max_value = math.nan
    if "std" in dvh:
        std_dose_grid = np.array(dvh["std/doseGrid"], dtype=float).reshape(-1)
        std_values = np.array(dvh["std/volumePoints"], dtype=float).reshape(-1)
        std_interp = np.interp(dose_grid, std_dose_grid, std_values)
        upper = np.minimum(volume_points + std_interp, 100.0)
        max_value = 100.0 * dvh_volume_at_dose(dose_grid, upper, threshold)
    return {"mean": mean_value, "max": max_value}


def endpoint_mean_percent(file: Any, plan_group: Any, endpoint: Endpoint) -> float:
    return endpoint_stats_percent(file, plan_group, endpoint)["mean"]


def collect_endpoint_rows_from_mat(mat_path: Path, source_id: str, source_index: int) -> list[dict[str, Any]]:
    h5py = require_h5py()
    rows = []
    with h5py.File(mat_path, "r") as file:
        run_id = read_optional_char(file, "/resultsMetadata/runId", mat_path.stem)
        mat_metadata = source_metadata(file, mat_path)
        plan_metadata = robust_plan_metadata(file)
        reference = file["/results/sampling/reference"]
        ref_label = decode_matlab_char(reference["label"]) if "label" in reference else "Reference (Nominal)"
        ref_rectum = endpoint_stats_percent(file, reference, ENDPOINTS["rectum_v40"])
        ref_bladder = endpoint_stats_percent(file, reference, ENDPOINTS["bladder_v60"])
        ref_rectum_v40 = ref_rectum["mean"]
        ref_bladder_v60 = ref_bladder["mean"]
        rows.append(
            {
                **mat_metadata,
                **reference_plan_metadata(ref_label),
                "source_id": source_id,
                "source_index": source_index,
                "source_file": str(mat_path),
                "run_id": run_id,
                "label": ref_label,
                "approach": "Reference",
                "variant": "",
                "ri1": read_scalar(reference["doseStat/robustnessAnalysis/index1/robustnessIndex"]),
                "mean_rectum_v40_percent": ref_rectum["mean"],
                "mean_bladder_v60_percent": ref_bladder["mean"],
                "max_rectum_v40_percent": ref_rectum["max"],
                "max_bladder_v60_percent": ref_bladder["max"],
                "reference_rectum_v40_percent": ref_rectum_v40,
                "reference_bladder_v60_percent": ref_bladder_v60,
                "por_rectum_v40_pp": 0.0,
                "por_bladder_v60_pp": 0.0,
            }
        )
        for obj in deref_cell(file, file["/results/sampling/robust"]):
            if obj is None:
                continue
            label = decode_matlab_char(obj["label"])
            approach = approach_from_label(label)
            matched = match_robust_plan_metadata(label, approach, plan_metadata)
            rectum = endpoint_stats_percent(file, obj, ENDPOINTS["rectum_v40"])
            bladder = endpoint_stats_percent(file, obj, ENDPOINTS["bladder_v60"])
            rows.append(
                {
                    **mat_metadata,
                    **matched,
                    "source_id": source_id,
                    "source_index": source_index,
                    "source_file": str(mat_path),
                    "run_id": run_id,
                    "label": label,
                    "approach": approach,
                    "variant": variant_from_label(label),
                    "ri1": read_scalar(obj["doseStat/robustnessAnalysis/index1/robustnessIndex"]),
                    "mean_rectum_v40_percent": rectum["mean"],
                    "mean_bladder_v60_percent": bladder["mean"],
                    "max_rectum_v40_percent": rectum["max"],
                    "max_bladder_v60_percent": bladder["max"],
                    "reference_rectum_v40_percent": ref_rectum_v40,
                    "reference_bladder_v60_percent": ref_bladder_v60,
                    "por_rectum_v40_pp": rectum["mean"] - ref_rectum_v40,
                    "por_bladder_v60_pp": bladder["mean"] - ref_bladder_v60,
                }
            )
    return rows


def collect_endpoint_rows(mat_paths: list[Path]) -> list[dict[str, Any]]:
    rows = []
    for source_index, mat_path in enumerate(mat_paths, start=1):
        rows.extend(collect_endpoint_rows_from_mat(mat_path, f"result_{source_index}", source_index))
    return rows


def collect_optimization_time_rows_from_mat(mat_path: Path, source_id: str, source_index: int) -> list[dict[str, Any]]:
    h5py = require_h5py()
    rows = []
    with h5py.File(mat_path, "r") as file:
        if "/results/performance/planTimings" not in file:
            return rows
        run_id = read_optional_char(file, "/resultsMetadata/runId", mat_path.stem)
        mat_metadata = source_metadata(file, mat_path)
        plan_metadata = robust_plan_metadata(file)
        timings = read_matlab_value(file, file["/results/performance/planTimings"])
        if not isinstance(timings, dict):
            return rows
        labels = as_list(timings.get("label", []))
        stages = as_list(timings.get("stage", []))
        roles = as_list(timings.get("role", []))
        tasks = as_list(timings.get("task", []))
        statuses = as_list(timings.get("status", []))
        variant_ids = as_list(timings.get("variantId", []))
        wall_times = as_list(timings.get("wallTimeSeconds", []))
        cpu_times = as_list(timings.get("cpuTimeSeconds", []))
        iteration_values = as_list(timings.get("iterations", []))
        time_per_iteration_values = as_list(timings.get("timePerIterationSeconds", []))
        rtpi_values = as_list(timings.get("rTPI", []))
        rtpi_reference_labels = as_list(timings.get("rTPIReferenceLabel", []))
        rtpi_reference_time_values = as_list(timings.get("rTPIReferenceTimePerIterationSeconds", []))
        for index, raw_label in enumerate(labels):
            stage = str(nth(stages, index, ""))
            role = str(nth(roles, index, ""))
            task = str(nth(tasks, index, ""))
            if stage != "optimize" or role not in {"reference", "robust"} or task != "fluenceOptimization":
                continue
            label = str(raw_label)
            approach = approach_from_label(label)
            matched = match_robust_plan_metadata(label, approach, plan_metadata)
            wall = finite_float(nth(wall_times, index, math.nan))
            cpu = finite_float(nth(cpu_times, index, math.nan))
            iterations = finite_float(nth(iteration_values, index, math.nan))
            time_per_iteration = finite_float(nth(time_per_iteration_values, index, math.nan))
            rtpi = finite_float(nth(rtpi_values, index, math.nan))
            if not math.isfinite(rtpi):
                continue
            rtpi_reference_time = finite_float(nth(rtpi_reference_time_values, index, math.nan))
            rtpi_reference_label = str(nth(rtpi_reference_labels, index, ""))
            rows.append(
                {
                    **mat_metadata,
                    **matched,
                    "source_id": source_id,
                    "source_index": source_index,
                    "source_file": str(mat_path),
                    "run_id": run_id,
                    "label": label,
                    "approach": approach,
                    "variant": variant_from_label(label),
                    "variant_id": str(nth(variant_ids, index, "")),
                    "stage": stage,
                    "role": role,
                    "task": task,
                    "status": str(nth(statuses, index, "")),
                    "wall_time_seconds": wall,
                    "cpu_time_seconds": cpu,
                    "iterations": iterations,
                    "time_per_iteration_s": time_per_iteration,
                    "cpu_time_per_iteration_s": (
                        cpu / iterations if math.isfinite(cpu) and math.isfinite(iterations) and iterations > 0 else math.nan
                    ),
                    "rtpi": rtpi,
                    "rtpi_reference_label": rtpi_reference_label,
                    "rtpi_reference_time_per_iteration_s": rtpi_reference_time,
                }
            )
    return rows


def collect_optimization_time_rows(mat_paths: list[Path]) -> list[dict[str, Any]]:
    rows = []
    for source_index, mat_path in enumerate(mat_paths, start=1):
        rows.extend(collect_optimization_time_rows_from_mat(mat_path, f"result_{source_index}", source_index))
    return rows


def collect_precompute_dij_rows_from_mat(mat_path: Path, source_id: str, source_index: int) -> list[dict[str, Any]]:
    h5py = require_h5py()
    rows = []
    with h5py.File(mat_path, "r") as file:
        if "/results/performance/planTimings" not in file:
            return rows
        run_id = read_optional_char(file, "/resultsMetadata/runId", mat_path.stem)
        mat_metadata = source_metadata(file, mat_path)
        plan_metadata = robust_plan_metadata(file)
        timings = read_matlab_value(file, file["/results/performance/planTimings"])
        if not isinstance(timings, dict):
            return rows
        labels = as_list(timings.get("label", []))
        stages = as_list(timings.get("stage", []))
        roles = as_list(timings.get("role", []))
        tasks = as_list(timings.get("task", []))
        statuses = as_list(timings.get("status", []))
        plan_ids = as_list(timings.get("robustPlanId", []))
        time_values = as_list(timings.get("dijPrecomputingTimeSeconds", []))
        relative_time_values = as_list(timings.get("relativeDijPrecomputingTime", []))
        reference_time_values = as_list(timings.get("dijPrecomputingReferenceTimeSeconds", []))
        reference_labels = as_list(timings.get("dijPrecomputingReferenceLabel", []))
        size_values = as_list(timings.get("dijPrecomputingSizeBytes", []))
        relative_size_values = as_list(timings.get("relativeDijPrecomputingSize", []))
        size_reference_values = as_list(timings.get("dijPrecomputingSizeReferenceBytes", []))
        size_reference_labels = as_list(timings.get("dijPrecomputingSizeReferenceLabel", []))
        for index, raw_label in enumerate(labels):
            stage = str(nth(stages, index, ""))
            role = str(nth(roles, index, ""))
            if stage != "precompute" or role not in {"reference", "robust"}:
                continue
            dij_time = finite_float(nth(time_values, index, math.nan))
            dij_size_bytes = finite_float(nth(size_values, index, math.nan))
            if not math.isfinite(dij_time) and not math.isfinite(dij_size_bytes):
                continue
            reference_time = finite_float(nth(reference_time_values, index, math.nan))
            relative_time = finite_float(nth(relative_time_values, index, math.nan))
            reference_label = str(nth(reference_labels, index, ""))
            size_reference_bytes = finite_float(nth(size_reference_values, index, math.nan))
            relative_size = finite_float(nth(relative_size_values, index, math.nan))
            label = str(raw_label)
            approach = approach_from_label(label)
            matched = match_robust_plan_metadata(label, approach, plan_metadata)
            rows.append(
                {
                    **mat_metadata,
                    **matched,
                    "source_id": source_id,
                    "source_index": source_index,
                    "source_file": str(mat_path),
                    "run_id": run_id,
                    "label": label,
                    "approach": approach,
                    "variant": variant_from_label(label),
                    "variant_id": str(nth(plan_ids, index, "")),
                    "stage": stage,
                    "role": role,
                    "task": str(nth(tasks, index, "")),
                    "status": str(nth(statuses, index, "")),
                    "precompute_dij_time_seconds": dij_time,
                    "precompute_relative_dij_time": relative_time,
                    "precompute_dij_reference_label": reference_label,
                    "precompute_dij_reference_time_seconds": reference_time,
                    "precompute_dij_size_bytes": dij_size_bytes,
                    "precompute_dij_size_gib": (
                        dij_size_bytes / BYTES_PER_GIB if math.isfinite(dij_size_bytes) else math.nan
                    ),
                    "precompute_relative_dij_size": relative_size,
                    "precompute_dij_size_reference_label": str(nth(size_reference_labels, index, "")),
                    "precompute_dij_size_reference_bytes": size_reference_bytes,
                    "precompute_dij_size_reference_gib": (
                        size_reference_bytes / BYTES_PER_GIB if math.isfinite(size_reference_bytes) else math.nan
                    ),
                }
            )
    return rows


def collect_precompute_dij_rows(mat_paths: list[Path]) -> list[dict[str, Any]]:
    rows = []
    for source_index, mat_path in enumerate(mat_paths, start=1):
        rows.extend(collect_precompute_dij_rows_from_mat(mat_path, f"result_{source_index}", source_index))
    return rows


def aggregate_by_approach(rows: list[dict[str, Any]], value_key: str, prefix: str) -> list[dict[str, Any]]:
    aggregates = []
    for approach in row_approaches_in_legend_order(rows):
        values = [finite_float(row.get(value_key)) for row in rows if row.get("approach") == approach]
        values = [value for value in values if math.isfinite(value)]
        if not values:
            continue
        aggregates.append(
            {
                "approach": approach,
                "display_label": approach_display_label(approach),
                "count": len(values),
                f"mean_{prefix}": sum(values) / len(values),
                f"std_{prefix}": (sum((value - sum(values) / len(values)) ** 2 for value in values) / len(values)) ** 0.5,
            }
        )
    return aggregates


def is_dominated(candidate: dict[str, Any], challenger: dict[str, Any], stat_mode: str) -> bool:
    config = STAT_CONFIG[stat_mode]
    candidate_values = (
        finite_float(candidate["ri1"]),
        finite_float(candidate[config["rectum_key"]]),
        finite_float(candidate[config["bladder_key"]]),
    )
    challenger_values = (
        finite_float(challenger["ri1"]),
        finite_float(challenger[config["rectum_key"]]),
        finite_float(challenger[config["bladder_key"]]),
    )
    no_worse = (
        challenger_values[0] >= candidate_values[0]
        and challenger_values[1] <= candidate_values[1]
        and challenger_values[2] <= candidate_values[2]
    )
    strictly_better = (
        challenger_values[0] > candidate_values[0]
        or challenger_values[1] < candidate_values[1]
        or challenger_values[2] < candidate_values[2]
    )
    return no_worse and strictly_better


def mark_pareto_dominance(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    marked = []
    for row in rows:
        item = dict(row)
        for stat_mode in STAT_CONFIG:
            item[f"dominant_{stat_mode}"] = not any(
                is_dominated(row, other, stat_mode) for other in rows if other is not row
            )
        marked.append(item)
    return marked


def write_csv(rows: list[dict[str, Any]], csv_path: Path, fieldnames: list[str]) -> None:
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fieldnames})


def endpoint_fieldnames() -> list[str]:
    return [
        "source_id",
        "source_index",
        "source_file",
        "run_id",
        "label",
        "approach",
        "variant",
        *METADATA_FIELDS,
        "dominant_por",
        "dominant_mean",
        "dominant_max",
        "ri1",
        "por_rectum_v40_pp",
        "por_bladder_v60_pp",
        "mean_rectum_v40_percent",
        "mean_bladder_v60_percent",
        "max_rectum_v40_percent",
        "max_bladder_v60_percent",
        "reference_rectum_v40_percent",
        "reference_bladder_v60_percent",
    ]


def timing_fieldnames(extra: list[str]) -> list[str]:
    return [
        "source_id",
        "source_index",
        "source_file",
        "run_id",
        "label",
        "approach",
        "variant",
        "variant_id",
        *METADATA_FIELDS,
        "stage",
        "role",
        "task",
        "status",
        *extra,
    ]


def precompute_dij_fieldnames() -> list[str]:
    return timing_fieldnames(
        [
            "precompute_dij_time_seconds",
            "precompute_relative_dij_time",
            "precompute_dij_reference_label",
            "precompute_dij_reference_time_seconds",
            "precompute_dij_size_bytes",
            "precompute_dij_size_gib",
            "precompute_relative_dij_size",
            "precompute_dij_size_reference_label",
            "precompute_dij_size_reference_bytes",
            "precompute_dij_size_reference_gib",
        ]
    )


def plot_endpoint_rows(rows: list[dict[str, Any]], output_path: Path, stat_mode: str, filter_mode: str) -> None:
    np, _, plt, Line2D = require_plotting()
    config = STAT_CONFIG[stat_mode]
    approaches = row_approaches_in_legend_order(rows)
    colors = approach_colors(approaches)
    fig, axes = plt.subplots(1, 2, figsize=(11.4, 6.2), sharex=True)
    panels = [
        (axes[0], config["rectum_key"], config["rectum_ylabel"], RECTUM_V40_LABEL),
        (axes[1], config["bladder_key"], config["bladder_ylabel"], BLADDER_V60_LABEL),
    ]
    for axis, y_key, y_label, title in panels:
        for approach in approaches:
            group = [row for row in rows if row["approach"] == approach]
            if not group:
                continue
            edge_colors = [
                DOMINANT_MARKER_EDGE_COLOR if row.get(f"dominant_{stat_mode}") else darkened_color(colors[approach])
                for row in group
            ]
            edge_widths = [
                DOMINANT_MARKER_EDGE_WIDTH if row.get(f"dominant_{stat_mode}") else MARKER_EDGE_WIDTH
                for row in group
            ]
            axis.scatter(
                [finite_float(row["ri1"]) for row in group],
                [finite_float(row[y_key]) for row in group],
                s=58,
                color=colors[approach],
                edgecolors=edge_colors,
                linewidths=edge_widths,
                alpha=0.92,
            )
        axis.grid(SHOW_GRID)
        if stat_mode == "por":
            axis.axhline(0, color="#777777", linewidth=0.9, linestyle="--", alpha=0.8)
        axis.set_title(title)
        axis.set_xlabel("RI1 (Robustness Index 1)")
        axis.set_ylabel(y_label)
        axis.set_xlim(RI1_X_LIMITS)
        axis.set_ylim(padded_limits([finite_float(row[y_key]) for row in rows]))
        axis.set_box_aspect(1)
    axes[1].yaxis.tick_left()
    axes[1].yaxis.set_label_position("left")
    handles = [
        Line2D([0], [0], marker="o", linestyle="None", label=approach_display_label(approach),
               markerfacecolor=colors[approach], markeredgecolor=darkened_color(colors[approach]),
               markeredgewidth=MARKER_EDGE_WIDTH, markersize=8)
        for approach in approaches
    ]
    handles.append(
        Line2D([0], [0], marker="o", linestyle="None", label="Dominant",
               markerfacecolor="white", markeredgecolor=DOMINANT_MARKER_EDGE_COLOR,
               markeredgewidth=DOMINANT_MARKER_EDGE_WIDTH, markersize=8)
    )
    fig.legend(handles, [handle.get_label() for handle in handles], loc="lower center",
               bbox_to_anchor=(0.5, 0.03), ncol=max(len(handles), 1), frameon=False,
               title="Robustness approach")
    fig.suptitle(f"{config['title']} - {'all plans' if filter_mode == 'all' else 'dominant plans'}")
    fig.subplots_adjust(left=0.08, right=0.98, bottom=0.2, top=0.86, wspace=0.18)
    fig.savefig(output_path, dpi=220, bbox_inches="tight")
    plt.close(fig)


def plot_approach_boxplots(
    rows: list[dict[str, Any]],
    value_key: str,
    output_path: Path,
    title: str,
    ylabel: str,
    reference_y: float | None = None,
) -> None:
    np, _, plt, _ = require_plotting()
    approaches = row_approaches_in_legend_order(rows)
    colors = approach_colors(approaches)
    groups = []
    plotted = []
    for approach in approaches:
        values = [finite_float(row.get(value_key)) for row in rows if row.get("approach") == approach]
        values = [value for value in values if math.isfinite(value)]
        if values:
            groups.append(values)
            plotted.append(approach)
    if not groups:
        raise RuntimeError(f"No finite values for boxplot key {value_key}.")
    positions = np.arange(len(groups))
    fig, axis = plt.subplots(1, 1, figsize=(8.2, 6.2))
    boxplot = axis.boxplot(groups, positions=positions, widths=0.56, patch_artist=True,
                           showfliers=False, medianprops={"color": "#111111", "linewidth": 1.3})
    for index, (patch, approach) in enumerate(zip(boxplot["boxes"], plotted, strict=True)):
        edge_color = darkened_color(colors[approach])
        patch.set_facecolor(colors[approach])
        patch.set_edgecolor(edge_color)
        patch.set_alpha(0.72)
        patch.set_linewidth(1.1)
        for whisker in boxplot["whiskers"][2 * index: 2 * index + 2]:
            whisker.set_color(edge_color)
        for cap in boxplot["caps"][2 * index: 2 * index + 2]:
            cap.set_color(edge_color)
    for x_value, values in zip(positions, groups, strict=True):
        axis.annotate(f"n={len(values)}", (x_value, max(values)), xytext=(0, 4),
                      textcoords="offset points", ha="center", va="bottom", fontsize=8,
                      color="#333333")
    all_values = [value for values in groups for value in values]
    axis.grid(SHOW_GRID)
    if reference_y is not None and math.isfinite(reference_y):
        axis.axhline(reference_y, color="#777777", linewidth=0.9, linestyle="--", alpha=0.8)
    axis.set_title(title)
    axis.set_ylabel(ylabel)
    axis.set_xticks(positions)
    axis.set_xticklabels([approach_display_label(approach) for approach in plotted], rotation=20, ha="right")
    axis.set_ylim(0, max(all_values) * 1.18 if all_values else 1.0)
    axis.set_box_aspect(1)
    fig.subplots_adjust(left=0.14, right=0.98, bottom=0.23, top=0.9)
    fig.savefig(output_path, dpi=220, bbox_inches="tight")
    plt.close(fig)


def selected_stat_modes(mode: str) -> list[str]:
    return list(STAT_CONFIG) if mode == "all" else [mode]


def selected_filter_modes(mode: str) -> list[str]:
    return ["all", "dominant"] if mode == "both" else [mode]


def selected_figure_modes(mode: str) -> list[str]:
    if mode == "all":
        return ["endpoint", "time", "dij"]
    if mode == "both":
        return ["endpoint", "time"]
    return [mode]


def selected_time_modes(modes: list[str]) -> list[str]:
    if "all" in modes or "both" in modes:
        return ["precompute_dij_time", "optimization_rtpi"]
    return list(dict.fromkeys(modes))


def selected_value_modes(mode: str) -> list[str]:
    return ["absolute", "relative"] if mode == "both" else [mode]


def metric_output_stem(base: str, value_mode: str) -> str:
    return base if value_mode == "absolute" else f"{base}_{value_mode}"


def write_boxplot_metric_outputs(
    rows: list[dict[str, Any]],
    output_dir: Path,
    base_stem: str,
    value_mode: str,
    config: dict[str, Any],
) -> None:
    stem = metric_output_stem(base_stem, value_mode)
    value_key = str(config["value_key"])
    prefix = str(config["prefix"])
    summary = aggregate_by_approach(rows, value_key, prefix)
    summary_path = output_dir / f"{stem}_summary.csv"
    write_csv(summary, summary_path, ["approach", "display_label", "count", f"mean_{prefix}", f"std_{prefix}"])
    print(f"Wrote {summary_path}")
    png = output_dir / f"{stem}_boxplot.png"
    reference_y = config.get("reference_y")
    plot_approach_boxplots(
        rows,
        value_key,
        png,
        str(config["title"]),
        str(config["ylabel"]),
        reference_y=finite_float(reference_y) if reference_y is not None else None,
    )
    print(f"Wrote {png}")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mat", type=Path, nargs="+", required=True, help="workflow_results.mat path(s).")
    parser.add_argument("--out-dir", type=Path, required=True, help="Output directory.")
    parser.add_argument("--stat", choices=["por", "mean", "max", "all"], default="all")
    parser.add_argument("--filter", dest="filter_mode", choices=["all", "dominant", "both"], default="both")
    parser.add_argument("--figure", choices=["endpoint", "time", "dij", "both", "all"], default="all")
    parser.add_argument(
        "--time-mode",
        nargs="+",
        choices=["precompute_dij_time", "optimization_rtpi", "both", "all"],
        default=["all"],
    )
    parser.add_argument(
        "--time-value",
        choices=["absolute", "relative", "both"],
        default="absolute",
        help="Value used for precompute Dij time boxplots.",
    )
    parser.add_argument(
        "--size-value",
        choices=["absolute", "relative", "both"],
        default="absolute",
        help="Value used for precompute Dij size boxplots.",
    )
    parser.add_argument("--where", action="append", default=[], metavar="FIELD=VALUE[,VALUE]")
    parser.add_argument("--exclude", dest="exclude_filters", action="append", default=[], metavar="FIELD=VALUE[,VALUE]")
    parser.add_argument("--exclude-approach", nargs="*", default=[], help="Deprecated shortcut for --exclude approach=...")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    if args.exclude_approach:
        args.exclude_filters.extend(f"approach={approach}" for approach in args.exclude_approach)
    filters = parse_filter_specs(args.where, args.exclude_filters)
    figures = selected_figure_modes(args.figure)

    if "endpoint" in figures:
        rows = mark_pareto_dominance(apply_row_filters(collect_endpoint_rows(args.mat), filters))
        if not rows:
            raise RuntimeError("No endpoint rows were found after filtering.")
        endpoint_csv = args.out_dir / "ri1_endpoint_points.csv"
        write_csv(rows, endpoint_csv, endpoint_fieldnames())
        print(f"Wrote {endpoint_csv}")
        for stat_mode in selected_stat_modes(args.stat):
            for filter_mode in selected_filter_modes(args.filter_mode):
                plot_rows = rows if filter_mode == "all" else [row for row in rows if row.get(f"dominant_{stat_mode}")]
                if filter_mode == "dominant":
                    dominant_csv = args.out_dir / f"ri1_endpoint_{stat_mode}_dominant_points.csv"
                    write_csv(plot_rows, dominant_csv, endpoint_fieldnames())
                    print(f"Wrote {dominant_csv}")
                path = args.out_dir / f"ri1_endpoint_{stat_mode}_{filter_mode}_scatter.png"
                plot_endpoint_rows(plot_rows, path, stat_mode, filter_mode)
                print(f"Wrote {path}")

    if "time" in figures:
        time_modes = selected_time_modes(args.time_mode)
        if "precompute_dij_time" in time_modes:
            rows = apply_row_filters(collect_precompute_dij_rows(args.mat), filters)
            if not rows:
                raise RuntimeError("No precompute Dij timing rows were found after filtering.")
            fields = precompute_dij_fieldnames()
            points = args.out_dir / "precompute_dij_time_points.csv"
            write_csv(rows, points, fields)
            print(f"Wrote {points}")
            for value_mode in selected_value_modes(args.time_value):
                write_boxplot_metric_outputs(
                    rows,
                    args.out_dir,
                    "precompute_dij_time",
                    value_mode,
                    PRECOMPUTE_TIME_VALUE_CONFIG[value_mode],
                )
        if "optimization_rtpi" in time_modes:
            rows = apply_row_filters(collect_optimization_time_rows(args.mat), filters)
            if not rows:
                raise RuntimeError("No optimization timing rows were found after filtering.")
            fields = timing_fieldnames(["wall_time_seconds", "cpu_time_seconds", "iterations", "time_per_iteration_s", "cpu_time_per_iteration_s", "rtpi", "rtpi_reference_label", "rtpi_reference_time_per_iteration_s"])
            points = args.out_dir / "optimization_rtpi_points.csv"
            write_csv(rows, points, fields)
            print(f"Wrote {points}")
            summary = aggregate_by_approach(rows, "rtpi", "rtpi")
            summary_path = args.out_dir / "optimization_rtpi_summary.csv"
            write_csv(summary, summary_path, ["approach", "display_label", "count", "mean_rtpi", "std_rtpi"])
            print(f"Wrote {summary_path}")
            png = args.out_dir / "optimization_rtpi_boxplot.png"
            plot_approach_boxplots(rows, "rtpi", png, "Optimization rTPI", "rTPI", reference_y=1.0)
            print(f"Wrote {png}")

    if "dij" in figures:
        rows = apply_row_filters(collect_precompute_dij_rows(args.mat), filters)
        if not rows:
            raise RuntimeError("No precompute Dij size rows were found after filtering.")
        fields = precompute_dij_fieldnames()
        points = args.out_dir / "precompute_dij_size_points.csv"
        write_csv(rows, points, fields)
        print(f"Wrote {points}")
        for value_mode in selected_value_modes(args.size_value):
            write_boxplot_metric_outputs(
                rows,
                args.out_dir,
                "precompute_dij_size",
                value_mode,
                PRECOMPUTE_SIZE_VALUE_CONFIG[value_mode],
            )


if __name__ == "__main__":
    main(sys.argv[1:])
