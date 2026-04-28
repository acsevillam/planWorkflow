# planWorkflow Toolbox

`planWorkflow` provides staged robust optimization workflows for matRad with
persistent workflow state, checkpoints, resume support, computational-resource
tracking, dose influence matrix caching, and plan-analysis helpers.

This repository is a standalone MATLAB toolbox. It depends on a compatible
matRad checkout at runtime, but matRad is not vendored here.

## Layout

- `+planWorkflow`: toolbox package namespace.
- `+planWorkflow/tests`: fast MATLAB unit tests.
- `setupPlanWorkflow.m`: path setup helper for planWorkflow and matRad.

## Setup

When used from a matRad integration worktree, add the toolbox root and
initialize matRad:

```matlab
addpath('/path/to/matRad/submodules/planWorkflow');
setupPlanWorkflow('/path/to/matRad');
```

If matRad is already on the MATLAB path, the toolbox can also be added directly:

```matlab
addpath('/path/to/external/planWorkflow');
```

## Example

```matlab
config = struct();
config.radiationMode = 'photons';
config.description = 'prostate';
config.caseID = '3482';
config.robustness = 'COWC';
config.scen_mode = 'wcScen';
config.wcSigma = 1.0;
config.sampling_scen_mode = 'impScen_permuted5';
config.sampling_wcSigma = 1.5;
config.analysis = struct('doseWindowDvh',[],'gammaCriteria',[3 3], ...
    'robustnessCriteria',[5 5]);

workflow = planWorkflow.PhotonWorkflow(config);

workflow.prepare();
workflow.precompute();
workflow.pullDose();
workflow.optimize();
workflow.sample();
workflow.analyze();
workflow.save();
```

## Tests

Run the fast package tests from MATLAB:

```matlab
addpath('/path/to/external/planWorkflow');
setupPlanWorkflow('/path/to/matRad');
planWorkflow.runTests('/path/to/matRad');
```

The tests cover strict config validation, dose scaling, robustness strategies,
and workflow artifact persistence with synthetic data.

## Notes

Patient data, generated workflow output, dose influence matrix caches, and
machine-specific binaries are intentionally not part of this repository.
