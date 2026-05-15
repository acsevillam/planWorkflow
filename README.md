# planWorkflow Toolbox

`planWorkflow` provides staged robust optimization workflows for matRad with
persistent workflow state, checkpoints, resume support, computational-resource
tracking, dose influence matrix caching, and plan-analysis helpers.

This repository is a standalone MATLAB toolbox. It depends on a compatible
matRad checkout at runtime, but matRad is not vendored here.
Parallel multi-scenario dose-influence calculation uses the
`matRad_supportsParallelScenarioDij` helper when the active matRad checkout
provides it. If the helper is unavailable, the toolbox falls back to serial
scenario dose calculation and emits a warning.

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

The example below assumes the matRad checkout contains a prostate patient with
case id `3482` under its configured patient-data folder. Replace `caseID`,
`rootPath`, and the patient paths with local values when running on a different
dataset.

```matlab
config = struct();
config.rootPath = '/path/to/matRad/userdata';
config.outputRootPath = fullfile(config.rootPath,'output');
config.patientDataPath = fullfile(config.rootPath,'patients');
config.cacheRootPath = fullfile(config.outputRootPath,'cache');

config.prepare.radiationMode = 'photons';
config.prepare.description = 'prostate';
config.prepare.plan_template = 'interval2_001';
config.prepare.caseID = '3482';
config.prepare.plan_beams = '9F';

config.precompute.doseResolution = [3 3 3];
config.precompute.reference.label = 'Nominal';
config.precompute.reference.scenario.mode = 'nomScen';
config.precompute.reference.scenario.ctActive = false;
config.precompute.reference.scenario.ctReferenceScenId = 1;

config.precompute.robustPlans.robust_1.label = 'INTERVAL2';
config.precompute.robustPlans.robust_1.objectiveSetName = 'robust_1';
config.precompute.robustPlans.robust_1.scenario.mode = 'wcScen';
config.precompute.robustPlans.robust_1.scenario.ctActive = true;
config.precompute.robustPlans.robust_1.scenario.ctScenProb = [];
config.precompute.robustPlans.robust_1.scenario.setupActive = true;
config.precompute.robustPlans.robust_1.scenario.shiftSD = [5 10 5];
config.precompute.robustPlans.robust_1.scenario.wcSigma = 1.0;
config.precompute.robustPlans.robust_1.variants(1).id = 'theta_5';
config.precompute.robustPlans.robust_1.variants(1).label = 'theta1=5';
config.precompute.robustPlans.robust_1.variants(1).theta1 = 5;


config.sampling.sampling_linkToOptimization = true;
config.sampling.sampling_scen_mode = 'impScen_permuted5';
config.sampling.sampling_ctActive = true;
config.sampling.sampling_ctScenProb = [];
config.sampling.sampling_setupActive = true;
config.sampling.sampling_shiftSD = [5 10 5];
config.sampling.sampling_wcSigma = 1.5;

config.analysis.evaluationMode = 'total';
config.analysis.gammaWindow = [0 1];
config.analysis.gammaCriteria = [3 3];
config.analysis.robustnessCriteria = [5 5];
config.analysis.robustnessTargetMode = 'include';
config.analysis.robustnessTargets = {'CTV'};

config.resources.doseCalculation.workerUpperBound = [];
config.resources.doseCalculation.releasePoolAfterStage = false;

workflow = planWorkflow.Workflow(config);

workflow.gui();
workflow.prepare();
workflow.precompute();
workflow.pullDose();
workflow.optimize();
workflow.sample();
workflow.analyze();
workflow.save();
```

To inspect and edit the effective plan settings for a single run, call
`workflow.gui()` before `prepare()`. The editor opens only when MATLAB is
running with desktop UI support; in batch mode the call is skipped.

```matlab
workflow.gui();
workflow.prepare();
```

The editor modifies only the in-memory settings used by that workflow run. The
versioned JSON template files are not rewritten. Its tabs match the workflow
stages: `Prepare`, `Precompute`, `Dose pulling`, `Optimize`, `Sampling`, and
`Analysis`. Each tab edits the parameters consumed by that stage; the `Prepare`
tab also exposes the objective-defined target, beam set parameters, dose grid
resolution, and a single objective table with a `Structure` column.

`resources.sampling.workerUpperBound` and
`resources.doseCalculation.workerUpperBound` may be empty or a finite positive
integer. `workerUpperBound = 1` is valid and can force serial execution when at
least two workers would be required. `resources.doseCalculation.releasePoolAfterStage`
defaults to `false`, so pools created outside the workflow are not closed unless
the run explicitly opts into that cleanup.

The robust scenario defaults and catalog presets are photon-oriented examples.
When selecting catalog robust plans for proton, carbon, or helium workflows,
call `RobustPlanCatalog.select/all` with `radiationMode` and an explicit
`robustScenario` that defines the range-uncertainty policy. The catalog does
not infer range uncertainty for particles.

## Tests

Run the fast package tests from MATLAB:

```matlab
addpath('/path/to/external/planWorkflow');
setupPlanWorkflow('/path/to/matRad');
planWorkflow.runTests('/path/to/matRad');
```

The tests cover strict config validation, patient-surface skin generation, dose
scaling and pulling, JSON treatment-plan templates, robustness strategies, and
workflow artifact persistence with synthetic data.

## Notes

Patient data, generated workflow output, dose influence matrix caches, and
machine-specific binaries are intentionally not part of this repository.

Plan templates live as component folders under `+planWorkflow/+templates/json`.
Templates are organized by anatomical location. With
`description = 'prostate'`, `plan_template = 'interval2_001'` selects the
`json/prostate/interval2_001` component folder. The initial template is split into
`metadata.json`,
`beams.json`, `objectives.json`, and `structures.json`. The prescription,
dose-pulling channels, target selection, and all structure/ring objective specs live in
`objectives.json`; `structures.json` defines selectors, structure roles,
priorities, and derived ring geometry/display metadata. Templates are not tied
to a radiation mode; `radiationMode` is a prepare-stage workflow parameter.
In `objectiveSets.robustPlans`, an objective `parameters.penalty` may be a
finite numeric vector to request a deterministic penalty sweep. The public
config still defines only robust parameter `variants`; planWorkflow expands
those variants internally with the penalty combinations during validation.
Penalty sweeps are capped at 1000 combinations per robust objective set and
10000 internal variants after combining with robust parameter variants. A
penalty vector is not allowed on an objective configured with a
`dose_pulling_2` channel; use a scalar penalty there or move the sweep to a
non-pulled objective.
