function tests = testPlanEditor
tests = functiontests(localfunctions);
end

function testPreparePreflightDoesNotOpenEditor(testCase)
workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));

workflow.prepareEffectivePlanTemplatePublic();

verifyFalse(testCase,workflow.editorWasCalled);
verifyEqual(testCase,workflow.runConfig.plan_beams,'9F');
verifyNotEmpty(testCase,workflow.runConfig.plan_template_hash);
end

function testGuiStageSkipsWhenUiUnavailable(testCase)
workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
workflow.setGuiSupport(false);

workflow.gui();

verifyFalse(testCase,workflow.editorWasCalled);
verifyEqual(testCase,workflow.runConfig.plan_template_hash,'');
end

function testClosedEditorReturnsWithoutError(testCase)
workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
workflow.setEditorResponse(template,workflow.runConfig,false);

workflow.gui();

verifyTrue(testCase,workflow.editorWasCalled);
verifyEmpty(testCase,workflow.guiProgressReporter);
verifyEqual(testCase,workflow.runConfig.plan_template_hash,'');
end

function testPlanEditorCloseConfirmationDistinguishesEditorAndProgress(testCase)
[message,title,confirmLabel,cancelLabel] = ...
    planWorkflow.gui.PlanEditor.closeConfirmationDialog(false);
verifyEqual(testCase,title,'Close plan workflow editor');
verifyTrue(testCase,contains(message,'discard unapplied changes'));
verifyEqual(testCase,confirmLabel,'Close editor');
verifyEqual(testCase,cancelLabel,'Continue editing');

[message,~,confirmLabel,cancelLabel] = ...
    planWorkflow.gui.PlanEditor.closeConfirmationDialog(true);
verifyTrue(testCase,contains(message,'workflow will continue'));
verifyTrue(testCase,contains(message,'Use Stop'));
verifyEqual(testCase,confirmLabel,'Close window');
verifyEqual(testCase,cancelLabel,'Keep open');

verifyTrue(testCase,planWorkflow.gui.PlanEditor.confirmCloseRequest( ...
    true,@(varargin) varargin{3}));
verifyFalse(testCase,planWorkflow.gui.PlanEditor.confirmCloseRequest( ...
    true,@(varargin) varargin{4}));
end

function testGuiCanChangeSelectedBeamSet(testCase)
workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
runConfig = workflow.runConfig;
runConfig.plan_beams = '7F';
workflow.setEditorResponse(template,runConfig,true);

workflow.gui();

verifyEqual(testCase,workflow.runConfig.plan_beams,'7F');
verifyNotEmpty(testCase,workflow.runConfig.plan_template_hash);
verifyTrue(testCase,contains(workflow.cacheKeyPublic('reference'),'7F'));
end

function testGuiUsesEditedTemplateForCalculateNormalization(testCase)
workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
objectiveSetName = firstRobustObjectiveSetName(template);
template = ...
    planWorkflow.templates.ObjectiveRobustnessMutator.harmonizeTemplateNonNoneRobustness( ...
    template,objectiveSetName,'INTERVAL3');
runConfig = workflow.runConfig;
runConfig.precompute.robustPlans(1).label = 'INTERVAL3';
workflow.setEditorResponse(template,runConfig,true);

workflow.gui();

robustPlans = workflow.runConfig.precompute.robustPlans;
contract = ...
    planWorkflow.templates.ObjectiveRobustnessContract.forTemplateObjectiveSet( ...
    workflow.data.planTemplate,objectiveSetName);

verifyEqual(testCase,workflow.runConfig.plan_template,'interval2_001');
verifyEqual(testCase,robustPlans(1).label,'INTERVAL3');
verifyEqual(testCase,robustPlans(1).robustnessMode,'INTERVAL3');
verifyEqual(testCase,contract.robustnessMode,'INTERVAL3');
verifyEqual(testCase,workflow.runConfig.plan_template_hash, ...
    planWorkflow.templates.PlanTemplate.hash(template));
end

function testGuiPlanLabelDoesNotDriveObjectiveRobustness(testCase)
workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
runConfig = workflow.runConfig;
runConfig.precompute.robustPlans(1).label = 'INTERVAL3';
workflow.setEditorResponse(template,runConfig,true);

workflow.gui();

robustPlans = workflow.runConfig.precompute.robustPlans;

verifyEqual(testCase,robustPlans(1).label,'INTERVAL3');
verifyEqual(testCase,robustPlans(1).robustnessMode,'INTERVAL2');
end

function testPlanEditorValidateRunConfigRequiresTemplateInput(testCase)
options = struct();
options.validateRunConfig = @(runConfig) runConfig;

verifyError(testCase,@() ...
    planWorkflow.gui.PlanEditor.normalizeEditorOptions(options), ...
    'planWorkflow:gui:PlanEditor:InvalidEditorOptions');

options.validateRunConfig = @(runConfig,template) runConfig;
options = planWorkflow.gui.PlanEditor.normalizeEditorOptions(options);

verifyEqual(testCase,nargin(options.validateRunConfig),2);
end

function testAnalyzedWorkflowGuiProvidesInitialResultsAndRecalculateCallback(testCase)
workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
workflow.data.results = struct('analysisCount',1, ...
    'runConfig',workflow.runConfig);
workflow.state.completedStages = {'prepared','precomputed', ...
    'dose_pulled','optimized','sampled','analyzed'};
workflow.setEditorResponse(template,workflow.runConfig,true);

workflow.gui();

verifyTrue(testCase,workflow.editorOptions.readOnly);
verifyTrue(testCase,isa( ...
    workflow.editorOptions.recalculateAnalysisCallback,'function_handle'));
verifyTrue(testCase,isa( ...
    workflow.editorOptions.progressReporterReadyCallback, ...
    'function_handle'));
verifyEqual(testCase,workflow.editorOptions.initialResults.analysisCount,1);
verifyTrue(testCase,isfield(workflow.editorOptions.initialResults, ...
    'performance'));
end

function testHiddenParameterPanelFieldsAreRemovedFromConfig(testCase)
fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
panel = uipanel('Parent',fig);
specs = struct( ...
    'field',{'scenarioSection','ctActive','ctScenProb', ...
    'ctReferenceScenId','shiftSD'}, ...
    'type',{'section','logical','numericVectorAllowEmpty', ...
    'numericScalar','numericVector'});
visibleFields = {'ctActive','ctReferenceScenId'};
planWorkflow.gui.ParameterPanelProjection.setVisibleFields( ...
    panel,visibleFields);
config = struct('ctActive',false,'ctScenProb',[0.4 0.6], ...
    'ctReferenceScenId',2,'shiftSD',[5 5 5]);

config = planWorkflow.gui.ParameterPanelProjection.removeInactiveFields( ...
    config,specs, ...
    planWorkflow.gui.ParameterPanelProjection.visibleFields( ...
    panel,specs));

verifyTrue(testCase,isfield(config,'ctActive'));
verifyTrue(testCase,isfield(config,'ctReferenceScenId'));
verifyFalse(testCase,isfield(config,'ctScenProb'));
verifyFalse(testCase,isfield(config,'shiftSD'));
end

function testParameterPanelDefaultCallbackRunsAfterFieldCallback(testCase)
fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
specs = struct('name','robustness','field','robustness', ...
    'type','char','helpText','');
optionSets = struct('robustness',{{'INTERVAL2','COWC'}});
callbacks = struct();
callbacks.robustness = @(~,~) setappdata(fig,'specificDone',true);
callbacks.defaultCallback = @(~,~) setappdata(fig, ...
    'defaultSawSpecific',logical(getappdata(fig,'specificDone')));

tableHandle = planWorkflow.gui.ParameterPanelRenderer.create( ...
    fig,[0 0 1 1],specs,optionSets,struct(),callbacks);
callback = get(tableHandle.controls(1),'Callback');
callback(tableHandle.controls(1),[]);

verifyTrue(testCase,getappdata(fig,'defaultSawSpecific'));
end

function testKModeIsPopupEvenWhenInitialStrategyDoesNotUseIt(testCase)
runConfig = struct();
runConfig.useCache = true;
runConfig.writeCache = true;
runConfig.precompute = planWorkflow.config.RobustPlanConfig.defaults();
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.robustnessMode = 'INTERVAL2';
plan.scenario = planWorkflow.config.ScenarioSpec.defaults('nomScen');
plan.variants = ...
    planWorkflow.config.RobustStrategySpec.defaultVariant('INTERVAL2',1);
runConfig.precompute.robustPlans = plan;

fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
tabGroup = uitabgroup('Parent',fig);
parent = uitab(tabGroup);
callbacks = struct('addRobustPlan',[],'deleteRobustPlan',[], ...
    'reference',struct());

handles = planWorkflow.gui.panels.PrecomputeEditorPanel.create( ...
    parent,runConfig,callbacks);
handles = ...
    planWorkflow.gui.panels.PrecomputeEditorPanel.rebuildRobustTabs( ...
    handles,runConfig);
fields = {handles.robustConfigTables(1).specs.field};
KModeIx = find(strcmp(fields,'KMode'),1);

verifyEqual(testCase, ...
    get(handles.robustConfigTables(1).controls(KModeIx),'Style'), ...
    'popupmenu');
verifyEqual(testCase, ...
    get(handles.robustConfigTables(1).controls(KModeIx),'String'), ...
    {'dynamic';'static'});
end

function testPrecomputeRobustnessFieldIsDropdownForRobustPlans(testCase)
runConfig = baseRunConfigWithRobust('INTERVAL2','nomScen', ...
    struct('ctActive',true));
planConfig = runConfig.precompute.robustPlans(1);

fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
tableHandle = planWorkflow.gui.ParameterPanelRenderer.create( ...
    fig,[0 0 1 1], ...
    planWorkflow.gui.panels.PrecomputePanel.robustSpecs(), ...
    planWorkflow.gui.panels.PrecomputePanel.optionSets( ...
    runConfig,planConfig),struct(),struct());

robustnessControl = ...
    planWorkflow.gui.ParameterPanelRenderer.control( ...
    tableHandle,'robustness');

verifyEqual(testCase,get(robustnessControl,'Style'),'popupmenu');
verifyTrue(testCase,any(strcmp(get(robustnessControl,'String'),'PROB2')));
end

