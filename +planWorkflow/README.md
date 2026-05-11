# planWorkflow Package

`planWorkflow` provides staged robust optimization workflows with persistent state,
checkpoints, resume support, computational-resource tracking, and dose
influence matrix caching. The package is intended to live in a standalone
toolbox repository whose root folder is on the MATLAB path.

## Class layout

- `planWorkflow.WorkflowBase`: common lifecycle, state, resume, output paths, cache handling, timing, and memory tracking.
- `planWorkflow.Workflow`: public robust optimization workflow entrypoint.
- `planWorkflow.Engine`: internal robust workflow implementation used by `planWorkflow.Workflow`.
- `planWorkflow.config.Analysis`: strict analysis defaults, validation, and prescription-based dose windows.
- `planWorkflow.analysis.ExpectedQi`: QI calculation from the expected DVH curve used by trustband plots.
- `planWorkflow.analysis.ResultLogger`: compact console formatting for final analysis summaries.
- `planWorkflow.analysis.PlanAnalysis`, `planWorkflow.analysis.Figures`: plan-analysis and sampling-figure helpers.
- `planWorkflow.io.loadGeometry`, `planWorkflow.io.createDicomMetadata`: geometry import from MAT or DICOM patient data and DICOM import metadata assembly.
- `planWorkflow.templates.PlanTemplate`: strict JSON-backed treatment-plan templates for beams, structures, objectives, and derived structures.
- `planWorkflow.plan.Plan`, `planWorkflow.plan.loadBeams`, `planWorkflow.plan.Objectives`: plan construction, beam selectors, and objective helpers.
- `planWorkflow.scenario.createModel`: scenario-model factory using matRad scenario classes.
- `planWorkflow.structures.normalizeNames`, `planWorkflow.structures.createSkin`, `planWorkflow.structures.pullDose`: cst name normalization, patient-surface skin generation, and dose-pulling increments.
- `planWorkflow.robustness.AbstractStrategy`: common interface for robust objective strategies.
- `planWorkflow.robustness.StochasticStrategy`, `planWorkflow.robustness.COWCStrategy`, `planWorkflow.robustness.CheapCOWCStrategy`, `planWorkflow.robustness.NoneStrategy`, `planWorkflow.robustness.IntervalStrategy`: concrete strategy implementations.

## Example

```matlab
config = struct();
config.prepare.radiationMode = 'photons';
config.prepare.description = 'prostate';
config.prepare.plan_template = 'interval2_001';
config.prepare.caseID = '3482';
config.prepare.plan_beams = '9F';
config.precompute.reference.label = 'Nominal';
config.precompute.reference.robustnessMode = 'none';
config.precompute.reference.scenario.mode = 'nomScen';
config.precompute.reference.scenario.ctActive = false;
config.precompute.reference.scenario.setupActive = false;
config.precompute.reference.scenario.rangeActive = false;
config.precompute.reference.scenario.gantryActive = false;
config.precompute.reference.scenario.couchActive = false;
config.precompute.robustPlans.robust_1.label = 'INTERVAL2 theta sweep';
config.precompute.robustPlans.robust_1.objectiveSetName = 'robust_1';
config.precompute.robustPlans.robust_1.scenario.mode = 'wcScen';
config.precompute.robustPlans.robust_1.scenario.ctActive = true;
config.precompute.robustPlans.robust_1.scenario.ctScenProb = [];
config.precompute.robustPlans.robust_1.scenario.setupActive = true;
config.precompute.robustPlans.robust_1.scenario.rangeActive = false;
config.precompute.robustPlans.robust_1.scenario.gantryActive = false;
config.precompute.robustPlans.robust_1.scenario.couchActive = false;
config.precompute.robustPlans.robust_1.scenario.shiftSD = [5 10 5];
config.precompute.robustPlans.robust_1.scenario.wcSigma = 1.0;
config.precompute.robustPlans.robust_1.variants.id = 'theta_10';
config.precompute.robustPlans.robust_1.variants.label = 'theta1=10';
config.precompute.robustPlans.robust_1.variants.theta1 = 10;
config.sampling.sampling_scen_mode = 'impScen_permuted5';
config.sampling.sampling_ctScenProb = [];
config.sampling.sampling_wcSigma = 1.5;
config.analysis = struct('doseWindowDvh',[],'gammaCriteria',[3 3], ...
    'robustnessCriteria',[5 5]);

workflow = planWorkflow.Workflow(config);

workflow.prepare();
workflow.precompute();
workflow.pullDose();
workflow.optimize();
workflow.sample();
workflow.analyze();
workflow.save();
```

Robust plan templates can define `parameters.penalty` as a finite numeric
vector inside `objectiveSets.robustPlans`. The workflow keeps `reference` as a
single-plan objective set and expands robust `variants` with penalty
combinations internally; macros export only the public robust parameter
`variants`. Penalty sweeps are capped at 1000 combinations per robust
objective set and 10000 internal variants after combining with robust
parameter variants. A penalty vector is rejected on objectives using a
`dose_pulling_2` channel; keep those objectives scalar or move the sweep to a
non-pulled objective.

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

The tests cover strict config validation, patient-surface skin generation, dose
scaling, robustness strategies, and workflow artifact persistence with synthetic
data.

## Stages

