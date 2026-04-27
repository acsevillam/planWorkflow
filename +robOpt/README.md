# robOpt Package

`robOpt` provides staged robust optimization workflows with persistent state,
checkpoints, resume support, computational-resource tracking, and dose
influence matrix caching. The package is intended to live in a standalone
toolbox repository whose root folder is on the MATLAB path.

## Class layout

- `robOpt.WorkflowBase`: common lifecycle, state, resume, output paths, cache handling, timing, and memory tracking.
- `robOpt.PhotonWorkflow`: public photon robust optimization workflow entrypoint.
- `robOpt.Engine`: internal robust workflow implementation used by `robOpt.PhotonWorkflow`.
- `robOpt.config.Analysis`: strict analysis defaults, validation, and prescription-based dose windows.
- `robOpt.analysis.ExpectedQi`: QI calculation from the expected DVH curve used by trustband plots.
- `robOpt.analysis.ResultLogger`: compact console formatting for final analysis summaries.
- `robOpt.analysis.PlanAnalysis`, `robOpt.analysis.Figures`: plan-analysis and sampling-figure helpers.
- `robOpt.io.loadGeometry`: geometry import from MAT or DICOM patient data.
- `robOpt.plan.Plan`, `robOpt.plan.loadBeams`, `robOpt.plan.loadObjectives`, `robOpt.plan.Objectives`: plan construction, beam/objective selectors, and objective helpers.
- `robOpt.scenario.createModel`: scenario-model factory using matRad scenario classes.
- `robOpt.structures.normalizeNames`, `robOpt.structures.scaleDoseObjectives`: cst name normalization and dose-pulling objective scaling.
- `robOpt.robustness.AbstractStrategy`: common interface for robust objective strategies.
- `robOpt.robustness.StochasticStrategy`, `robOpt.robustness.COWCStrategy`, `robOpt.robustness.CheapCOWCStrategy`, `robOpt.robustness.NoneStrategy`, `robOpt.robustness.IntervalStrategy`: concrete strategy implementations.

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

workflow = robOpt.PhotonWorkflow(config);

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
workflow = robOpt.WorkflowBase.resumeFrom('/path/to/workflow_state.mat');
workflow.optimize();
```

## Tests

Run the fast package tests from MATLAB after the robOpt repository root is
available on the MATLAB path:

```matlab
robOpt.runTests();
```

Pass the matRad checkout explicitly when using robOpt as a standalone toolbox:

```matlab
robOpt.runTests('/Users/acsevillam/workspace/matRad/integration_varRBErobOpt_robOpt');
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
`matRad_RandomScenarios` through `robOpt.scenario.createModel`. Interval
strategies are represented by `robOpt.robustness.IntervalStrategy`, but require a
concrete interval precompute implementation before optimization.

Use `scen_mode` and `wcSigma` for the optimization scenario model, and
`sampling_scen_mode` and `sampling_wcSigma` for the sampling scenario model.
Truncated importance modes use the same effective sigma as their stage
(`wcSigma` or `sampling_wcSigma`) as the Mahalanobis truncation radius. Empty
analysis dose windows are filled from the prescription during `prepare()`. The
workflow configuration is strict: analysis parameters belong in the `analysis`
struct, and misplaced root-level fields such as `sampling`, `sampling_mode`,
`gammaCriteria`, or `doseWindowDvh` are intentionally rejected.