function testPrecomputeSyncOnlyRewritesObjectivesWhenRobustnessChanges(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
objectiveSetName = firstRobustObjectiveSetName(template);
runConfig = baseRunConfigWithRobust('INTERVAL2','nomScen', ...
    struct('ctActive',true));
transversalConfig = runConfig;
transversalConfig.bixelWidth = 5;

fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
tabGroup = uitabgroup('Parent',fig);
parent = uitab(tabGroup);
callbacks = struct('addRobustPlan',[],'deleteRobustPlan',[], ...
    'reference',struct());
handles = planWorkflow.gui.panels.PrecomputeEditorPanel.create( ...
    parent,runConfig,callbacks);
[handles,runConfig,template] = ...
    planWorkflow.gui.panels.PrecomputeEditorPanel.load( ...
    handles,runConfig,template,transversalConfig);
baselineData = planWorkflow.gui.ObjectiveTableAdapter.toTable( ...
    template,objectiveSetName);

[handles,runConfig,template,transversalConfig] = ...
    planWorkflow.gui.panels.PrecomputeEditorPanel.sync( ...
    handles,runConfig,template,transversalConfig);
unchangedData = planWorkflow.gui.ObjectiveTableAdapter.toTable( ...
    template,objectiveSetName);

verifyEqual(testCase,unchangedData(:,5),baselineData(:,5));

robustnessControl = ...
    planWorkflow.gui.ParameterPanelRenderer.control( ...
    handles.robustConfigTables(1),'robustness');
robustnessValues = get(robustnessControl,'String');
robustnessIx = find(strcmp(robustnessValues,'INTERVAL3'),1);
set(robustnessControl,'Value',robustnessIx);
handles = ...
    planWorkflow.gui.panels.PrecomputeEditorPanel.refreshVisibility( ...
    handles);

[~,~,template,~] = ...
    planWorkflow.gui.panels.PrecomputeEditorPanel.sync( ...
    handles,runConfig,template,transversalConfig);
changedData = planWorkflow.gui.ObjectiveTableAdapter.toTable( ...
    template,objectiveSetName);

verifyTrue(testCase,any(strcmp(changedData(:,5),'none')));
verifyTrue(testCase,any(strcmp(changedData(:,5),'INTERVAL3')));
verifyFalse(testCase,any(strcmp(changedData(:,5),'INTERVAL2')));
end

function testPrecomputeLoadReusesRobustTabsWhenPlanIdentityUnchanged(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
runConfig = baseRunConfigWithRobust('INTERVAL2','nomScen', ...
    struct('ctActive',true));
transversalConfig = runConfig;
transversalConfig.bixelWidth = 5;

fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
tabGroup = uitabgroup('Parent',fig);
parent = uitab(tabGroup);
callbacks = struct('addRobustPlan',[],'deleteRobustPlan',[], ...
    'reference',struct());
handles = planWorkflow.gui.panels.PrecomputeEditorPanel.create( ...
    parent,runConfig,callbacks);
[handles,runConfig,template] = ...
    planWorkflow.gui.panels.PrecomputeEditorPanel.load( ...
    handles,runConfig,template,transversalConfig);
firstRobustTab = handles.robustTabs(1);
firstRobustPanel = handles.robustConfigTables(1).panel;

runConfig.precompute.robustPlans(1).label = 'Renamed plan';
[handles,~,~] = ...
    planWorkflow.gui.panels.PrecomputeEditorPanel.load( ...
    handles,runConfig,template,transversalConfig);

verifyTrue(testCase,isequal(handles.robustTabs(1),firstRobustTab));
verifyTrue(testCase,isequal(handles.robustConfigTables(1).panel, ...
    firstRobustPanel));
verifyEqual(testCase,get(handles.robustTabs(1),'Title'), ...
    'Renamed plan');
end

function testPrecomputeLoadRebuildsRobustTabsWhenPlanSetChanges(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
runConfig = baseRunConfigWithRobust('INTERVAL2','nomScen', ...
    struct('ctActive',true));
transversalConfig = runConfig;
transversalConfig.bixelWidth = 5;

fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
tabGroup = uitabgroup('Parent',fig);
parent = uitab(tabGroup);
callbacks = struct('addRobustPlan',[],'deleteRobustPlan',[], ...
    'reference',struct());
handles = planWorkflow.gui.panels.PrecomputeEditorPanel.create( ...
    parent,runConfig,callbacks);
[handles,runConfig,template] = ...
    planWorkflow.gui.panels.PrecomputeEditorPanel.load( ...
    handles,runConfig,template,transversalConfig);
firstRobustTab = handles.robustTabs(1);

[template,runConfig] = appendSecondRobustPlan(template,runConfig);
[handles,~,~] = ...
    planWorkflow.gui.panels.PrecomputeEditorPanel.load( ...
    handles,runConfig,template,transversalConfig);

verifyNumElements(testCase,handles.robustTabs,2);
verifyFalse(testCase,ishandle(firstRobustTab));
verifyEqual(testCase,get(handles.robustTabs(2),'Title'),'Robust 2');
end

function testPrecomputeReferenceRobustnessDropdownPreservesNominalObjectives(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
runConfig = baseRunConfig();
transversalConfig = runConfig;
transversalConfig.bixelWidth = 5;

fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
tabGroup = uitabgroup('Parent',fig);
parent = uitab(tabGroup);
callbacks = struct('addRobustPlan',[],'deleteRobustPlan',[], ...
    'reference',struct());
handles = planWorkflow.gui.panels.PrecomputeEditorPanel.create( ...
    parent,runConfig,callbacks);
[handles,runConfig,template] = ...
    planWorkflow.gui.panels.PrecomputeEditorPanel.load( ...
    handles,runConfig,template,transversalConfig);

robustnessControl = ...
    planWorkflow.gui.ParameterPanelRenderer.control( ...
    handles.referenceConfigTable,'reference_robustness');
robustnessValues = get(robustnessControl,'String');
robustnessIx = find(strcmp(robustnessValues,'INTERVAL2'),1);
set(robustnessControl,'Value',robustnessIx);
handles = ...
    planWorkflow.gui.panels.PrecomputeEditorPanel.refreshVisibility( ...
    handles);

[handles,runConfig,template,~] = ...
    planWorkflow.gui.panels.PrecomputeEditorPanel.sync( ...
    handles,runConfig,template,transversalConfig);
data = planWorkflow.gui.ObjectiveTableAdapter.toTable( ...
    template,'reference');
reference = ...
    planWorkflow.config.RobustPlanConfig.referenceFromRunConfig( ...
    runConfig);

verifyTrue(testCase,all(strcmp(data(:,5),'none')));
verifyEqual(testCase,reference.robustnessMode,'none');
verifyEqual(testCase, ...
    planWorkflow.gui.ParameterPanelRenderer.fieldValue( ...
    handles.referenceConfigTable,'reference_robustness'),'none');
end

function testPrepareQuantityOptIsPopupFromBioModel(testCase)
fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
specs = planWorkflow.gui.ParameterPanelSpecAdapter.fromSchema( ...
    planWorkflow.config.WorkflowParameterSchema.prepareBeamSpecs());
optionSets = planWorkflow.gui.WorkflowParameterOptions.prepareBeamOptionSets( ...
    {'9F'},{'protons'},{'Generic'},{'none'},{'physicalDose'});
selectedOptions = struct('plan_beams',1,'radiationMode',1, ...
    'machine',1,'bioModel',1,'quantityOpt',1);

tableHandle = planWorkflow.gui.ParameterPanelRenderer.create( ...
    fig,[0 0 1 1],specs,optionSets,selectedOptions,struct());
fields = {tableHandle.specs.field};
quantityIx = find(strcmp(fields,'quantityOpt'),1);

verifyEqual(testCase,get(tableHandle.controls(quantityIx),'Style'), ...
    'popupmenu');
verifyEqual(testCase,cellstr(get(tableHandle.controls(quantityIx), ...
    'String')),{'physicalDose'});
end

function testPrepareBioModelDerivedFieldsAreReadOnly(testCase)
fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
schemaSpecs = planWorkflow.config.WorkflowParameterSchema.prepareBeamSpecs();
specs = planWorkflow.gui.ParameterPanelSpecAdapter.fromSchema(schemaSpecs);
optionSets = planWorkflow.gui.WorkflowParameterOptions.prepareBeamOptionSets( ...
    {'9F'},{'photons'},{'Generic'},{'none'},{'effect'});
selectedOptions = struct('plan_beams',1,'radiationMode',1, ...
    'machine',1,'bioModel',1,'quantityOpt',1);
beamConfig = struct('radiationMode','photons', ...
    'includeOtherRadiationModes',false, ...
    'machine','Generic','bioModel','none','quantityOpt','effect', ...
    'bioOpt',1,'quantityVis','physicalDose','plan_beams','9F', ...
    'gantryAngles',[0 90],'couchAngles',[0 0]);

tableHandle = planWorkflow.gui.ParameterPanelRenderer.create( ...
    fig,[0 0 1 1],specs,optionSets,selectedOptions,struct());
planWorkflow.gui.ParameterPanelRenderer.load( ...
    tableHandle,beamConfig,optionSets,selectedOptions);
fields = {tableHandle.specs.field};
quantityIx = find(strcmp(fields,'quantityOpt'),1);
bioOptIx = find(strcmp(fields,'bioOpt'),1);
quantityVisIx = find(strcmp(fields,'quantityVis'),1);

verifyEqual(testCase,bioOptIx,quantityIx + 1);
verifyEqual(testCase,quantityVisIx,quantityIx + 2);
verifyEqual(testCase,tableHandle.specs(bioOptIx).controlKind,'readOnly');
verifyFalse(testCase,tableHandle.specs(bioOptIx).isConfigField);
verifyEqual(testCase,get(tableHandle.controls(bioOptIx),'Enable'), ...
    'inactive');
verifyEqual(testCase,get(tableHandle.controls(quantityVisIx),'Enable'), ...
    'inactive');
verifyEqual(testCase,get(tableHandle.controls(bioOptIx),'String'),'1');
verifyEqual(testCase,get(tableHandle.controls(quantityVisIx),'String'), ...
    'physicalDose');

savedBeamConfig = planWorkflow.gui.ParameterPanelRenderer.toConfig( ...
    beamConfig,tableHandle);
verifyFalse(testCase,isfield(savedBeamConfig,'bioOpt'));
verifyFalse(testCase,isfield(savedBeamConfig,'quantityVis'));
end

function testPrepareEditableContractComesFromSchema(testCase)
schemaSpecs = planWorkflow.config.WorkflowParameterSchema.prepareBeamSpecs();
guiSpecs = planWorkflow.gui.ParameterPanelSpecAdapter.fromSchema( ...
    schemaSpecs);

verifyEqual(testCase,{guiSpecs.field},{schemaSpecs.field});
verifyEqual(testCase,{guiSpecs.controlKind},{schemaSpecs.controlKind});
verifyTrue(testCase,any(strcmp( ...
    planWorkflow.config.StageConfigSchema.fields('prepare'), ...
    'quantityOpt')));
verifyFalse(testCase,any(strcmp( ...
    planWorkflow.config.StageConfigSchema.fields('prepare'), ...
    'bioOpt')));
verifyFalse(testCase,any(strcmp( ...
    planWorkflow.config.StageConfigSchema.fields('prepare'), ...
    'quantityVis')));
end

function testPrepareQuantityOptionsFollowBioModel(testCase)
physicalOptions = planWorkflow.gui.WorkflowParameterOptions.prepareBeamOptionSets( ...
    {'9F'},{'protons'},{'Generic'},{'none'});
rbexdOptions = planWorkflow.gui.WorkflowParameterOptions.prepareBeamOptionSets( ...
    {'9F'},{'protons'},{'Generic'},{'constRBE'});

verifyEqual(testCase,physicalOptions.quantityOpt,{'physicalDose'});
verifyEqual(testCase,rbexdOptions.quantityOpt,{'RBExDose'});
end

function testAnalysisEndpointsFileIsPopup(testCase)
fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
analysis = planWorkflow.config.Analysis.defaults();
runConfig = struct('analysis',analysis,'quantityOpt','physicalDose');

tableHandle = planWorkflow.gui.panels.AnalysisPanel.create( ...
    fig,[0 0 1 1],analysis,struct(),runConfig,struct());
fields = {tableHandle.specs.field};
endpointsFileIx = find(strcmp(fields,'endpointsFile'),1);

verifyEqual(testCase,get(tableHandle.controls(endpointsFileIx),'Style'), ...
    'popupmenu');
end

function testAnalysisPanelSyncsFigureSliceControl(testCase)
fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
analysis = planWorkflow.config.Analysis.defaults();
runConfig = struct('analysis',analysis,'quantityOpt','physicalDose');

tableHandle = planWorkflow.gui.panels.AnalysisPanel.create( ...
    fig,[0 0 1 1],analysis,struct(),runConfig,struct());
planWorkflow.gui.panels.AnalysisPanel.load(tableHandle,analysis, ...
    struct(),runConfig);

sliceControl = planWorkflow.gui.ParameterPanelRenderer.control( ...
    tableHandle,'figuresSliceControl');
set(sliceControl,'Value',true);
syncedAnalysis = planWorkflow.gui.panels.AnalysisPanel.sync( ...
    tableHandle,analysis);

verifyTrue(testCase,syncedAnalysis.figures.sliceControl);
verifyFalse(testCase,isfield(syncedAnalysis,'figuresSliceControl'));
end

function testStageParameterControllerExposesAnalysisControlsForUnlock(testCase)
fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
runConfig = workflow.runConfig;
template = struct('structures',struct('name','CTV','role','TARGET'), ...
    'rings',[]);
parents = struct( ...
    'dosePulling',uipanel('Parent',fig), ...
    'optimize',uipanel('Parent',fig), ...
    'sampling',uipanel('Parent',fig), ...
    'analysis',uipanel('Parent',fig));
controller = planWorkflow.gui.StageParameterPanelController.create( ...
    parents,runConfig,template,@(~) [],@(~,~) []);

allControls = controller.controls();
analysisControls = controller.analysisControls();

verifyNotEmpty(testCase,analysisControls);
verifyLessThan(testCase,numel(analysisControls),numel(allControls));
for i = 1:numel(analysisControls)
    verifyTrue(testCase,any(analysisControls(i) == allControls));
end
end

function testSelectionControlRequiresOptionSet(testCase)
fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
specs = planWorkflow.gui.ParameterPanelSpecAdapter.spec( ...
    'endpoint file','endpointsFile','char','', ...
    'selection');

verifyError(testCase,@() planWorkflow.gui.ParameterPanelRenderer.create( ...
    fig,[0 0 1 1],specs,struct(),struct(),struct()), ...
    'planWorkflow:gui:ParameterPanelRenderer:MissingOptionSet');
end

function testIncompatibleEndpointFileSelectionIsReportedButNotListed(testCase)
analysis = planWorkflow.config.Analysis.defaults();
analysis.endpointsFile = 'prostate.json';
runConfig = struct('analysis',analysis,'radiationMode','protons', ...
    'bioModel','constRBE');

[options,status] = ...
    planWorkflow.gui.WorkflowParameterOptions.endpointFileOptions( ...
    analysis,runConfig);

verifyFalse(testCase,any(strcmp(options.validValues,'prostate.json')));
verifyTrue(testCase,any(strcmp(options.values,'prostate.json')));
verifyTrue(testCase,contains(options.labels{1},'not valid'));
verifyFalse(testCase,status.isCompatible);
verifyTrue(testCase,contains(status.message,'RBExDose'));
end

function testIncompatibleEndpointFileIsPreservedUntilUserChangesIt(testCase)
fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
analysis = planWorkflow.config.Analysis.defaults();
analysis.endpointsFile = 'prostate.json';
runConfig = struct('analysis',analysis,'radiationMode','protons', ...
    'bioModel','constRBE');

tableHandle = planWorkflow.gui.panels.AnalysisPanel.create( ...
    fig,[0 0 1 1],analysis,struct(),runConfig,struct());
planWorkflow.gui.panels.AnalysisPanel.load(tableHandle,analysis, ...
    struct(),runConfig);
syncedAnalysis = planWorkflow.gui.panels.AnalysisPanel.sync( ...
    tableHandle,analysis);

verifyEqual(testCase,syncedAnalysis.endpointsFile,'prostate.json');

fields = {tableHandle.specs.field};
endpointIx = find(strcmp(fields,'endpointsFile'),1);
values = get(tableHandle.controls(endpointIx),'String');
verifyTrue(testCase,contains(values{get(tableHandle.controls(endpointIx), ...
    'Value')},'not valid'));
noneIx = find(strcmp(values,'none'),1);
set(tableHandle.controls(endpointIx),'Value',noneIx);
syncedAnalysis = planWorkflow.gui.panels.AnalysisPanel.sync( ...
    tableHandle,analysis);

verifyEmpty(testCase,syncedAnalysis.endpointsFile);
end

function testGuiCanChangeDoseResolution(testCase)
workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
runConfig = workflow.runConfig;
runConfig.doseResolution = [2 3 4];
baseKey = workflow.cacheKeyPublic('reference');
workflow.setEditorResponse(template,runConfig,true);

workflow.gui();

verifyEqual(testCase,workflow.runConfig.doseResolution,[2 3 4]);
verifyNotEqual(testCase,workflow.cacheKeyPublic('reference'),baseKey);
descriptor = workflow.cacheDescriptorPublic('reference',struct());
verifyEqual(testCase,descriptor.identity.doseCalculation.doseResolution, ...
    [2 3 4]);
end

function testGuiAfterPrepareIsReadOnly(testCase)
workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
runConfig = workflow.runConfig;
runConfig.plan_beams = '7F';
workflow.state.completedStages = {'prepared'};
workflow.setEditorResponse(template,runConfig,true);

workflow.gui();

verifyTrue(testCase,workflow.editorWasCalled);
verifyTrue(testCase,workflow.editorOptions.readOnly);
verifyEqual(testCase,workflow.runConfig.plan_beams,'9F');
end

function testGuiAfterPrepareRejectsConfigurationArguments(testCase)
workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
workflow.state.completedStages = {'prepared'};

verifyError(testCase,@() workflow.gui('plan_beams','7F'), ...
    'planWorkflow:WorkflowBase:GuiReadOnlyConfig');
end

function testGuiCanResumeFromSelectedStateFile(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
source = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
source.runConfig.plan_beams = '7F';
source.setEffectivePlanTemplatePublic(template);
source.state.completedStages = {'prepared','precomputed'};
source.state.currentStage = 'precomputed';
source.save();

workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
workflow.setEditorResponse(template,workflow.runConfig,true,[], ...
    source.stateFile);

workflow.gui();

verifyEqual(testCase,workflow.runConfig.plan_beams,'7F');
verifyTrue(testCase,any(strcmp(workflow.state.completedStages, ...
    'precomputed')));
verifyEqual(testCase,workflow.stateFile,source.stateFile);
end

function testGuiKeepsProgressReporterForWorkflowStages(testCase)
workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
reporter = planWorkflowTest.ProgressReporterProbe();
workflow.setEditorResponse(template,workflow.runConfig,true,reporter);

workflow.gui();

verifyEqual(testCase,workflow.guiProgressReporter,reporter);
end

function testGuiCanChangeWorkflowDosePullingConfig(testCase)
workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
runConfig = workflow.runConfig;
runConfig.dose_pulling1 = true;
runConfig.dose_pulling1_target = {'CTV','PTV'};
runConfig.dose_pulling1_criteria = {'COV1','D99'};
runConfig.dose_pulling1_limit = [0.90 0.95];
runConfig.dose_pulling1_start = 10;
runConfig.dose_pulling2 = true;
runConfig.dose_pulling2_target = {'PTV'};
workflow.setEditorResponse(template,runConfig,true);

workflow.gui();

verifyTrue(testCase,workflow.runConfig.dose_pulling1);
verifyEqual(testCase,workflow.runConfig.dose_pulling1_target,{'CTV','PTV'});
verifyEqual(testCase,workflow.runConfig.dose_pulling1_criteria, ...
    {'COV1','D99'});
verifyEqual(testCase,workflow.runConfig.dose_pulling1_limit,[0.90 0.95]);
verifyEqual(testCase,workflow.runConfig.dose_pulling1_start,10);
verifyTrue(testCase,workflow.runConfig.dose_pulling2);
verifyEqual(testCase,workflow.runConfig.dose_pulling2_target,{'PTV'});
end

function testDosePullingFieldsFollowChannelToggles(testCase)
commonFields = {'dose_pulling_max_iter','dose_pulling_strategy', ...
    'dose_pulling_search_schedule','dose_pulling_local_window', ...
    'dose_pulling_patience','dose_pulling_target_tol', ...
    'dose_pulling_selection_policy', ...
    'dose_pulling_max_vmax_percent','dose_pulling_use_warm_start'};
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.dosePullingVisibleFields( ...
    false,false), ...
    [{'dose_pulling1','dose_pulling2'},commonFields]);
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.dosePullingVisibleFields( ...
    true,false), ...
    {'dose_pulling1','dose_pulling1_target', ...
    'dose_pulling1_criteria','dose_pulling1_limit', ...
    'dose_pulling1_start','dose_pulling2', ...
    commonFields{:}});
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.dosePullingVisibleFields( ...
    false,true), ...
    {'dose_pulling1','dose_pulling2', ...
    'dose_pulling2_target','dose_pulling2_criteria', ...
    'dose_pulling2_limit','dose_pulling2_start',commonFields{:}});
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.dosePullingVisibleFields( ...
    false,false,'Threshold','normalizedKnee'), ...
    {'dose_pulling1','dose_pulling2','dose_pulling_max_iter', ...
    'dose_pulling_strategy'});
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.dosePullingVisibleFields( ...
    false,false,'heuristicMultiObjective','weightedSum'), ...
    [{'dose_pulling1','dose_pulling2'},commonFields(1:7), ...
    {'dose_pulling_target_weight','dose_pulling_oar_weight', ...
    'dose_pulling_step_weight'},commonFields(8:9)]);