`precompute()` creates or loads required dose influence matrices from cache.
`pullDose()` adapts dose-pulling objectives and stores warm-start weights for
the final optimization. `sample()` generates sampled dose scenarios and stores
them in `workflow_data.mat`. `analyze()` calculates plan indicators and, when
sampled data exists, runs `matRad_samplingAnalysis` and stores final results in
`workflow_results.mat`.

Each run folder stores a lightweight `workflow_state.mat` manifest plus separate
`workflow_data.mat`, `workflow_results.mat`, and `workflow_performance.mat`
artifacts. Performance timing and memory are stored in `workflow_results.mat`
under `results.performance` and mirrored in `workflow_performance.mat` as
`performance`. Stage records include wall-clock seconds, CPU seconds, MATLAB
process resident set size, `obj.data` bytes, status, timestamps, attempts, and
per-stage history. Plan records additionally split measured work by stage,
reference/robust role, robust plan, variant, and task.

The photon workflow reads supported matRad objective and robustness capabilities
through `planWorkflow.matRadCapabilitiesReader`. The executable robustness
modes exposed by the workflow are `none`, `STOCH`, `COWC`, `c-COWC`,
`PROB2`, `INTERVAL2`, and `INTERVAL3` when the loaded matRad provides those base
capabilities. Scenario generation uses
`matRad_NominalScenario`, `matRad_WorstCaseScenarios`,
`matRad_ImportanceScenarios`, `matRad_TruncatedImportanceScenarios`, and
`matRad_RandomScenarios` through `planWorkflow.scenario.createModel`. Interval
strategies call matRad's native `matRad_calcDoseInterval2` and
`matRad_calcDoseInterval3` precompute functions before optimization.
`PROB2` calls `matRad_calcDoseProb2` and attaches the cached `dij_prob2`
payload only to the optimization plan. `INTERVAL2/3` use `radiusMode = 'std'`
or `'extreme'`; `INTERVAL3` consumes `OARRadiusFactor` and `OARRadiusRank`
without legacy `U/S/V/k` cache compatibility. Constraints remain entries in
the existing objective arrays because matRad consumes them from `cst{i,6}`.

Use explicit `reference_*`, `robust_*`, and `sampling_*` scenario fields for
the reference, robust, and sampling scenario models. For example,
`robust_scen_mode` and `robust_wcSigma` configure the robust precompute model,
while `sampling_scen_mode` and `sampling_wcSigma` configure sampling. Truncated
importance modes use the effective sigma from their own stage as the
Mahalanobis truncation radius. Empty analysis dose windows are filled from the
prescription during `prepare()`. The workflow configuration is strict: analysis
parameters belong in the `analysis` struct, and misplaced root-level fields
such as `sampling`, `sampling_mode`, `gammaCriteria`, or `doseWindowDvh` are
intentionally rejected.

For breast workflows, `normalizeNames` can create a missing `SKIN` structure
from the patient `BODY`/external contour. `skinMode = 'full'` creates the full
patient-surface shell; `skinMode = 'targetRegion'` keeps a compact surface patch
whose skin voxels are within `skinTargetDistanceMm` from the configured target.
The target-region patch is reduced to one connected component and surface holes
are filled. `skinThicknessMm` can be set to create a thicker inward shell.

## Plan Templates

`plan_template` selects a component folder under the anatomical location
declared by `description`. With `description = 'prostate'`,
`plan_template = 'interval2_001'` selects `+planWorkflow/+templates/json/prostate/interval2_001`.
The first supported template is split into `metadata.json`, `beams.json`,
`objectives.json`, and `structures.json` so each plan component can be reviewed
independently. `objectives.json` owns all structure and ring objective specs;
the prescription, target selection, and dose-pulling channels. `structures.json`
describes selectors, structure roles, priorities, and derived-ring
geometry/display metadata. Templates are not tied to a radiation mode;
`radiationMode` is a prepare-stage workflow parameter. Workflow configs can
group stage-specific settings under stage structs. The prepare group selects
the anatomical template and beam set after it declares the workflow anatomy:

```matlab
config.prepare.radiationMode = 'photons';
config.prepare.description = 'prostate';
config.prepare.plan_template = 'interval2_001';
config.prepare.plan_beams = '9F';
workflow.prepare();
```

The JSON loader assembles and validates the component files, including template
id, beam set, and objective-defined target. Objective parameters are named matRad
constructor values; `dosePulling.rates` applies the configured pulling channel
start offset and later pulling increments. The template loader does not evaluate
arbitrary expressions.

Call `workflow.gui()` before `prepare()` to open a modal editor after the
selected JSON template is loaded and before the workflow prepares geometry,
objectives, beams, and cache paths. The editor opens only when MATLAB is running
with desktop UI support; batch runs skip the call.

```matlab
workflow.gui();
workflow.prepare();
```

The editor is organized by workflow stage: `Prepare`, `Precompute`,
`Dose pulling`, `Optimize`, `Sampling`, and `Analysis`. Each tab edits the
parameters consumed by that stage. The `Prepare` tab also changes the selected
objective-defined target, beam set, beam parameters, dose grid resolution, prescription, and
objective rows in a single table keyed by `Structure`; `Dose pulling` edits both
workflow dose-pulling controls and template pulling channels/rates. The accepted
template is stored with the workflow artifacts together with a stable hash used
in cache keys; the JSON files under `+templates/json` are not modified.
