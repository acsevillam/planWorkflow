# planWorkflow Package

`planWorkflow` provides staged robust optimization workflows with persistent state,
checkpoints, resume support, computational-resource tracking, and dose
influence matrix caching. The package is intended to live in a standalone
toolbox repository whose root folder is on the MATLAB path.

## Class layout

- `planWorkflow.WorkflowBase`: common lifecycle, state, resume, output paths, cache handling, timing, and memory tracking.
- `planWorkflow.PhotonWorkflow`: public photon robust optimization workflow entrypoint.
- `planWorkflow.Engine`: internal robust workflow implementation used by `planWorkflow.PhotonWorkflow`.
- `planWorkflow.config.Analysis`: strict analysis defaults, validation, and prescription-based dose windows.
- `planWorkflow.analysis.ExpectedQi`: QI calculation from the expected DVH curve used by trustband plots.
- `planWorkflow.analysis.ResultLogger`: compact console formatting for final analysis summaries.
- `planWorkflow.analysis.PlanAnalysis`, `planWorkflow.analysis.Figures`: plan-analysis and sampling-figure helpers.
- `planWorkflow.io.loadGeometry`: geometry import from MAT or DICOM patient data.
- `planWorkflow.plan.Plan`, `planWorkflow.plan.loadBeams`, `planWorkflow.plan.loadObjectives`, `planWorkflow.plan.Objectives`: plan construction, beam/objective selectors, and objective helpers.
- `planWorkflow.scenario.createModel`: scenario-model factory using matRad scenario classes.
- `planWorkflow.structures.normalizeNames`, `planWorkflow.structures.scaleDoseObjectives`: cst name normalization and dose-pulling objective scaling.
- `planWorkflow.robustness.AbstractStrategy`: common interface for robust objective strategies.
- `planWorkflow.robustness.StochasticStrategy`, `planWorkflow.robustness.COWCStrategy`, `planWorkflow.robustness.CheapCOWCStrategy`, `planWorkflow.robustness.NoneStrategy`, `planWorkflow.robustness.IntervalStrategy`: concrete strategy implementations.

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

## Resume

```matlab
workflow = planWorkflow.WorkflowBase.resumeFrom('/path/to/workflow_state.mat');
workflow.optimize();
```

## Tests

Run the fast package tests from MATLAB after the planWorkflow repository root is
available on the MATLAB path:

```matlab
planWorkflow.runTests();
```

Pass the matRad checkout explicitly when using planWorkflow as a standalone toolbox:

```matlab
planWorkflow.runTests('/path/to/matRad');
```

The tests cover strict config validation, dose scaling, robustness strategies,
and workflow artifact persistence with synthetic data.

## Stages

`precompute()` creates or loads required dose influence matrices from cache.
`pullDose()` adapts dose-pulling objectives and stores warm-start weights for
the final optimization. `sample()` generates sampled dose scenarios and stores
them in `workflow_data.mat`. `analyze()` calculates plan indicators and, when
sampled data exists, runs `matRad_samplingAnalysis` and stores final results in
`workflow_results.mat`.

Each run folder stores a lightweight `workflow_state.mat` manifest plus separate
`workflow_data.mat`, `workflow_results.mat`, and `workflow_performance.mat`
artifacts. Computational resource timing and memory are stored in
`workflow_performance.mat` as `computationalResources`; stage records include
wall-clock seconds, CPU seconds, MATLAB process resident set size, `obj.data`
bytes, status, timestamps, attempts, and per-stage history.

The photon workflow currently supports `none`, `STOCH`, `STOCH2`, `COWC`,
`COWC2`, `c-COWC`, and `c-COWC2`. Scenario generation uses
`matRad_NominalScenario`, `matRad_WorstCaseScenarios`,
`matRad_ImportanceScenarios`, `matRad_TruncatedImportanceScenarios`, and
`matRad_RandomScenarios` through `planWorkflow.scenario.createModel`. Interval
strategies are represented by `planWorkflow.robustness.IntervalStrategy`, but require a
concrete interval precompute implementation before optimization.

Use `scen_mode` and `wcSigma` for the optimization scenario model, and
`sampling_scen_mode` and `sampling_wcSigma` for the sampling scenario model.
Truncated importance modes use the same effective sigma as their stage
(`wcSigma` or `sampling_wcSigma`) as the Mahalanobis truncation radius. Empty
analysis dose windows are filled from the prescription during `prepare()`. The
workflow configuration is strict: analysis parameters belong in the `analysis`
struct, and misplaced root-level fields such as `sampling`, `sampling_mode`,
`gammaCriteria`, or `doseWindowDvh` are intentionally rejected.