end

function testDosePullingDropdownsAndVisibilityRefresh(testCase)
fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
panel = planWorkflow.gui.panels.DosePullingPanel.create( ...
    fig,[0 0 1 1],struct());
runConfig = dosePullingPanelRunConfig();

planWorkflow.gui.panels.DosePullingPanel.load(panel,runConfig);

strategyControl = planWorkflow.gui.ParameterPanelRenderer.control( ...
    panel,'dose_pulling_strategy');
scheduleControl = planWorkflow.gui.ParameterPanelRenderer.control( ...
    panel,'dose_pulling_search_schedule');
policyControl = planWorkflow.gui.ParameterPanelRenderer.control( ...
    panel,'dose_pulling_selection_policy');
verifyEqual(testCase,get(strategyControl,'Style'),'popupmenu');
verifyEqual(testCase,get(scheduleControl,'Style'),'popupmenu');
verifyEqual(testCase,get(policyControl,'Style'),'popupmenu');
verifyTrue(testCase,any(strcmp(get(strategyControl,'String'), ...
    'Threshold')));
verifyTrue(testCase,any(strcmp(get(policyControl,'String'), ...
    'weightedSum')));

policyValues = get(policyControl,'String');
set(policyControl,'Value',find(strcmp(policyValues,'weightedSum'),1));
planWorkflow.gui.panels.DosePullingPanel.refresh(panel);
visibleFields = planWorkflow.gui.ParameterPanelRenderer.visibleFields(panel);
verifyTrue(testCase,any(strcmp(visibleFields, ...
    'dose_pulling_target_weight')));
verifyTrue(testCase,any(strcmp(visibleFields, ...
    'dose_pulling_oar_weight')));
verifyTrue(testCase,any(strcmp(visibleFields, ...
    'dose_pulling_step_weight')));

strategyValues = get(strategyControl,'String');
set(strategyControl,'Value',find(strcmp(strategyValues,'Threshold'),1));
planWorkflow.gui.panels.DosePullingPanel.refresh(panel);
visibleFields = planWorkflow.gui.ParameterPanelRenderer.visibleFields(panel);
verifyFalse(testCase,any(strcmp(visibleFields, ...
    'dose_pulling_search_schedule')));
verifyFalse(testCase,any(strcmp(visibleFields, ...
    'dose_pulling_selection_policy')));
verifyFalse(testCase,any(strcmp(visibleFields, ...
    'dose_pulling_target_weight')));
end

function testDosePullingFieldsHaveHelpText(testCase)
specs = planWorkflow.gui.panels.DosePullingPanel.specs();
fields = {specs.field};
doseFields = fields(startsWith(fields,'dose_pulling'));
for fieldIx = 1:numel(doseFields)
    specIx = find(strcmp(fields,doseFields{fieldIx}),1);
    verifyNotEmpty(testCase,strtrim(specs(specIx).helpText), ...
        sprintf('Missing help text for %s.',doseFields{fieldIx}));
end
end

function testSamplingFieldsFollowOptimizationLinkToggle(testCase)
linkedFields = planWorkflow.config.WorkflowParameterSchema.samplingParameterFields( ...
    true,'impScen_permuted5_truncated');
unlinkedFields = planWorkflow.config.WorkflowParameterSchema.samplingParameterFields( ...
    false,'impScen_permuted5_truncated');

verifyTrue(testCase,any(strcmp(linkedFields, ...
    'sampling_linkToOptimization')));
verifyFalse(testCase,any(strcmp(linkedFields,'sampling_caseID')));
verifyFalse(testCase,any(strcmp(linkedFields, ...
    'sampling_AcquisitionType')));
verifyTrue(testCase,any(strcmp(linkedFields,'sampling_scen_mode')));
verifyTrue(testCase,any(strcmp(linkedFields,'sampling_ctActive')));
verifyFalse(testCase,any(strcmp(linkedFields,'sampling_ctReferenceScenId')));
verifyTrue(testCase,any(strcmp(linkedFields,'sampling_ctScenProb')));
verifyTrue(testCase,any(strcmp(linkedFields,'sampling_wcSigma')));
verifyTrue(testCase,any(strcmp(linkedFields,'sampling_setupActive')));
verifyTrue(testCase,any(strcmp(linkedFields,'sampling_rangeActive')));
verifyTrue(testCase,any(strcmp(linkedFields,'sampling_shiftSD')));
verifyFalse(testCase,any(strcmp(linkedFields,'sampling_rangeAbsSD')));
verifyFalse(testCase,any(strcmp(linkedFields,'sampling_rangeRelSD')));
verifyTrue(testCase,any(strcmp(unlinkedFields,'sampling_caseID')));
verifyTrue(testCase,any(strcmp(unlinkedFields, ...
    'sampling_AcquisitionType')));
end

function testHlutFileOptionsIncludeMatRadDefault(testCase)
hlutFileNames = ...
    planWorkflow.gui.WorkflowParameterOptions.availableHlutFileNames();

verifyTrue(testCase,any(strcmp(hlutFileNames,'matRad_default.hlut')));
end

