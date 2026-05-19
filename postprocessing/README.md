# planWorkflow Postprocessing

Python postprocessing tools for `workflow_results.mat` files produced by
`planWorkflow`.

## Current command

Run from this directory, or add it to `PYTHONPATH`:

```bash
.venv/bin/python -m planworkflow_postprocessing \
  --mat /path/to/run_a/workflow_results.mat /path/to/run_b/workflow_results.mat \
  --out-dir /path/to/output \
  --figure all \
  --stat por \
  --filter all
```

The module writes:

- `ri1_endpoint_points.csv`
- `ri1_endpoint_<stat>_<all|dominant>_scatter.png`
- `precompute_dij_time_points.csv`
- `precompute_dij_time_boxplot.png`
- `precompute_dij_time_relative_boxplot.png` when `--time-value relative|both`
- `optimization_rtpi_points.csv`
- `optimization_rtpi_boxplot.png`
- `precompute_dij_size_points.csv`
- `precompute_dij_size_boxplot.png`
- `precompute_dij_size_relative_boxplot.png` when `--size-value relative|both`

## Timing modes

`--figure time` can be restricted with:

```bash
--time-mode precompute_dij_time
--time-mode optimization_rtpi
--time-mode all
```

`precompute_dij_time` reads `dijPrecomputingTimeSeconds` directly from
`/results/performance/planTimings`. `optimization_rtpi` reads `rTPI` directly
from the same table for robust `fluenceOptimization` timings. Precompute Dij
size uses `dijPrecomputingSizeBytes`.

Precompute time and size boxplots can use absolute or relative values:

```bash
--time-value absolute
--time-value relative
--time-value both

--size-value absolute
--size-value relative
--size-value both
```

Absolute time uses `dijPrecomputingTimeSeconds`; relative time uses
`relativeDijPrecomputingTime`. Absolute size uses `dijPrecomputingSizeBytes`
reported in GiB; relative size uses `relativeDijPrecomputingSize`.

## Filters

Rows can be filtered before CSV/figure generation:

```bash
--where patient=3482
--where scen_mode=impScen*
--exclude robustness=c-COWC
--exclude approach=cheap-minimax
```

Supported metadata fields include patient, site, radiation mode, workflow,
series id, scenario mode, dose-pulling flags, robustness mode, robust plan id,
and precompute scenario count. The typo alias `robutsness` is accepted for
backward compatibility.

## Dependencies

Reading MATLAB v7.3 files and plotting requires:

- `h5py`
- `numpy`
- `matplotlib`

The MATLAB GUI uses the repository-local `.venv` by default:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install h5py numpy matplotlib pandas
```

Pure helper tests do not require those dependencies.

## Tests

```bash
.venv/bin/python postprocessing/tests/test_robust_analysis.py
```

## MATLAB GUI

The MATLAB postprocessing editor is available from the `planWorkflow` package:

```matlab
planWorkflow.gui.PostprocessingEditor.open()
```

The editor discovers `workflow_results.mat` files from selected folders,
builds the Python CLI commands, runs them, and shows generated PNG figures in a
Results tab.