function testPrecomputeRobustnessFieldsFollowMatRadAssociations(testCase)
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'STOCH','nomScen'), ...
    {'label','robustness','variantSummary','scen_mode','ctActive', ...
    'ctScenProb'});
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'COWC','nomScen'), ...
    {'label','robustness','variantSummary','scen_mode','ctActive', ...
    'ctScenProb'});
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'c-COWC','nomScen'), ...
    {'label','robustness','variantSummary','p1','p2','scen_mode', ...
    'ctActive','ctScenProb'});
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'INTERVAL2','nomScen'), ...
    {'label','robustness','variantSummary','theta1','radiusMode', ...
    'useScenarioBatch','SecondPassStrategy','KeepCache','CacheRoot', ...
    'scen_mode','ctActive','ctScenProb'});
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'INTERVAL3','nomScen'), ...
    {'label','robustness','variantSummary','theta1','theta2', ...
    'radiusMode','KMode','kmax','retentionThreshold','useScenarioBatch', ...
    'SecondPassStrategy','KeepCache','CacheRoot','scen_mode', ...
    'ctActive','ctScenProb'});
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'INTERVAL3','nomScen',struct(),'static'), ...
    {'label','robustness','variantSummary','theta1','theta2', ...
    'radiusMode','KMode','kmax','useScenarioBatch','SecondPassStrategy', ...
    'KeepCache','CacheRoot','scen_mode','ctActive','ctScenProb'});
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'INTERVAL3','nomScen',struct(),'dynamic','extreme'), ...
    {'label','robustness','variantSummary','theta1','theta2', ...
    'radiusMode','useScenarioBatch','SecondPassStrategy','KeepCache', ...
    'CacheRoot','scen_mode','ctActive','ctScenProb'});
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'PROB2','nomScen'), ...
    {'label','robustness','variantSummary','useScenarioBatch', ...
    'SecondPassStrategy','KeepCache','CacheRoot','scen_mode', ...
    'ctActive','ctScenProb'});
end

function testHiddenRobustVariantFieldsAreCleanedByPanelAdapter(testCase)
config = struct();
config.id = 'robust_1';
config.label = 'Interval 2';
config.objectiveSetName = 'robust_1';
config.robustness = 'INTERVAL2';
config.scen_mode = 'wcScen';
config.ctActive = true;
config.setupActive = true;
config.rangeActive = false;
config.gantryActive = false;
config.couchActive = false;
config.shiftSD = [5 10 5];
config.wcSigma = 1;
config.theta1 = 5;
config.theta2 = 9;
config.p1 = 1;
config.p2 = 2;

plan = planWorkflow.config.RobustPlanPanelAdapter.planFromPanelConfig( ...
    config);

verifyEqual(testCase,plan.robustnessMode,'INTERVAL2');
verifyEqual(testCase,plan.variants.theta1,5);
verifyFalse(testCase,isfield(plan.variants,'theta2'));
verifyFalse(testCase,isfield(plan.variants,'p1'));
verifyFalse(testCase,isfield(plan.variants,'p2'));
end

function testDosePrecomputeRoundTripThroughPanelAdapter(testCase)
cacheRoot = fullfile(tempdir,'planWorkflow_interval_cache');
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = 'interval3';
plan.label = 'Interval 3';
plan.objectiveSetName = 'interval3';
plan.robustnessMode = 'INTERVAL3';
plan.dosePrecompute.useScenarioBatch = true;
plan.dosePrecompute.SecondPassStrategy = 'recompute';
plan.dosePrecompute.KeepCache = true;
plan.dosePrecompute.CacheRoot = cacheRoot;

panelConfig = planWorkflow.config.RobustPlanPanelAdapter.planPanelConfig( ...
    plan);
roundTripPlan = ...
    planWorkflow.config.RobustPlanPanelAdapter.planFromPanelConfig( ...
    panelConfig);

verifyTrue(testCase,panelConfig.useScenarioBatch);
verifyEqual(testCase,panelConfig.SecondPassStrategy,'recompute');
verifyTrue(testCase,panelConfig.KeepCache);
verifyEqual(testCase,panelConfig.CacheRoot,cacheRoot);
verifyEqual(testCase,roundTripPlan.dosePrecompute,plan.dosePrecompute);
end

function testReferenceDosePrecomputeRoundTripThroughPanelAdapter(testCase)
cacheRoot = fullfile(tempdir,'planWorkflow_prob_cache');
runConfig = baseRunConfig();
runConfig.precompute.reference.robustnessMode = 'PROB2';
runConfig.precompute.reference.dosePrecompute.useScenarioBatch = true;
runConfig.precompute.reference.dosePrecompute.SecondPassStrategy = 'disk';
runConfig.precompute.reference.dosePrecompute.KeepCache = true;
runConfig.precompute.reference.dosePrecompute.CacheRoot = cacheRoot;

panelConfig = ...
    planWorkflow.config.RobustPlanPanelAdapter.referencePanelConfig( ...
    runConfig);
runConfigOut = ...
    planWorkflow.config.RobustPlanPanelAdapter.applyReferencePanelConfig( ...
    baseRunConfig(),panelConfig);

verifyTrue(testCase,panelConfig.reference_useScenarioBatch);
verifyEqual(testCase,panelConfig.reference_CacheRoot,cacheRoot);
verifyEqual(testCase, ...
    runConfigOut.precompute.reference.dosePrecompute, ...
    runConfig.precompute.reference.dosePrecompute);
end

function testPrecomputeReferenceRobustnessFieldsUseReferencePrefix(testCase)
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.precomputeReferenceParameterFields( ...
    'INTERVAL3','nomScen'), ...
    {'reference_label','reference_robustness','reference_theta1', ...
    'reference_theta2','reference_radiusMode','reference_KMode', ...
    'reference_kmax', ...
    'reference_retentionThreshold','reference_useScenarioBatch', ...
    'reference_SecondPassStrategy','reference_KeepCache', ...
    'reference_CacheRoot','reference_scen_mode', ...
    'reference_ctActive','reference_ctScenProb'});
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.precomputeReferenceParameterFields( ...
    'INTERVAL3','nomScen',struct(),'static'), ...
    {'reference_label','reference_robustness','reference_theta1', ...
    'reference_theta2','reference_radiusMode','reference_KMode', ...
    'reference_kmax', ...
    'reference_useScenarioBatch','reference_SecondPassStrategy', ...
    'reference_KeepCache','reference_CacheRoot', ...
    'reference_scen_mode','reference_ctActive','reference_ctScenProb'});
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.precomputeReferenceParameterFields( ...
    'INTERVAL3','nomScen',struct(),'dynamic','extreme'), ...
    {'reference_label','reference_robustness','reference_theta1', ...
    'reference_theta2','reference_radiusMode','reference_useScenarioBatch', ...
    'reference_SecondPassStrategy','reference_KeepCache', ...
    'reference_CacheRoot','reference_scen_mode','reference_ctActive', ...
    'reference_ctScenProb'});
end

function testParameterPanelSectionFieldsAreNotConfigFields(testCase)
dimensionConfig = struct('ctActive',true,'setupActive',true, ...
    'rangeActive',true);
sectionFields = {'patientSection','imagesSection', ...
    'doseCalculationSection','robustnessSection', ...
    'robustnessParameterSection','dosePrecomputeSection', ...
    'scenarioModeSection','scenarioSelectionSection', ...
    'scenarioParameterSection','cacheSection'};

parameterFields = ...
    planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'INTERVAL3','wcScen',dimensionConfig);
samplingParameterFields = ...
    planWorkflow.config.WorkflowParameterSchema.samplingParameterFields( ...
    true,'wcScen',dimensionConfig);

for i = 1:numel(sectionFields)
    verifyFalse(testCase,any(strcmp(parameterFields,sectionFields{i})));
    verifyFalse(testCase,any(strcmp(samplingParameterFields, ...
        sectionFields{i})));
end
end

function testPrecomputeVisibleFieldsAreSplitByPlanSurface(testCase)
dimensionConfig = struct('ctActive',true,'setupActive',true, ...
    'rangeActive',true);

verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.precomputeTransversalParameterFields(), ...
    {'bixelWidth','doseResolution','useCache','writeCache'});
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.precomputeReferenceParameterFields(), ...
    {'reference_label','reference_robustness','reference_scen_mode', ...
    'reference_ctActive','reference_ctScenProb'});

robustFields = planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'INTERVAL3','wcScen',dimensionConfig);
verifyEqual(testCase,robustFields{1},'label');
verifyTrue(testCase,any(strcmp(robustFields,'robustness')));
verifyTrue(testCase,any(strcmp(robustFields,'theta1')));
verifyTrue(testCase,any(strcmp(robustFields,'theta2')));
verifyTrue(testCase,any(strcmp(robustFields,'scen_mode')));
verifyTrue(testCase,any(strcmp(robustFields,'shiftSD')));
verifyTrue(testCase,any(strcmp(robustFields,'rangeAbsSD')));
verifyFalse(testCase,any(strcmp(robustFields,'doseResolution')));
verifyFalse(testCase,any(strcmp(robustFields,'useCache')));
verifyFalse(testCase,any(strcmp(robustFields,'writeCache')));
end

function testPrecomputeVisibleFieldsExposeRobustPlansForMacros(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
runConfig = planWorkflow.gui.PlanEditorContract.alignRobustPlansWithTemplate( ...
    baseRunConfig(),template);

fields = planWorkflow.config.WorkflowParameterSchema.precomputeExportFields( ...
    runConfig);

verifyTrue(testCase,any(strcmp(fields,'robustPlans')));
verifyFalse(testCase,any(strcmp(fields,'robust_scen_mode')));
end

function testRobustPlansAlignWithObjectiveTabs(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
objectiveSetName = firstRobustObjectiveSetName(template);
robustObjectiveSets = ...
    planWorkflow.templates.PlanTemplate.robustObjectiveSets(template);
secondPlan = robustObjectiveSets(1);
secondPlan.id = 'robust_2';
secondPlan.label = 'Robust 2';
template.objectiveSets.robustPlans = [robustObjectiveSets secondPlan];
runConfig = baseRunConfig();
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = objectiveSetName;
plan.label = 'Robust 1';
plan.objectiveSetName = objectiveSetName;
plan.robustnessMode = 'INTERVAL2';
plan.variants = [struct('id','theta_low','label','Theta low', ...
    'theta1',0.95) struct('id','theta_high','label','Theta high', ...
    'theta1',1.05)];
runConfig.precompute.robustPlans = ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(plan);

runConfig = planWorkflow.gui.PlanEditorContract.alignRobustPlansWithTemplate( ...
    runConfig,template);

robustPlans = runConfig.precompute.robustPlans;
verifyEqual(testCase,numel(robustPlans),2);
verifyEqual(testCase,{robustPlans.objectiveSetName}, ...
    {objectiveSetName,'robust_2'});
verifyEqual(testCase,{robustPlans.label}, ...
    {'Robust 1','Robust 2'});
verifyEqual(testCase,robustPlans(1).variants(1).theta1,0.95);
verifyEqual(testCase,robustPlans(2).robustnessMode,'INTERVAL2');
verifyEqual(testCase,numel(robustPlans(2).variants),1);
verifyTrue(testCase,isfield(robustPlans(2).variants,'theta1'));
end

function testTemplateSelectionResetsRobustPlansToSelectedTemplate(testCase)
runConfig = baseRunConfig();
runConfig.plan_template = 'COWC_001';
cowcTemplate = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','COWC_001');
runConfig = planWorkflow.gui.PlanEditorContract.alignPrecomputeWithTemplate( ...
    runConfig,cowcTemplate);

patch = planWorkflow.gui.panels.PrepareTemplateSelection.selectTemplate( ...
    runConfig,{'COWC_001','PROB2_001'},2,false);

robustPlans = patch.runConfig.precompute.robustPlans;
verifyEqual(testCase,numel(robustPlans),1);
verifyEqual(testCase,robustPlans(1).id,'MeanVariance');
verifyEqual(testCase,robustPlans(1).objectiveSetName,'MeanVariance');
verifyEqual(testCase,robustPlans(1).robustnessMode,'PROB2');
end

function testTemplateSelectionRegeneratesComparisonRobustPlans(testCase)
runConfig = baseRunConfig();
runConfig.plan_template = 'COWC_001';
cowcTemplate = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','COWC_001');
runConfig = planWorkflow.gui.PlanEditorContract.alignPrecomputeWithTemplate( ...
    runConfig,cowcTemplate);

patch = planWorkflow.gui.panels.PrepareTemplateSelection.selectTemplate( ...
    runConfig,{'COWC_001','comparison_001'},2,false);

robustPlans = patch.runConfig.precompute.robustPlans;
robustObjectiveSets = ...
    planWorkflow.templates.PlanTemplate.robustObjectiveSets( ...
    patch.template);
verifyEqual(testCase,{robustPlans.id},{robustObjectiveSets.id});
verifyEqual(testCase,{robustPlans.objectiveSetName}, ...
    {robustObjectiveSets.id});
verifyEqual(testCase,{robustPlans.label},{robustObjectiveSets.label});
end

function testRobustPlanAlignmentRejectsPositionalFallback(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
runConfig = baseRunConfig();
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = 'legacy_plan';
plan.label = 'Legacy plan';
plan.objectiveSetName = 'legacy_objectives';
plan.robustnessMode = 'INTERVAL2';
plan.variants = struct('id','theta_5','label','theta1=5', ...
    'theta1',5);
runConfig.precompute.robustPlans = ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(plan);

verifyError(testCase,@() ...
    planWorkflow.gui.PlanEditorContract.alignRobustPlansWithTemplate( ...
    runConfig,template), ...
    ['planWorkflow:config:WorkflowContractValidator:' ...
     'UnmatchedRobustPlan']);
end

function testObjectiveTabsRebuildWhenTemplatePlanSetChanges(testCase)
verifyFalse(testCase, ...
    planWorkflow.gui.PlanEditorContract.objectiveSetTabsNeedRebuild( ...
    {'reference','robust_1'}, ...
    {'reference','robust_1'}));
verifyFalse(testCase, ...
    planWorkflow.gui.PlanEditorContract.objectiveSetTabsNeedRebuild( ...
    {'robust_1','reference'}, ...
    {'reference','robust_1'}));
verifyTrue(testCase, ...
    planWorkflow.gui.PlanEditorContract.objectiveSetTabsNeedRebuild( ...
    {'reference','robust_1','robust_2'}, ...
    {'reference','robust_1'}));
verifyTrue(testCase, ...
    planWorkflow.gui.PlanEditorContract.objectiveSetTabsNeedRebuild( ...
    {'reference','robust_1'}, ...
    {'reference','robust_1','robust_2'}));
verifyTrue(testCase, ...
    planWorkflow.gui.PlanEditorContract.objectiveSetTabsNeedRebuild( ...
    {'reference','robust_1'}, ...
    {'reference','robust_2'}));
end

function testRobustPlanLabelCanBeDefinedByMacro(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
objectiveSetName = firstRobustObjectiveSetName(template);
runConfig = baseRunConfig();
runConfig.precompute.robustPlans = struct('id',objectiveSetName, ...
    'objectiveSetName',objectiveSetName, ...
    'label','  Interval 2 target plan  ', ...
    'scenario',planWorkflow.config.RobustPlanConfig.defaultScenario( ...
    'wcScen'), ...
    'variants',struct('id','theta_1','label','Theta 1','theta1',1));

runConfig = planWorkflow.gui.PlanEditorContract.alignRobustPlansWithTemplate( ...
    runConfig,template);
template = planWorkflow.gui.PlanEditorContract.syncRobustObjectiveSetLabels( ...
    template,runConfig);
labels = planWorkflow.gui.PlanEditorContract.objectiveSetLabelsForRunConfig( ...
    template,runConfig);

verifyEqual(testCase,labels{2},'Interval 2 target plan');
verifyEqual(testCase,template.objectiveSets.robustPlans(1).id, ...
    objectiveSetName);
verifyEqual(testCase,template.objectiveSets.robustPlans(1).label, ...
    'Interval 2 target plan');
verifyEqual(testCase,runConfig.precompute.robustPlans(1).objectiveSetName, ...
    objectiveSetName);
verifyEqual(testCase,runConfig.precompute.robustPlans(1).label, ...
    'Interval 2 target plan');
verifyError(testCase,@() ...
    planWorkflow.gui.PlanEditorContract.normalizeRobustPlanLabel('   '), ...
    'planWorkflow:config:WorkflowContractValidator:InvalidPlanLabel');
end

function testReferencePlanLabelRendersInReferenceTabTitle(testCase)
runConfig = baseRunConfig();
runConfig.precompute.reference.label = '  Nominal reference  ';

runConfig = planWorkflow.gui.PlanEditorContract.ensureReferencePlanLabel( ...
    runConfig);

verifyEqual(testCase,runConfig.precompute.reference.label, ...
    'Nominal reference');
verifyEqual(testCase, ...
    planWorkflow.gui.panels.PrecomputePanel.referencePlanTabTitle( ...
    runConfig.precompute.reference.label), ...
    'Reference (Nominal reference)');
verifyEqual(testCase, ...
    planWorkflow.gui.panels.PrecomputePanel.referencePlanTabTitle('   '), ...
    'Reference');

template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
labels = planWorkflow.gui.PlanEditorContract.objectiveSetLabelsForRunConfig( ...
    template,runConfig);

verifyEqual(testCase,labels{1},'Reference (Nominal reference)');
end

function testParameterPanelScrollOffsetKeepsShortPanelsInPlace(testCase)
verifyEqual(testCase, ...
    planWorkflow.gui.PanelScroller.scrollOffset(0,1),0);
verifyEqual(testCase, ...
    planWorkflow.gui.PanelScroller.scrollOffset(-0.2,1),0);
verifyEqual(testCase, ...
    planWorkflow.gui.PanelScroller.scrollOffset(0.5,0.5),0);
verifyEqual(testCase, ...
    planWorkflow.gui.PanelScroller.scrollOffset(0.5,0),0.5);
verifyEqual(testCase, ...
    planWorkflow.gui.PanelScroller.scrollOffset(0.5,1),0);
end

function testPanelScrollerPreservesOffsetAcrossReconfigure(testCase)
fig = figure('Visible','off');
cleanupFig = onCleanup(@() close(fig));
panel = uipanel('Parent',fig,'Units','normalized', ...
    'Position',[0 0 1 1]);
label = uicontrol('Parent',panel,'Style','text', ...
    'Units','normalized','Position',[0.02 0.9 0.4 0.04]);
slider = planWorkflow.gui.PanelScroller.createSlider(panel);

planWorkflow.gui.PanelScroller.configure(slider,label,-0.5);
set(slider,'Value',0.2);
planWorkflow.gui.PanelScroller.scroll(slider);
previousOffset = planWorkflow.gui.PanelScroller.currentOffset(slider);

set(label,'Position',[0.02 0.9 0.4 0.04]);
planWorkflow.gui.PanelScroller.configure(slider,label,-0.7,true);

verifyEqual(testCase, ...
    planWorkflow.gui.PanelScroller.currentOffset(slider), ...
    previousOffset,'AbsTol',1e-12);
end

function testParameterPanelWheelSliderValueIsClamped(testCase)
verifyEqual(testCase, ...
    planWorkflow.gui.PanelScroller.wheelSliderValue(0,1,1),0);
verifyEqual(testCase, ...
    planWorkflow.gui.PanelScroller.wheelSliderValue(0.5,0.5,1), ...
    0.4375,'AbsTol',1e-12);
verifyEqual(testCase, ...
    planWorkflow.gui.PanelScroller.wheelSliderValue(0.5,0,1),0);
verifyEqual(testCase, ...
    planWorkflow.gui.PanelScroller.wheelSliderValue(0.5,0.5,-1), ...
    0.5,'AbsTol',1e-12);
verifyEqual(testCase, ...
    planWorkflow.gui.PanelScroller.wheelSliderValue(0.5,2,0), ...
    0.5,'AbsTol',1e-12);
end

function testCtReferenceVisibleWhenCtInactive(testCase)
ctInactive = struct('ctActive',false,'ctReferenceScenId',2, ...
    'setupActive',true,'rangeActive',false);

fields = planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'COWC','nomScen',ctInactive);

verifyTrue(testCase,any(strcmp(fields,'ctActive')));
verifyTrue(testCase,any(strcmp(fields,'ctReferenceScenId')));
verifyFalse(testCase,any(strcmp(fields,'ctScenProb')));
end

function testCtScenarioProbabilitiesVisibleWhenCtActive(testCase)
ctActive = struct('ctActive',true,'ctReferenceScenId',1, ...
    'setupActive',true,'rangeActive',false);

fields = planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'COWC','nomScen',ctActive);

verifyTrue(testCase,any(strcmp(fields,'ctActive')));
verifyTrue(testCase,any(strcmp(fields,'ctScenProb')));
verifyFalse(testCase,any(strcmp(fields,'ctReferenceScenId')));
end

function testScenarioDimensionFieldsControlVisibleScales(testCase)
setupOnly = struct('setupActive',true,'rangeActive',false, ...
    'gantryActive',false,'couchActive',false);
rangeEnabled = struct('setupActive',true,'rangeActive',true, ...
    'gantryActive',false,'couchActive',false);
angleEnabled = struct('setupActive',true,'rangeActive',false, ...
    'gantryActive',true,'couchActive',true);
noneEnabled = struct('setupActive',false,'rangeActive',false, ...
    'gantryActive',false,'couchActive',false);

setupFields = planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'COWC','wcScen',setupOnly);
rangeFields = planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'COWC','wcScen',rangeEnabled);
noneFields = planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'COWC','wcScen',noneEnabled);

verifyTrue(testCase,any(strcmp(setupFields,'setupActive')));
verifyTrue(testCase,any(strcmp(setupFields,'rangeActive')));
verifyFalse(testCase,any(strcmp(setupFields,'gantryActive')));
verifyFalse(testCase,any(strcmp(setupFields,'couchActive')));
verifyTrue(testCase,any(strcmp(setupFields,'shiftSD')));
verifyTrue(testCase,any(strcmp(setupFields,'wcSigma')));
verifyFalse(testCase,any(strcmp(setupFields,'rangeAbsSD')));
verifyFalse(testCase,any(strcmp(setupFields,'gantryAngleSD')));
verifyFalse(testCase,any(strcmp(setupFields,'numOfRangeGridPoints')));
assertFieldBefore(testCase,setupFields,'ctActive','setupActive');
assertFieldBefore(testCase,setupFields,'setupActive','rangeActive');
assertFieldBefore(testCase,setupFields,'rangeActive','shiftSD');

verifyTrue(testCase,any(strcmp(rangeFields,'rangeAbsSD')));
verifyTrue(testCase,any(strcmp(rangeFields,'rangeRelSD')));
verifyTrue(testCase,any(strcmp(rangeFields,'numOfRangeGridPoints')));
assertFieldBefore(testCase,rangeFields,'ctActive','setupActive');
assertFieldBefore(testCase,rangeFields,'setupActive','rangeActive');
assertFieldBefore(testCase,rangeFields,'rangeActive','rangeAbsSD');
assertFieldBefore(testCase,rangeFields,'rangeActive','shiftSD');
assertFieldBefore(testCase,rangeFields,'shiftSD','rangeAbsSD');
assertFieldBefore(testCase,rangeFields,'rangeAbsSD','rangeRelSD');
assertFieldBefore(testCase,rangeFields,'rangeRelSD','wcSigma');
assertFieldBefore(testCase,rangeFields,'wcSigma','numOfRangeGridPoints');

verifyTrue(testCase,any(strcmp(noneFields,'setupActive')));
verifyFalse(testCase,any(strcmp(noneFields,'shiftSD')));
verifyFalse(testCase,any(strcmp(noneFields,'wcSigma')));

randomFields = planWorkflow.config.WorkflowParameterSchema.precomputeRobustParameterFields( ...
    'COWC','random',angleEnabled);
verifyTrue(testCase,any(strcmp(randomFields,'gantryActive')));
verifyTrue(testCase,any(strcmp(randomFields,'couchActive')));
verifyTrue(testCase,any(strcmp(randomFields,'gantryAngleSD')));
verifyTrue(testCase,any(strcmp(randomFields,'couchAngleSD')));
verifyTrue(testCase,any(strcmp(randomFields,'randomSeed')));
assertFieldBefore(testCase,randomFields,'rangeActive','gantryActive');
assertFieldBefore(testCase,randomFields,'gantryActive','couchActive');
assertFieldBefore(testCase,randomFields,'couchActive','shiftSD');
assertFieldBefore(testCase,randomFields,'shiftSD','gantryAngleSD');
assertFieldBefore(testCase,randomFields,'gantryAngleSD','couchAngleSD');
assertFieldBefore(testCase,randomFields,'random_size','randomSeed');

samplingFields = planWorkflow.config.WorkflowParameterSchema.samplingParameterFields( ...
    true,'wcScen',rangeEnabled);
assertFieldBefore(testCase,samplingFields,'sampling_ctActive','sampling_setupActive');
assertFieldBefore(testCase,samplingFields,'sampling_setupActive','sampling_rangeActive');
assertFieldBefore(testCase,samplingFields,'sampling_rangeActive','sampling_shiftSD');
assertFieldBefore(testCase,samplingFields,'sampling_rangeRelSD','sampling_wcSigma');
end

function testSupportedScenarioModesOnlyExposePermutedTruncated(testCase)
values = planWorkflow.matRadCapabilitiesReader.supportedScenarioModes();

verifyTrue(testCase,any(strcmp(values,'impScen_permuted5_truncated')));
verifyTrue(testCase,any(strcmp(values,'impScen_permuted7_truncated')));
verifyFalse(testCase,any(strcmp(values,'impScen_truncated')));
verifyFalse(testCase,any(strcmp(values,'impScen5_truncated')));
verifyFalse(testCase,any(strcmp(values,'impScen7_truncated')));
end

function testSupportedRobustnessModesDoNotExposeLegacyAliases(testCase)
values = planWorkflow.matRadCapabilitiesReader.supportedWorkflowRobustnessModes();

verifyTrue(testCase,any(strcmp(values,'INTERVAL2')));
verifyTrue(testCase,any(strcmp(values,'INTERVAL3')));
verifyTrue(testCase,any(strcmp(values,'PROB2')));
verifyFalse(testCase,any(strcmp(values,'STOCH2')));
verifyFalse(testCase,any(strcmp(values,'COWC2')));
verifyFalse(testCase,any(strcmp(values,'c-COWC2')));
verifyFalse(testCase,any(strcmp(values,'INTERVAL1')));
end

function testSupportedRadiationModesUseCanonicalCarbonName(testCase)
values = planWorkflow.matRadCapabilitiesReader.supportedRadiationModes();

verifyTrue(testCase,any(strcmp(values,'carbon')));
verifyFalse(testCase,any(strcmp(values,'carbons')));
end

function testAnalysisRobustnessTargetOptionsUseTemplateStructures(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');

targetOptions = ...
    planWorkflow.gui.WorkflowParameterOptions.analysisRobustnessTargetOptions( ...
    template,{'CUSTOM'});

verifyTrue(testCase,any(strcmp(targetOptions,'CTV')));
verifyTrue(testCase,any(strcmp(targetOptions,'PTV')));
verifyFalse(testCase,any(strcmp(targetOptions,'BLADDER')));
verifyFalse(testCase,any(strcmp(targetOptions,'RING 0 - 20 mm')));
verifyFalse(testCase,any(strcmp(targetOptions,'CUSTOM')));
end

function testAnalysisRobustnessTargetOptionsFollowStructureRoles(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
data = planWorkflow.gui.TemplateStructureTableAdapter.toTable(template);
bladderRow = find(strcmp(data(:,2),'BLADDER'),1);
ctvRow = find(strcmp(data(:,2),'CTV'),1);
data{bladderRow,3} = 'TARGET';
data{ctvRow,3} = 'OAR';

template = planWorkflow.gui.TemplateStructureTableAdapter.applyTable( ...
    template,data);
targetOptions = ...
    planWorkflow.gui.WorkflowParameterOptions.analysisRobustnessTargetOptions( ...
    template,[]);

verifyTrue(testCase,any(strcmp(targetOptions,'BLADDER')));
verifyFalse(testCase,any(strcmp(targetOptions,'CTV')));
end

function testAnalysisRobustnessTargetsHiddenForAllMode(testCase)
allFields = planWorkflow.config.WorkflowParameterSchema.analysisVisibleFields('all');
includeFields = ...
    planWorkflow.config.WorkflowParameterSchema.analysisVisibleFields('include');

verifyFalse(testCase,any(strcmp(allFields,'robustnessTargets')));
verifyTrue(testCase,any(strcmp(includeFields,'robustnessTargets')));
verifyTrue(testCase,any(strcmp(allFields,'doseWindowExpectedDoseDifference')));
verifyTrue(testCase,any(strcmp(allFields,'figuresSliceControl')));
verifyFalse(testCase,any(strcmp(allFields,'doseWindowUvh')));
end

function testMultiSelectParameterControlIsTall(testCase)
verifyGreaterThan(testCase, ...
    planWorkflow.gui.ParameterPanelLayout.controlHeightForType( ...
    'multiSelect'), ...
    planWorkflow.gui.ParameterPanelLayout.controlHeightForType('char'));
verifyGreaterThanOrEqual(testCase, ...
    planWorkflow.gui.ParameterPanelLayout.controlHeight(),0.05);
verifyGreaterThan(testCase, ...
    planWorkflow.gui.ParameterPanelLayout.baseRowStride(), ...
    planWorkflow.gui.ParameterPanelLayout.controlHeight());
end

function testSectionRowsHaveDedicatedSpacing(testCase)
verifyGreaterThanOrEqual(testCase, ...
    planWorkflow.gui.ParameterPanelLayout.controlHeightForType( ...
    'section'),0.05);
verifyGreaterThan(testCase, ...
    planWorkflow.gui.ParameterPanelLayout.sectionRowStride(), ...
    planWorkflow.gui.ParameterPanelLayout.controlHeightForType( ...
    'section'));
end

function testHelpTextFontSizeIsSmall(testCase)
verifyGreaterThan(testCase, ...
    planWorkflow.gui.TextLayout.helpTextFontSize(),0);
verifyLessThan(testCase, ...
    planWorkflow.gui.TextLayout.helpTextFontSize(),8);
end

function testHelpTextWrapsWithinParameterColumn(testCase)
longText = ['This help text is intentionally long enough to require ' ...
    'multiple display lines in the parameter panel.'];
wrappedText = planWorkflow.gui.TextLayout.helpTextForDisplay( ...
    longText,planWorkflow.gui.TextLayout.parameterHelpTextWrapColumn());
lines = regexp(wrappedText,sprintf('\n'),'split');

verifyTrue(testCase,contains(wrappedText,sprintf('\n')));
verifyLessThanOrEqual(testCase, ...
    max(cellfun(@numel,lines)), ...
    planWorkflow.gui.TextLayout.parameterHelpTextWrapColumn());
verifyGreaterThan(testCase, ...
    planWorkflow.gui.TextLayout.helpTextLineCount( ...
    longText,planWorkflow.gui.TextLayout.parameterHelpTextWrapColumn()),1);
verifyGreaterThan(testCase, ...
    planWorkflow.gui.TextLayout.helpTextHeightForDisplay( ...
    longText,planWorkflow.gui.TextLayout.parameterHelpTextWrapColumn()), ...
    planWorkflow.gui.TextLayout.helpTextHeightForDisplay('Short text.'));
verifyGreaterThan(testCase, ...
    planWorkflow.gui.TextLayout.helpTextWidth(),0.2);
verifyLessThan(testCase,planWorkflow.gui.TextLayout.helpTextWidth(),0.32);
end

function testPrecomputeParametersHaveHelpText(testCase)
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('doseResolution'), ...
    'grid resolution'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('robustness'), ...
    'robustness strategy'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('scen_mode'), ...
    'scenario model'));
verifyNotEmpty(testCase, ...
    planWorkflow.gui.HelpText.parameter('useCache'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('useCache'), ...
    'cached dose influence data'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('writeCache'), ...
    'cache for later runs'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('setupActive'), ...
    'uncertainty components'));
verifyFalse(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('rangeActive'), ...
    'uncertainty dimensions'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('gantryActive'), ...
    'gantry angle'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('couchActive'), ...
    'couch angle'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('gantryAngleSD'), ...
    'degrees'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('couchAngleSD'), ...
    'degrees'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('randomSeed'), ...
    'reproducible sampled scenario'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('ctScenProb'), ...
    'probability vector'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('p1'), ...
    'c-COWC'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('p2'), ...
    'optimization scenarios'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('theta1'), ...
    'Bertoluzza'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('theta2'), ...
    'INTERVAL3'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('radiusMode'), ...
    'extreme'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('KMode'), ...
    'OAR radius factor'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('kmax'), ...
    'radius factor components'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter( ...
    'retentionThreshold'), ...
    'retention threshold'));
interval3Help = [ ...
    planWorkflow.gui.HelpText.parameter('KMode') ' ' ...
    planWorkflow.gui.HelpText.parameter('kmax') ' ' ...
    planWorkflow.gui.HelpText.parameter('retentionThreshold')];
verifyTrue(testCase,contains(interval3Help,'std radius mode'));
verifyFalse(testCase,contains(interval3Help, ...
    ['OAR covariance/' 'SVD estimated memory']));
verifyFalse(testCase,contains(interval3Help,'SVD'));

verifyEmpty(testCase, ...
    planWorkflow.gui.HelpText.parameter('n_cores'));
end

function testPrepareParametersHaveHelpText(testCase)
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('hlutFileName'), ...
    'Hounsfield lookup table'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('hlutFileName'), ...
    'density information'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('plan_template'), ...
    'treatment plan template'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('plan_template'), ...
    'beams'));
end

function testSamplingAndAnalysisParametersHaveHelpText(testCase)
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter( ...
    'sampling_linkToOptimization'), ...
    'same patient case'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter( ...
    'sampling_scen_mode'), ...
    'sampling cases'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter( ...
    'robustnessTargetMode'), ...
    'all target structures'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter( ...
    'robustnessTargets'), ...
    'Select target structures'));
end

function testDosePullingChannelsHaveHelpText(testCase)
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('dose_pulling1'), ...
    'reference dose pulling'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('dose_pulling1'), ...
    'selected targets'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('dose_pulling2'), ...
    'robust dose pulling'));
verifyTrue(testCase,contains( ...
    planWorkflow.gui.HelpText.parameter('dose_pulling2'), ...
    'selected criterion'));
end

function testStructureHelpTextExplainsOperationAndMargins(testCase)
operationText = planWorkflow.gui.HelpText.structure( ...
    'Operation');
marginText = planWorkflow.gui.HelpText.structure( ...
    'Margins mm');

verifyTrue(testCase,contains(operationText,'boolean expressions'));
verifyTrue(testCase,contains(operationText,'CTV+PTV'));
verifyTrue(testCase,contains(marginText,'[inner outer]'));
verifyTrue(testCase,contains(marginText,'[0 20]'));
verifyEmpty(testCase, ...
    planWorkflow.gui.HelpText.structure('missing'));
end

function testObjectiveHelpTextExplainsJsonColumns(testCase)
parametersText = planWorkflow.gui.HelpText.objective( ...
    'Parameters JSON');
dosePullingText = planWorkflow.gui.HelpText.objective( ...
    'DosePulling JSON');

verifyTrue(testCase,contains(parametersText,'named matRad objective'));
verifyTrue(testCase,contains(parametersText,'"penalty"'));
verifyTrue(testCase,contains(dosePullingText,'channel and rate'));
verifyTrue(testCase,contains(dosePullingText,'dose_pulling_1'));
verifyGreaterThan(testCase, ...
    planWorkflow.gui.TextLayout.wideHelpTextWrapColumn(), ...
    planWorkflow.gui.TextLayout.parameterHelpTextWrapColumn());
verifyGreaterThan(testCase, ...
    planWorkflow.gui.TextLayout.objectiveHelpTextWrapColumn(), ...
    planWorkflow.gui.TextLayout.wideHelpTextWrapColumn());
verifyFalse(testCase,contains( ...
    planWorkflow.gui.panels.PreparePanel.objectiveHelpTextForDisplay( ...
    'DosePulling JSON'),newline));
verifyGreaterThanOrEqual(testCase, ...
    planWorkflow.gui.TextLayout.wideHelpTextHeightForDisplay( ...
    planWorkflow.gui.panels.PreparePanel.objectiveHelpTextForDisplay( ...
    'DosePulling JSON')),0.042);
verifyEmpty(testCase, ...
    planWorkflow.gui.HelpText.objective('missing'));
end

function testExportButtonLabel(testCase)
verifyEqual(testCase,planWorkflow.gui.EditorChrome.exportButtonLabel(), ...
    'Export');
end

function testActionButtonsUseTextLabels(testCase)
labels = planWorkflow.gui.EditorChrome.actionButtonLabels();

verifyEqual(testCase,labels.resume,'Resume');
verifyEqual(testCase,labels.settings,'Settings');
verifyFalse(testCase,isfield(labels,'import'));
end

function testPlanEditorMainWindowIsNotModal(testCase)
verifyEqual(testCase,planWorkflow.gui.EditorChrome.editorWindowStyle(), ...
    'normal');
end

function testFooterLayoutKeepsProgressClearAndButtonsTopAligned(testCase)
layout = planWorkflow.gui.EditorChrome.footerLayout();

progressRight = layout.progressDetails(1) + layout.progressDetails(3);
buttonLeft = min([layout.exportButton(1),layout.calculateButton(1), ...
    layout.stopButton(1),layout.cancelButton(1)]);
verifyLessThanOrEqual(testCase,progressRight,buttonLeft - 0.01);

detailsTop = layout.progressDetails(2) + layout.progressDetails(4);
verifyGreaterThanOrEqual(testCase,layout.exportButton(2), ...
    detailsTop + 0.005);

buttonTop = layout.exportButton(2) + layout.exportButton(4);
buttonTops = [layout.calculateButton(2) + layout.calculateButton(4), ...
    layout.stopButton(2) + layout.stopButton(4), ...
    layout.cancelButton(2) + layout.cancelButton(4)];
verifyEqual(testCase,buttonTops,repmat(buttonTop,1,3), ...
    'AbsTol',1e-12);
end

function testObjectiveHeaderLayoutKeepsInputsClearOfActions(testCase)
layout = planWorkflow.gui.panels.PreparePanel.objectiveHeaderLayout();

fractionsRight = layout.fractionsEdit(1) + layout.fractionsEdit(3);
firstActionLeft = layout.addRobustPlanButton(1);
verifyLessThanOrEqual(testCase,fractionsRight,firstActionLeft - 0.04);

doseRight = layout.prescriptionEdit(1) + layout.prescriptionEdit(3);
verifyLessThanOrEqual(testCase,doseRight,layout.fractionsLabel(1) - 0.02);

verifyLessThanOrEqual(testCase,layout.objectiveTabsTop, ...
    layout.addRobustPlanButton(2) - 0.02);

actionButtons = [ ...
    layout.addRobustPlanButton; ...
    layout.deleteRobustPlanButton; ...
    layout.addObjectiveButton; ...
    layout.deleteObjectiveButton];
actionGaps = actionButtons(2:end,1) - ...
    (actionButtons(1:end-1,1) + actionButtons(1:end-1,3));
verifyTrue(testCase,all(actionGaps >= 0.01 - 1e-12));
end

function testPrecomputeActionLayoutKeepsActionsAboveTabs(testCase)
layout = planWorkflow.gui.panels.PrecomputePanel.actionLayout();

tabTop = layout.tabGroup(2) + layout.tabGroup(4);
verifyGreaterThanOrEqual(testCase, ...
    layout.addRobustPlanButton(2),tabTop + 0.01);
verifyGreaterThanOrEqual(testCase, ...
    layout.deleteRobustPlanButton(2),tabTop + 0.01);

addRight = layout.addRobustPlanButton(1) + ...
    layout.addRobustPlanButton(3);
deleteRight = layout.deleteRobustPlanButton(1) + ...
    layout.deleteRobustPlanButton(3);
verifyLessThanOrEqual(testCase,deleteRight,0.98);
verifyGreaterThanOrEqual(testCase, ...
    layout.deleteRobustPlanButton(1),addRight + 0.01);
end

function testObjectiveTableUsesDropdownsForStructureAndType(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');

columnFormat = planWorkflow.gui.ObjectiveTableAdapter.columnFormat( ...
    template);

verifyEqual(testCase,columnFormat{1},'logical');
verifyTrue(testCase,iscell(columnFormat{2}));
verifyTrue(testCase,iscell(columnFormat{3}));
verifyTrue(testCase,any(strcmp(columnFormat{2},'CTV')));
verifyTrue(testCase,any(strcmp(columnFormat{2},'RING 0 - 20 mm')));
verifyTrue(testCase,any(strcmp(columnFormat{3},'matRad_MaxDVH')));
verifyTrue(testCase,any(strcmp(columnFormat{3},'matRad_MinDVH')));
verifyTrue(testCase,any(strcmp(columnFormat{3},'matRad_MeanVariance')));
verifyTrue(testCase,any(strcmp(columnFormat{3}, ...
    'matRad_MinMaxMeanVariance')));
verifyEqual(testCase,columnFormat{4},'char');
verifyTrue(testCase,iscell(columnFormat{5}));
verifyTrue(testCase,any(strcmp(columnFormat{5},'none')));
verifyTrue(testCase,any(strcmp(columnFormat{5},'PROB2')));
verifyTrue(testCase,any(strcmp(columnFormat{5},'INTERVAL2')));
end

function testObjectiveTableHarmonizesNonNoneRobustnessRows(testCase)
data = {true,'CTV','matRad_MaxDVH','{}','none',''; ...
    true,'PTV','matRad_MaxDVH','{}','INTERVAL2',''; ...
    true,'RECTUM','matRad_MaxDVH','{}','COWC',''};

data = planWorkflow.gui.ObjectiveTableAdapter.harmonizeNonNoneRobustness( ...
    data,'INTERVAL3');

verifyEqual(testCase,data{1,5},'none');
verifyEqual(testCase,data{2,5},'INTERVAL3');
verifyEqual(testCase,data{3,5},'INTERVAL3');

data = planWorkflow.gui.ObjectiveTableAdapter.harmonizeNonNoneRobustness( ...
    data,'none');

verifyEqual(testCase,data{1,5},'none');
verifyEqual(testCase,data{2,5},'none');
verifyEqual(testCase,data{3,5},'none');
end

function testObjectiveRobustnessMutatorSetsEntireObjectiveSet(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
objectiveSetName = firstRobustObjectiveSetName(template);

template = ...
    planWorkflow.templates.ObjectiveRobustnessMutator.setTemplateObjectiveSetRobustness( ...
    template,objectiveSetName,'INTERVAL3');
data = planWorkflow.gui.ObjectiveTableAdapter.toTable( ...
    template,objectiveSetName);

verifyFalse(testCase,any(strcmp(data(:,5),'none')));
verifyTrue(testCase,all(strcmp(data(:,5),'INTERVAL3')));
end

function testPlanEditorContractRetargetsPrecomputeFromObjectiveRobustness(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
objectiveSetName = firstRobustObjectiveSetName(template);
runConfig = baseRunConfigWithRobust('INTERVAL2','nomScen', ...
    struct('ctActive',true));

template = ...
    planWorkflow.templates.ObjectiveRobustnessMutator.setTemplateObjectiveSetRobustness( ...
    template,objectiveSetName,'INTERVAL3');
runConfig = ...
    planWorkflow.gui.PlanEditorContract.retargetPrecomputeRobustnessFromObjectives( ...
    runConfig,template);
robustPlans = ...
    planWorkflow.config.RobustPlanConfig.plansFromRunConfig(runConfig);

verifyEqual(testCase,robustPlans(1).robustnessMode,'INTERVAL3');
verifyTrue(testCase,isfield(robustPlans(1).variants,'theta2'));
verifyEqual(testCase,robustPlans(1).robustnessOptions.radiusMode,'std');
verifyEqual(testCase,robustPlans(1).robustnessOptions.KMode,'dynamic');
end

function testStructureTableIncludesStructuresAndRings(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');

data = planWorkflow.gui.TemplateStructureTableAdapter.toTable(template);
supportedRoles = planWorkflow.gui.panels.PreparePanel.supportedStructureRoles();

verifyEqual(testCase,size(data,2),7);
verifyTrue(testCase,any(strcmp(data(:,1),'Structure') & ...
    strcmp(data(:,2),'CTV')));
verifyTrue(testCase,any(strcmp(data(:,1),'Ring') & ...
    strcmp(data(:,2),'RING 0 - 20 mm')));
verifyTrue(testCase,all(ismember(data(:,3),supportedRoles)));
end

function testStructureTableCanAddAndRemoveStructures(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
data = planWorkflow.gui.TemplateStructureTableAdapter.toTable(template);
data(end + 1,:) = {'Structure','BOWEL','OAR','[0.2 0.3 0.4]',3,'',''};

template = planWorkflow.gui.TemplateStructureTableAdapter.applyTable( ...
    template,data);

verifyTrue(testCase,any(strcmp({template.structures.name},'BOWEL')));
bowelIx = find(strcmp({template.structures.name},'BOWEL'),1);
verifyEqual(testCase,template.structures(bowelIx).role,'OAR');

data = planWorkflow.gui.TemplateStructureTableAdapter.toTable(template);
data(strcmp(data(:,2),'BOWEL'),:) = [];
template = planWorkflow.gui.TemplateStructureTableAdapter.applyTable( ...
    template,data);

verifyFalse(testCase,any(strcmp({template.structures.name},'BOWEL')));
end

function testStructureTableCanEditBooleanOperations(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
data = planWorkflow.gui.TemplateStructureTableAdapter.toTable(template);
data(end + 1,:) = {'Structure','PTV_MINUS_CTV','OAR','[0.1 0.2 0.3]',4, ...
    'PTV-CTV',''};

template = planWorkflow.gui.TemplateStructureTableAdapter.applyTable( ...
    template,data);

structureIx = find(strcmp({template.structures.name},'PTV_MINUS_CTV'));
verifyEqual(testCase,template.structures(structureIx).operation,'PTV-CTV');
end

function testStructureTableCanEditVisibleColor(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
data = planWorkflow.gui.TemplateStructureTableAdapter.toTable(template);
ctvRow = find(strcmp(data(:,2),'CTV'),1);
ringRow = find(strcmp(data(:,2),'RING 0 - 20 mm'),1);
data{ctvRow,4} = '[0.25 0.5 0.75]';
data{ringRow,4} = '[0.1 0.2 0.3]';

template = planWorkflow.gui.TemplateStructureTableAdapter.applyTable( ...
    template,data);

ctvIx = find(strcmp({template.structures.name},'CTV'),1);
ringIx = find(strcmp({template.rings.name},'RING 0 - 20 mm'),1);
verifyEqual(testCase,template.structures(ctvIx).visibleColor, ...
    [0.25 0.5 0.75]);
verifyEqual(testCase,template.rings(ringIx).visibleColor, ...
    [0.1 0.2 0.3]);
end

function testStructureTableColorsUseTemplateThenDefault(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
data = planWorkflow.gui.TemplateStructureTableAdapter.toTable(template);
ctvRow = find(strcmp(data(:,2),'CTV'),1);
ringRow = find(strcmp(data(:,2),'RING 0 - 20 mm'),1);
ctvIx = find(strcmp({template.structures.name},'CTV'),1);
verifyEqual(testCase,data{ctvRow,4}, ...
    planWorkflow.gui.TemplateStructureTableAdapter.colorText([1 0 0]));
verifyEqual(testCase,data{ringRow,4}, ...
    planWorkflow.gui.TemplateStructureTableAdapter.colorText( ...
    [0 1 0.501960784313726]));

template.structures(ctvIx).visibleColor = [];
data = planWorkflow.gui.TemplateStructureTableAdapter.toTable(template);
verifyEqual(testCase,data{ctvRow,4}, ...
    planWorkflow.gui.TemplateStructureTableAdapter.colorText([0 1 0]));

template.structures(ctvIx).visibleColor = [0.25 0.5 0.75];
data = planWorkflow.gui.TemplateStructureTableAdapter.toTable(template);
verifyEqual(testCase,data{ctvRow,4}, ...
    planWorkflow.gui.TemplateStructureTableAdapter.colorText( ...
    [0.25 0.5 0.75]));
end

function testStructureTablePreservesObjectiveSetsWhenRenamingByRow(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
data = planWorkflow.gui.TemplateStructureTableAdapter.toTable(template);
ctvRow = find(strcmp(data(:,2),'CTV'),1);
data{ctvRow,2} = 'CTV_EDITED';

template = planWorkflow.gui.TemplateStructureTableAdapter.applyTable( ...
    template,data);

editedIx = find(strcmp({template.structures.name},'CTV_EDITED'),1);
editedObjectiveIx = objectiveGroupIndex(template,'reference','CTV_EDITED');
verifyNotEmpty(testCase,editedIx);
verifyNotEmpty(testCase,editedObjectiveIx);
verifyNotEmpty(testCase, ...
    template.objectiveSets.reference.structureObjectives( ...
    editedObjectiveIx).objectives);
verifyFalse(testCase,isfield(template.structures,'objectives'));
end

function testEditedBeamParametersAreApplied(testCase)
runConfig = baseRunConfig();
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
beamIx = find(strcmp({template.beamSets.id},'9F'));
template.beamSets(beamIx).numOfFractions = 25;
template.beamSets(beamIx).gantryAngles = [10 20 30];
template.beamSets(beamIx).couchAngles = [0 5 10];
template.beamSets(beamIx).bixelWidth = 4;
ct = makeCt([7 7 7]);
cst = makeProstateCst(ct.cubeDim);
pln = struct();

pln = planWorkflow.templates.PlanTemplate.applyBeams( ...
    runConfig,pln,ct,cst,template);

verifyEqual(testCase,pln.numOfFractions,25);
verifyEqual(testCase,pln.propStf.gantryAngles,[10 20 30]);
verifyEqual(testCase,pln.propStf.couchAngles,[0 5 10]);
verifyEqual(testCase,pln.propStf.bixelWidth,4);
end

function testEditedPrescriptionAndObjectiveParametersAreApplied(testCase)
runConfig = baseRunConfig();
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
template.prescriptionDose = 80;
ctvIx = objectiveGroupIndex(template,'reference','CTV');
objective = objectiveFromGroup( ...
    template.objectiveSets.reference.structureObjectives(ctvIx),1);
objective.parameters.penalty = 45;
template.objectiveSets.reference.structureObjectives(ctvIx) = ...
    setObjectiveInGroup( ...
    template.objectiveSets.reference.structureObjectives(ctvIx), ...
    1,objective);
cst = makeProstateCst([7 7 7]);

[cst,objectiveInfo] = planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst,template);

verifyEqual(testCase,objectiveInfo.prescriptionDose,80);
verifyEqual(testCase,cst{objectiveInfo.ixTarget,6}{1}.penalty,45);
verifyEqual(testCase,cst{objectiveInfo.ixTarget,6}{1}.parameters{1},80);
end

function testEditedObjectiveRowsAreApplied(testCase)
runConfig = baseRunConfig();
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
ctvIx = objectiveGroupIndex(template,'reference','CTV');
extraObjective = struct();
extraObjective.enabled = true;
extraObjective.type = 'matRad_MaxDVH';
extraObjective.parameters = struct('penalty',5,'dRef',70,'vMaxPercent',1);
extraObjective.properties = struct('robustness','none');
firstObjective = objectiveFromGroup( ...
    template.objectiveSets.reference.structureObjectives(ctvIx),1);
template.objectiveSets.reference.structureObjectives( ...
    ctvIx).objectives = {firstObjective,extraObjective};
cst = makeProstateCst([7 7 7]);

[cst,objectiveInfo] = planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst,template);

verifyNumElements(testCase,cst{objectiveInfo.ixTarget,6},2);
verifyEqual(testCase,cst{objectiveInfo.ixTarget,6}{2}.penalty,5);
verifyEqual(testCase,cst{objectiveInfo.ixTarget,6}{2}.parameters{1},70);
end

function testEditedDosePullingChannelAndRatesAreApplied(testCase)
runConfig = baseRunConfig();
runConfig.dose_pulling1 = true;
runConfig.dose_pulling1_start = 2;
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
template.dosePulling.dose_pulling_1.step = 5;
bladderIx = objectiveGroupIndex(template,'reference','BLADDER');
objective = objectiveFromGroup( ...
    template.objectiveSets.reference.structureObjectives(bladderIx),1);
objective.dosePulling.rates.vMaxPercent = 3;
template.objectiveSets.reference.structureObjectives(bladderIx) = ...
    setObjectiveInGroup( ...
    template.objectiveSets.reference.structureObjectives(bladderIx), ...
    1,objective);
cst = makeProstateCst([7 7 7]);

[cst,~] = planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst,template);

ixBladder = find(strcmp(cst(:,2),'BLADDER'),1);
verifyEqual(testCase,cst{ixBladder,6}{1}.parameters{2},6);
verifyEqual(testCase,cst{ixBladder,6}{1}.pullingStep,5);
verifyEqual(testCase,cst{ixBladder,6}{1}.objectivePullingRate{2},3);
end

function testEditedTemplateRejectsUnknownDosePullingChannel(testCase)
runConfig = baseRunConfig();
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
bladderIx = objectiveGroupIndex(template,'reference','BLADDER');
objective = objectiveFromGroup( ...
    template.objectiveSets.reference.structureObjectives(bladderIx),1);
objective.dosePulling.channel = 'missing';
template.objectiveSets.reference.structureObjectives(bladderIx) = ...
    setObjectiveInGroup( ...
    template.objectiveSets.reference.structureObjectives(bladderIx), ...
    1,objective);

verifyError(testCase,@() ...
    planWorkflow.templates.PlanTemplate.validateEffectiveTemplate( ...
    template,runConfig), ...
    'planWorkflow:templates:PlanTemplate:UnknownDosePullingChannel');
end

function testEditedTemplateRejectsInvalidStartConfig(testCase)
runConfig = baseRunConfig();
runConfig.dose_pulling1 = true;
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
template.dosePulling.dose_pulling_1.startConfig = 'missing_start';

verifyError(testCase,@() ...
    planWorkflow.templates.PlanTemplate.validateEffectiveTemplate( ...
    template,runConfig), ...
    'planWorkflow:config:DosePullingConfig:MissingStartConfig');
end

function testEditedTemplateRejectsInvalidParameterName(testCase)
runConfig = baseRunConfig();
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
ctvIx = objectiveGroupIndex(template,'reference','CTV');
objective = objectiveFromGroup( ...
    template.objectiveSets.reference.structureObjectives(ctvIx),1);
objective.parameters.badParameter = 1;
template.objectiveSets.reference.structureObjectives(ctvIx) = ...
    setObjectiveInGroup( ...
    template.objectiveSets.reference.structureObjectives(ctvIx), ...
    1,objective);

verifyError(testCase,@() ...
    planWorkflow.templates.PlanTemplate.validateEffectiveTemplate( ...
    template,runConfig), ...
    'planWorkflow:templates:PlanTemplate:UnsupportedField');
end

function testEffectiveTemplateHashDoesNotDriveDoseCacheKey(testCase)
workflow = planWorkflowTest.EngineProbe(baseWorkflowConfig(testCase));
template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');
workflow.setEffectivePlanTemplatePublic(template);
baseKey = workflow.cacheKeyPublic('reference');
template.prescriptionDose = template.prescriptionDose + 1;
workflow.setEffectivePlanTemplatePublic(template);

verifyEqual(testCase,workflow.cacheKeyPublic('reference'),baseKey);
verifyFalse(testCase,contains(workflow.cacheKeyPublic('reference'), ...
    workflow.runConfig.plan_template_hash));
end

function config = baseWorkflowConfig(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
config = baseRunConfig();
config.workflowType = 'test';
config.caseID = 'case';
config.runId = 'plan-template-editor-test';
config.outputRootPath = fullfile(fixture.Folder,'output');
config.patientDataPath = fullfile(fixture.Folder,'patients');
config.cacheRootPath = fullfile(fixture.Folder,'cache');
end

function runConfig = baseRunConfig()
runConfig = struct();
runConfig.radiationMode = 'photons';
runConfig.description = 'prostate';
runConfig.plan_template = 'interval2_001';
runConfig.plan_beams = '9F';
runConfig.doseResolution = [3 3 3];
runConfig.precompute = planWorkflow.config.RobustPlanConfig.defaults();
runConfig.useCache = true;
runConfig.writeCache = true;
runConfig.sampling_linkToOptimization = true;
runConfig.sampling_scen_mode = 'impScen_permuted5';
runConfig.sampling_ctActive = true;
runConfig.sampling_ctReferenceScenId = 1;
runConfig.sampling_ctScenProb = [];
runConfig.sampling_setupActive = true;
runConfig.sampling_rangeActive = false;
runConfig.sampling_gantryActive = false;
runConfig.sampling_couchActive = false;
runConfig.sampling_shiftSD = [5 10 5];
runConfig.sampling_wcSigma = 1.5;
runConfig.sampling_rangeAbsSD = 0;
runConfig.sampling_rangeRelSD = 0;
runConfig.sampling_numOfRangeGridPoints = 1;
runConfig.sampling_gantryAngleSD = 0;
runConfig.sampling_couchAngleSD = 0;
runConfig.sampling_size = 50;
runConfig.sampling_randomSeed = [];
runConfig.dose_pulling1_start = 0;
runConfig.dose_pulling2_target = {'CTV'};
runConfig.dose_pulling2_start = 0;
end

function runConfig = dosePullingPanelRunConfig()
runConfig = struct();
runConfig.dose_pulling1 = false;
runConfig.dose_pulling1_target = {'CTV'};
runConfig.dose_pulling1_criteria = {'COV1'};
runConfig.dose_pulling1_limit = 0.9;
runConfig.dose_pulling1_start = 0;
runConfig.dose_pulling2 = false;
runConfig.dose_pulling2_target = {'CTV'};
runConfig.dose_pulling2_criteria = 'meanQiTarget';
runConfig.dose_pulling2_limit = 0.4;
runConfig.dose_pulling2_start = 0;
runConfig.dose_pulling_max_iter = 100;
runConfig.dose_pulling_strategy = 'heuristicMultiObjective';
runConfig.dose_pulling_search_schedule = 'exponential';
runConfig.dose_pulling_local_window = 8;
runConfig.dose_pulling_patience = 3;
runConfig.dose_pulling_target_tol = 1e-3;
runConfig.dose_pulling_selection_policy = 'normalizedKnee';
runConfig.dose_pulling_target_weight = 1.0;
runConfig.dose_pulling_oar_weight = 1.0;
runConfig.dose_pulling_step_weight = 1e-6;
runConfig.dose_pulling_max_vmax_percent = 100;
runConfig.dose_pulling_use_warm_start = true;
end

function runConfig = baseRunConfigWithRobust(robustness,scenMode, ...
        dimensionConfig)
runConfig = baseRunConfig();
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = 'Interval2';
plan.label = 'Interval2';
plan.objectiveSetName = 'Interval2';
plan.robustnessMode = robustness;
plan.scenario = planWorkflow.config.RobustPlanConfig.defaultScenario( ...
    scenMode);
fields = [{'ctActive','ctReferenceScenId'}, ...
    planWorkflow.scenario.dimensionActiveFields()];
for i = 1:numel(fields)
    fieldName = fields{i};
    if isfield(dimensionConfig,fieldName)
        plan.scenario.(fieldName) = dimensionConfig.(fieldName);
    end
end
runConfig.precompute.robustPlans = ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(plan);
end

function [template,runConfig] = appendSecondRobustPlan(template,runConfig)
robustObjectiveSets = ...
    planWorkflow.templates.PlanTemplate.robustObjectiveSets(template);
secondSet = robustObjectiveSets(1);
secondSet.id = 'robust_2';
secondSet.label = 'Robust 2';
template.objectiveSets.robustPlans = [robustObjectiveSets secondSet];

robustPlans = ...
    planWorkflow.config.RobustPlanConfig.plansFromRunConfig(runConfig);
secondPlan = robustPlans(1);
secondPlan.id = 'robust_2';
secondPlan.label = 'Robust 2';
secondPlan.objectiveSetName = 'robust_2';
runConfig.precompute.robustPlans = ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    [robustPlans secondPlan]);
end

function objectiveSetName = firstRobustObjectiveSetName(template)
robustObjectiveSets = ...
    planWorkflow.templates.PlanTemplate.robustObjectiveSets(template);
objectiveSetName = char(robustObjectiveSets(1).id);
end

function assertFieldBefore(testCase,fields,beforeField,afterField)
beforeIx = find(strcmp(fields,beforeField),1,'first');
afterIx = find(strcmp(fields,afterField),1,'first');
verifyFalse(testCase,isempty(beforeIx),sprintf('Missing field "%s".',beforeField));
verifyFalse(testCase,isempty(afterIx),sprintf('Missing field "%s".',afterField));
if ~isempty(beforeIx) && ~isempty(afterIx)
    verifyLessThan(testCase,beforeIx,afterIx);
end
end

function groupIx = objectiveGroupIndex(template,objectiveSetName,structureName)
objectiveSet = planWorkflow.templates.PlanTemplate.objectiveSet( ...
    template,objectiveSetName);
groupIx = find(strcmp({objectiveSet.structureObjectives.name}, ...
    structureName),1);
end

function objective = objectiveFromGroup(group,index)
objectives = group.objectives;
if iscell(objectives)
    objective = objectives{index};
else
    objective = objectives(index);
end
end

function group = setObjectiveInGroup(group,index,objective)
objectives = group.objectives;
if ~iscell(objectives)
    objectives = num2cell(objectives);
end
objectives{index} = objective;
group.objectives = objectives;
end

function ct = makeCt(cubeDim)
ct = struct();
ct.cubeDim = cubeDim;
ct.resolution = struct('x',1,'y',1,'z',1);
ct.numOfCtScen = 1;
end

function cst = makeProstateCst(cubeDim)
cst = cell(5,6);
cst = setStructure(cst,1,'BODY','OAR',find(true(cubeDim)),5);
cst = setStructure(cst,2,'CTV','TARGET',sub2ind(cubeDim,4,4,4),1);
cst = setStructure(cst,3,'PTV','TARGET', ...
    sub2ind(cubeDim,[3 4 5],[4 4 4],[4 4 4]),2);
cst = setStructure(cst,4,'BLADDER','OAR',sub2ind(cubeDim,2,4,4),3);
cst = setStructure(cst,5,'RECTUM','OAR',sub2ind(cubeDim,6,4,4),3);
end

function cst = setStructure(cst,ix,name,role,voxels,priority)
cst{ix,1} = ix;
cst{ix,2} = name;
cst{ix,3} = role;
cst{ix,4}{1} = voxels(:);
cst{ix,5} = struct('Priority',priority,'Visible',false, ...
    'visibleColor',[1 0 0]);
cst{ix,6} = [];
end
