function tests = testEngineConfig
tests = functiontests(localfunctions);
end

function testUnsupportedRootAnalysisFieldIsRejected(testCase)
config = baseEngineConfig(testCase);
config.gammaCriteria = [3 3];

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:Engine:UnsupportedConfigField');
end

function testLegacyNCoresIsRejected(testCase)
config = baseEngineConfig(testCase);
config.n_cores = 8;

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:Engine:UnsupportedConfigField');
end

function testLegacyPrepareNCoresIsRejected(testCase)
config = baseEngineConfig(testCase);
config.prepare = struct('n_cores',8);

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:WorkflowBase:UnsupportedStageConfigField');
end

function testResourcesAndOptimizerOptionsAreNormalized(testCase)
config = baseEngineConfig(testCase);
config.optimizerOptions = struct('max_iter',7);
config.resources = struct();
config.resources.sampling = struct('workerUpperBound',2);
config.resources.doseCalculation = struct('workerUpperBound',3);

workflow = planWorkflowTest.EngineProbe(config);

verifyEqual(testCase,workflow.runConfig.optimizerOptions.max_iter,7);
verifyTrue(testCase,workflow.runConfig.resources.memory.enabled);
verifyEqual(testCase, ...
    workflow.runConfig.resources.sampling.workerUpperBound,2);
verifyEqual(testCase, ...
    workflow.runConfig.resources.sampling.workerMemorySafetyFactor,1.2);
verifyEqual(testCase, ...
    workflow.runConfig.resources.sampling.minWorkerMemoryBytes, ...
    2 * 1024^3);
verifyEqual(testCase, ...
    workflow.runConfig.resources.doseCalculation.workerUpperBound,3);
verifyEqual(testCase, ...
    workflow.runConfig.resources.doseCalculation.minWorkerMemoryBytes, ...
    4 * 1024^3);
end

function testSingleRobustPlanUsesCanonicalRobustnessMode(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2 plan','Interval2','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
workflow = planWorkflow.Workflow(config);

robustPlans = workflow.runConfig.precompute.robustPlans;
verifyEqual(testCase,numel(robustPlans),1);
verifyEqual(testCase,robustPlans(1).robustnessMode,'INTERVAL2');
end

function testGuiAcceptedRunConfigReplacesStaleRobustVariantFields(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2 plan','Interval2','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_10','Theta 10',1,1,10,1));
workflow = planWorkflowTest.EngineProbe(config);

editedRunConfig = workflow.runConfig;
editedRunConfig.precompute.robustPlans(1).robustnessMode = 'none';
editedRunConfig.precompute.robustPlans(1).robustnessOptions = struct();
editedRunConfig.precompute.robustPlans(1).variants = ...
    planWorkflow.config.RobustPlanConfig.defaultVariants('none');
template = workflow.activePlanTemplatePublic();
nominalTemplate = ...
    planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','comparison_001');
nominalObjectiveSet = ...
    planWorkflow.templates.PlanTemplate.objectiveSet( ...
    nominalTemplate,'PTV');
template = ...
    planWorkflow.templates.PlanTemplate.setObjectiveSet( ...
    template,'Interval2',nominalObjectiveSet);
workflow.setEditorResponse(template,editedRunConfig,true,[],'');

workflow.gui();

robustPlan = workflow.runConfig.precompute.robustPlans(1);
verifyEqual(testCase,robustPlan.robustnessMode,'none');
verifyFalse(testCase,isfield(robustPlan.variants,'theta1'));
end

function testUnknownRobustPlanRobustnessModeIsRejected(testCase)
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.robustnessMode = 'COWC2';

verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(plan), ...
    'planWorkflow:config:RobustPlanConfig:UnknownStrategy');
end

function testMultipleRobustPlansPreserveIndependentConfigAndVariants(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'comparison_001';
config.precompute.robustPlans = [ ...
    robustPlanConfig('ptvPlan','PTV plan','PTV', ...
    'none','wcScen',[5 10 5], ...
    robustVariantConfig('variant_1','Variant 1',1,1,1,1)); ...
    robustPlanConfig('intervalPlan','Interval plan','Interval2', ...
    'INTERVAL2','random',[1 2 3], ...
    [robustVariantConfig('theta_low','Theta low',1,1,10,1); ...
    robustVariantConfig('theta_high','Theta high',1,1,20,1)])];

workflow = planWorkflowTest.EngineProbe(config);

robustPlans = workflow.runConfig.precompute.robustPlans;
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','comparison_001');
robustObjectiveSets = ...
    planWorkflow.templates.PlanTemplate.robustObjectiveSets(template);
ptvIx = robustPlanIx(robustPlans,'PTV');
intervalIx = robustPlanIx(robustPlans,'Interval2');
verifyEqual(testCase,numel(robustPlans),numel(robustObjectiveSets));
verifyEqual(testCase,robustPlans(ptvIx).robustnessMode, ...
    'none');
verifyEqual(testCase,robustPlans(ptvIx).scenario.mode, ...
    'wcScen');
verifyEqual(testCase,robustPlans(intervalIx).robustnessMode, ...
    'INTERVAL2');
verifyEqual(testCase,robustPlans(intervalIx).scenario.mode, ...
    'random');
verifyEqual(testCase,robustPlans(intervalIx).scenario.shiftSD, ...
    [1 2 3]);
verifyEqual(testCase,[robustPlans(intervalIx).variants.theta1], ...
    [10 20]);
end

function testNamedRobustPlansAreAcceptedForMacros(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'comparison_001';
config.precompute.robustPlans = struct();
config.precompute.robustPlans.robust_1.label = 'PTV';
config.precompute.robustPlans.robust_1.objectiveSetName = 'PTV';
config.precompute.robustPlans.robust_1.scenario = ...
    planWorkflow.config.RobustPlanConfig.defaultScenario('nomScen');
config.precompute.robustPlans.robust_1.scenario.ctActive = false;
config.precompute.robustPlans.robust_1.scenario.setupActive = false;
config.precompute.robustPlans.robust_1.variants = ...
    robustVariantsForStrategy( ...
    robustVariantConfig('variant_1','Variant 1',1,1,1,1),'none');

config.precompute.robustPlans.robust_2.label = 'INTERVAL2';
config.precompute.robustPlans.robust_2.objectiveSetName = 'Interval2';
config.precompute.robustPlans.robust_2.scenario = ...
    planWorkflow.config.RobustPlanConfig.defaultScenario('wcScen');
config.precompute.robustPlans.robust_2.variants = [ ...
    robustVariantConfig('theta_1','Theta 1',1,1,1,1); ...
    robustVariantConfig('theta_5','Theta 5',1,1,5,1); ...
    robustVariantConfig('theta_10','Theta 10',1,1,10,1)];
config.precompute.robustPlans.robust_2.variants = ...
    robustVariantsForStrategy( ...
    config.precompute.robustPlans.robust_2.variants,'INTERVAL2');

workflow = planWorkflowTest.EngineProbe(config);

robustPlans = workflow.runConfig.precompute.robustPlans;
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','comparison_001');
robustObjectiveSets = ...
    planWorkflow.templates.PlanTemplate.robustObjectiveSets(template);
ptvIx = robustPlanIx(robustPlans,'PTV');
intervalIx = robustPlanIx(robustPlans,'Interval2');
verifyEqual(testCase,numel(robustPlans),numel(robustObjectiveSets));
verifyEqual(testCase,{robustPlans.id}, ...
    {robustObjectiveSets.id});
expectedLabels = {robustObjectiveSets.label};
expectedLabels{intervalIx} = 'INTERVAL2';
verifyEqual(testCase,{robustPlans.label},expectedLabels);
verifyEqual(testCase,robustPlans(ptvIx).robustnessMode, ...
    'none');
verifyEqual(testCase,robustPlans(intervalIx).robustnessMode, ...
    'INTERVAL2');
verifyEqual(testCase,[robustPlans(intervalIx).variants.theta1], ...
    [1 5 10]);
end

function testNamedRobustPlanIdMismatchIsRejected(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = struct();
config.precompute.robustPlans.robust_1.id = 'other';

verifyError(testCase,@() planWorkflowTest.EngineProbe(config), ...
    'planWorkflow:config:RobustPlanConfig:RobustPlanIdMismatch');
end

function testRobustPlanRuntimeDataKeepsIndependentStructs(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));
workflow.data.robustPlans = cell(1,2);

ptvData = struct();
ptvData.planConfig = robustPlanConfig('robust_1','PTV','robust_1', ...
    'none','nomScen',[0 0 0], ...
    robustVariantConfig('variant_1','Variant 1',1,1,1,1));
ptvData.variantResults = planWorkflow.results.VariantResults.create( ...
    ptvData,1,struct('w',1));

intervalData = struct();
intervalData.planConfig = robustPlanConfig('robust_2','INTERVAL2', ...
    'robust_2','INTERVAL2','wcScen',[5 10 5], ...
    [robustVariantConfig('theta_5','Theta 5',1,1,5,1); ...
    robustVariantConfig('theta_10','Theta 10',1,1,10,1)]);
intervalData.dij_interval = struct('center',sparse(1,1));
intervalData.dijIntervalContext = struct('numOfScenarios',1);
intervalData.plnForOptimization = struct();
intervalData.variantResults = [ ...
    planWorkflow.results.VariantResults.create( ...
    intervalData,1,struct('w',2)); ...
    planWorkflow.results.VariantResults.create( ...
    intervalData,2,struct('w',3))];

workflow.data.robustPlans = {ptvData,intervalData};

verifyEqual(testCase,numel(workflow.data.robustPlans),2);
verifyFalse(testCase,isfield(workflow.data.robustPlans{1}, ...
    'dij_interval'));
verifyTrue(testCase,isfield(workflow.data.robustPlans{2}, ...
    'dij_interval'));
resultCount = ...
    numel(planWorkflow.results.VariantResults.requireComplete( ...
    workflow.data.robustPlans{1},'test result counting')) + ...
    numel(planWorkflow.results.VariantResults.requireComplete( ...
    workflow.data.robustPlans{2},'test result counting'));
verifyEqual(testCase,resultCount,3);
end

function testRobustResultLabelsUsePlanLabelAndStrategyParameters(testCase)
interval2Data = robustDataForLabel('INTERVAL2','INTERVAL2', ...
    robustVariantConfig('theta_5','Internal label',1,1,5,1));
verifyEqual(testCase, ...
    planWorkflow.results.PlanLabels.robustResultLabel( ...
    interval2Data.planConfig,1), ...
    'INTERVAL2 (theta1=5)');

interval3Data = robustDataForLabel('Interval 3 plan','INTERVAL3', ...
    robustVariantConfig('theta_pair','Internal label',1,1,10,0.5));
verifyEqual(testCase, ...
    planWorkflow.results.PlanLabels.robustResultLabel( ...
    interval3Data.planConfig,1), ...
    'Interval 3 plan (theta1=10, theta2=0.5)');

cheapCowcData = robustDataForLabel('Cheap COWC plan','c-COWC', ...
    robustVariantConfig('bounds','Internal label',0.25,0.75,1,1));
verifyEqual(testCase, ...
    planWorkflow.results.PlanLabels.robustResultLabel( ...
    cheapCowcData.planConfig,1), ...
    'Cheap COWC plan (p1=0.25, p2=0.75)');
end

function testRobustSamplingLabelsUseRunConfigStrategyParameters(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig('intervalPlan','INTERVAL2', ...
    'Interval2','INTERVAL2','wcScen',[5 10 5], ...
    [robustVariantConfig('theta_1','Variant 1',1,1,1,1); ...
    robustVariantConfig('theta_5','Variant 2',1,1,5,1); ...
    robustVariantConfig('theta_10','Variant 3',1,1,10,1)]);
workflow = planWorkflowTest.EngineProbe(config);

sample = struct('label','INTERVAL2 / Variant 2');

verifyEqual(testCase, ...
    planWorkflow.results.PlanLabels.robustResultLabelFromRunConfig( ...
	    workflow.runConfig,2,sample.label), ...
	    'INTERVAL2 (theta1=5)');
end

function testPlanTaskTimingLabelsUseStrategyParameters(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig('intervalPlan','INTERVAL2', ...
    'Interval2','INTERVAL2','wcScen',[5 10 5], ...
    [robustVariantConfig('theta_1','Variant 1',1,1,1,1); ...
    robustVariantConfig('theta_5','Variant 2',1,1,5,1)]);
workflow = planWorkflowTest.EngineProbe(config);

verifyEqual(testCase, ...
    planWorkflow.results.PlanLabels.planTimingLabel( ...
	    workflow.runConfig,'INTERVAL2 / Variant 2','robust', ...
	    'Interval2','theta_5'), ...
	    'INTERVAL2 (theta1=5)');
end

function testAnalysisResultsDoNotWriteGuiLog(testCase)
messages = {};
results = struct();
results.reference = struct('label','Reference (Nominal)','qi',[]);
planWorkflow.analysis.ResultLogger.log(@captureMessage,results);

verifyNotEmpty(testCase,messages);

    function captureMessage(message)
        messages{end + 1} = message;
    end
end

function testAnalysisResultUsesForwardDoseInsteadOfOptimizationCube(testCase)
forwardDoseCallCount = 0;
forwardDoseWeights = [];
context = struct();
context.forwardDoseForAnalysis = @forwardDose;

resultGUIOptimization = struct();
resultGUIOptimization.w = [1;2;3];
resultGUIOptimization.wUnsequenced = [3;2;1];
resultGUIOptimization.info = struct('iterations',9);
resultGUIOptimization.physicalDose = 0;

resultGUIAnalysis = ...
    planWorkflow.analysis.AnalysisService.createAnalysisResultGUI( ...
    context,struct(),{},struct(),struct(),resultGUIOptimization);

verifyEqual(testCase,forwardDoseCallCount,1);
verifyEqual(testCase,forwardDoseWeights,[1;2;3]);
verifyEqual(testCase,resultGUIAnalysis.physicalDose,42);
verifyEqual(testCase,resultGUIAnalysis.w,[1;2;3]);
verifyEqual(testCase,resultGUIAnalysis.wUnsequenced,[3;2;1]);
verifyEqual(testCase,resultGUIAnalysis.info.iterations,9);

    function resultGUI = forwardDose(~,~,~,~,w)
        forwardDoseCallCount = forwardDoseCallCount + 1;
        forwardDoseWeights = w;
        resultGUI = struct('physicalDose',42);
    end
end

function testAnalysisResultRequiresOptimizationWeights(testCase)
context = struct('forwardDoseForAnalysis',@(~,~,~,~,~) struct());

verifyError(testCase,@() ...
    planWorkflow.analysis.AnalysisService.createAnalysisResultGUI( ...
    context,struct(),{},struct(),struct(),struct()), ...
    'planWorkflow:analysis:MissingOptimizationWeights');
end

function testOptimizeStageContextDoesNotConfigureForwardDose(testCase)
config = baseEngineConfig(testCase);
data = struct();
data.ct = struct('numOfCtScen',1);
data.cst = {1};
dij = referenceDij();
data.stf = stfForBixels(3);
data.pln = struct('propStf',struct('numOfBeams',1));
data.optimizationInput = planWorkflow.precompute.OptimizationInput.build( ...
    data.ct,data.cst,data.pln,data.stf,dij,'nominal','test');

context = planWorkflow.stages.OptimizeStage.context( ...
    config,data,@passthroughTask,@(~) []);

verifyFalse(testCase,isfield(context,'forwardDoseForAnalysis'));
end

function testRobustAnalysisForwardInputsUseSingleNominalScenario(testCase)
planConfig = robustPlanConfig('robust_1','Robust','PTV', ...
    'none','wcScen',[5 10 5], ...
    robustVariantConfig('variant_1','Variant 1',1,1,1,1));
planConfig.scenario.ctActive = true;
planConfig.scenario.ctReferenceScenId = 2;
planConfig.scenario.rangeActive = true;
planConfig.scenario.rangeAbsSD = 1;
planConfig.scenario.rangeRelSD = 3.5;
planConfig.scenario.numOfRangeGridPoints = 3;

ct = struct('numOfCtScen',3);
pln = struct();
pln.propStf = struct('numOfBeams',1);
pln.propOpt = struct('scen4D','all','dij_interval',1, ...
    'dij_prob',2);
scenarioConfig = ...
    planWorkflow.config.RobustPlanConfig.matRadScenario( ...
    planConfig.scenario);
scenarioConfig = planWorkflow.config.ScenarioSpec.withBeamCount( ...
    scenarioConfig,pln);
pln.multScen = planWorkflow.scenario.createModel( ...
    ct,scenarioConfig.scen_mode,scenarioConfig,'optimization');

robustData = struct();
robustData.ct = ct;
robustData.cst = {1};
dij = struct('totalNumOfBixels',3);
robustData.stf = stfForBixels(3);
robustData.pln = pln;
robustData.planConfig = planConfig;
robustData.optimizationInput = ...
    planWorkflow.precompute.OptimizationInput.build( ...
    robustData.ct,robustData.cst,robustData.pln,robustData.stf, ...
    dij,'scenario','test');
variantResult = struct('variantId','variant_1','resultGUI', ...
    struct('w',ones(3,1)));

[stfAnalysis,plnNominal] = ...
    planWorkflow.analysis.NominalForwardInputs.robustVariant( ...
    robustData,variantResult);

scenarioIds = plnNominal.multScen.scenarioIds();
verifyEqual(testCase,stfAnalysis.totalNumOfBixels,3);
verifyEqual(testCase,numel(scenarioIds),1);
verifyEqual(testCase,plnNominal.multScen.getCtScenario(scenarioIds(1)),2);
verifyEqual(testCase,plnNominal.multScen.getSetupShift(scenarioIds(1)), ...
    [0 0 0]);
verifyFalse(testCase,isfield(plnNominal.propOpt,'scen4D'));
verifyFalse(testCase,isfield(plnNominal.propOpt,'dij_interval'));
verifyFalse(testCase,isfield(plnNominal.propOpt,'dij_prob'));
end

function testRobustAnalysisForwardInputsPreferOptimizationStf(testCase)
planConfig = robustPlanConfig('robust_1','Robust','PTV', ...
    'none','nomScen',[0 0 0], ...
    robustVariantConfig('variant_1','Variant 1',1,1,1,1));
robustData = struct();
robustData.ct = struct('numOfCtScen',1);
robustData.cst = {1};
dij = struct('totalNumOfBixels',7);
robustData.stf = stfForBixels(3);
robustData.stfNominal = stfForBixels(5);
optimizationStf = stfForBixels(7);
optimizationStf.source = 'optimization';
robustData.pln = struct('propStf',struct('numOfBeams',1), ...
    'multScen',matRad_NominalScenario());
robustData.planConfig = planConfig;
robustData.optimizationInput = ...
    planWorkflow.precompute.OptimizationInput.build( ...
    robustData.ct,robustData.cst,robustData.pln,optimizationStf, ...
    dij,'scenario','optimization');

[stfAnalysis,~] = ...
    planWorkflow.analysis.NominalForwardInputs.robustVariant( ...
    robustData,struct('variantId','variant_1','resultGUI', ...
    struct('w',ones(7,1))));

verifyEqual(testCase,stfAnalysis.totalNumOfBixels,7);
verifyEqual(testCase,stfAnalysis.source,'optimization');
end

function testRobustAnalysisForwardInputsRequireOptimizationStf(testCase)
planConfig = robustPlanConfig('robust_1','Robust','PTV', ...
    'none','nomScen',[0 0 0], ...
    robustVariantConfig('variant_1','Variant 1',1,1,1,1));
robustData = struct();
robustData.ct = struct('numOfCtScen',1);
robustData.stf = stfForBixels(3);
robustData.pln = struct('propStf',struct('numOfBeams',1), ...
    'multScen',matRad_NominalScenario());
robustData.planConfig = planConfig;

verifyError(testCase,@() ...
    planWorkflow.analysis.NominalForwardInputs.robustVariant( ...
    robustData,struct('variantId','variant_1','resultGUI', ...
    struct('w',ones(3,1)))), ...
    'planWorkflow:precompute:OptimizationInput:MissingOptimizationInput');
end

function testRobustAnalysisForwardInputsRejectWeightSteeringMismatch(testCase)
planConfig = robustPlanConfig('robust_1','Robust','PTV', ...
    'none','nomScen',[0 0 0], ...
    robustVariantConfig('variant_1','Variant 1',1,1,1,1));
robustData = struct();
robustData.ct = struct('numOfCtScen',1);
robustData.cst = {1};
dij = struct('totalNumOfBixels',7);
robustData.stf = stfForBixels(3);
robustData.pln = struct('propStf',struct('numOfBeams',1), ...
    'multScen',matRad_NominalScenario());
robustData.planConfig = planConfig;
robustData.optimizationInput = ...
    planWorkflow.precompute.OptimizationInput.build( ...
    robustData.ct,robustData.cst,robustData.pln,stfForBixels(7), ...
    dij,'scenario','test');

verifyError(testCase,@() ...
    planWorkflow.analysis.NominalForwardInputs.robustVariant( ...
    robustData,struct('variantId','variant_1','resultGUI', ...
    struct('w',ones(5,1)))), ...
    'planWorkflow:precompute:OptimizationInput:WeightSteeringMismatch');
end

function testIntervalPlanApplies4DOptimizationConfig(testCase)
config = baseEngineConfig(testCase);
plan = robustPlanConfig('intervalPlan','INTERVAL2','Interval2', ...
    'INTERVAL2','wcScen',[5 10 5], ...
    robustVariantConfig('theta_5','theta1=5',1,1,5,1));
plan.scenario.ctActive = true;
config.precompute.robustPlans = plan;
workflow = planWorkflowTest.EngineProbe(config);

robustData = struct();
robustData.planConfig = workflow.runConfig.precompute.robustPlans(1);
robustData.strategy = planWorkflow.robustness.IntervalStrategy('INTERVAL2');
robustData.ct = struct();
robustData.cst = {1};
robustData.stf = struct('totalNumOfBixels',1);
dij = struct('totalNumOfBixels',1);
robustData.pln = struct('propOpt',struct());
robustData.optimizationInput = ...
    planWorkflow.precompute.OptimizationInput.build( ...
    robustData.ct,robustData.cst,robustData.pln,robustData.stf, ...
    dij,'interval','test');

pln = workflow.planForRobustDataPlanIndexPublic(robustData,1);

verifyEqual(testCase,pln.propOpt.theta1,5);
verifyEqual(testCase,pln.propOpt.scen4D,'all');
end

function testDisabled4DOptimizationRemovesScen4DFromPlan(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2','Interval2','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_5','theta1=5',1,1,5,1));
config.precompute.robustPlans.scenario.ctActive = false;
config.precompute.robustPlans.optimization4D.enabled = true;
workflow = planWorkflowTest.EngineProbe(config);

robustData = struct();
robustData.planConfig = workflow.runConfig.precompute.robustPlans(1);
robustData.strategy = planWorkflow.robustness.IntervalStrategy('INTERVAL2');
robustData.ct = struct();
robustData.cst = {1};
robustData.stf = struct('totalNumOfBixels',1);
dij = struct('totalNumOfBixels',1);
robustData.pln = struct('propOpt',struct('scen4D','all'));
robustData.optimizationInput = ...
    planWorkflow.precompute.OptimizationInput.build( ...
    robustData.ct,robustData.cst,robustData.pln,robustData.stf, ...
    dij,'interval','test');

pln = workflow.planForRobustDataPlanIndexPublic(robustData,1);

verifyFalse(testCase,isfield(pln.propOpt,'scen4D'));
end

function testInactiveCtReferenceDataViewBuildsSingleCtInputs(testCase)
sourceData = struct();
sourceData.ct = multiScenarioCt(3);
sourceData.cst = multiScenarioCst(3);
sourceData.pln = struct();
scenario = planWorkflow.config.RobustPlanConfig.defaultScenario( ...
    'wcScen');
scenario.ctActive = false;
scenario.ctReferenceScenId = 2;
scenario.setupActive = true;
scenario.rangeActive = true;
scenario.rangeAbsSD = 1;
scenario.rangeRelSD = 3.5;
scenario.numOfRangeGridPoints = 3;

[viewData,scenarioForComputation,metadata] = ...
    planWorkflow.precompute.CtReferenceDataView.apply( ...
    sourceData,scenario);

verifyTrue(testCase,metadata.active);
verifyEqual(testCase,metadata.originalCtReferenceScenId,2);
verifyEqual(testCase,metadata.localCtReferenceScenId,1);
verifyEqual(testCase,viewData.ct.numOfCtScen,1);
verifyEqual(testCase,viewData.ct.refScen,1);
verifyFalse(testCase,isfield(viewData,'ctReferenceScenId'));
verifyFalse(testCase,isfield(viewData,'localCtReferenceScenId'));
verifyFalse(testCase,isfield(viewData.ct, ...
    'planWorkflowOriginalCtReferenceScenId'));
verifyEqual(testCase,viewData.ct.cube{1},sourceData.ct.cube{2});
verifyEqual(testCase,viewData.ct.cubeHU{1},sourceData.ct.cubeHU{2});
verifyEqual(testCase,viewData.cst{1,4}{1},'ct2-voi1');
verifyEqual(testCase,scenarioForComputation.ctReferenceScenId,1);

scenarioConfig = planWorkflow.config.RobustPlanConfig.matRadScenario( ...
    scenarioForComputation);
model = planWorkflow.scenario.createModel(viewData.ct, ...
    scenarioConfig.scen_mode,scenarioConfig,'optimization');

verifyEqual(testCase,model.ctScenProb,[1 1]);
scenarioIds = model.scenarioIds();
ctScenIds = arrayfun(@(id) model.getCtScenario(id),scenarioIds);
verifyEqual(testCase,unique(ctScenIds),1);
end

function testReferencePlanApplies4DOptimizationConfig(testCase)
config = baseEngineConfig(testCase);
config.precompute.reference.scenario.ctActive = true;
config.precompute.reference.optimization4D.enabled = false;
config.precompute.reference.optimization4D.scen4D = [1 3];
workflow = planWorkflowTest.EngineProbe(config);

pln = planWorkflow.optimization.PlanOptimizationService.apply4DConfig( ...
    struct('propOpt',struct()),workflow.runConfig.precompute.reference);

verifyEqual(testCase,pln.propOpt.scen4D,'all');
end

function testReferenceOptimization4DAffectsDoseCacheIdentity(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));
plnA = struct('propOpt',struct());
plnB = struct('propOpt',struct('scen4D','all'));

descriptorA = workflow.cacheDescriptorPublic('reference',plnA);
descriptorB = workflow.cacheDescriptorPublic('reference',plnB);

verifyEmpty(testCase,descriptorA.identity.optimization.scen4D);
verifyEqual(testCase,descriptorB.identity.optimization.scen4D,'all');
verifyNotEqual(testCase,descriptorA.identityHash, ...
    descriptorB.identityHash);
end

function testIntervalCacheContextIncludesOptimization4DScenario(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'interval3_001';
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL3','Interval3','INTERVAL3','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
workflow = planWorkflowTest.EngineProbe(config);

scenarioModel = matRad_WorstCaseScenarios();
scenarioModel.scenarioDimensionActive = {'ct','setup'};
scenarioModel.shiftSD = [1 2 3];
scenarioModel.wcSigma = 1;

robustDataA = intervalRobustData(workflow);
robustDataA.pln.multScen = scenarioModel;
robustDataA.pln.propOpt = struct();
robustDataA.stf = stfForBixels(3);
robustDataB = robustDataA;
robustDataB.pln.propOpt.scen4D = 'all';

contextA = workflow.intervalCacheContextPublic(robustDataA);
contextB = workflow.intervalCacheContextPublic(robustDataB);

verifyEqual(testCase,contextA.interval.scen4D,1);
verifyEqual(testCase,contextB.interval.scen4D,'all');
intervalTagA = workflow.intervalDoseCacheTagPublic(robustDataA);
intervalTagB = workflow.intervalDoseCacheTagPublic(robustDataB);
verifyNotEqual(testCase, ...
    workflow.cacheDescriptorPublic(intervalTagA, ...
    robustDataA.pln,contextA).identityHash, ...
    workflow.cacheDescriptorPublic(intervalTagB, ...
    robustDataB.pln,contextB).identityHash);
end

function testInterval3DoseConfigEnablesParallelWithoutCacheKey(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'interval3_001';
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL3','Interval3','INTERVAL3','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
workflow = planWorkflowTest.EngineProbe(config);

robustData = intervalRobustData(workflow);
robustData.ct = struct('refScen',1);
robustData.cst = cell(1,6);
robustData.cst{1,2} = 'PTV';
robustData.objectiveInfo = struct( ...
    'ixTarget',1, ...
    'robustOarNames',{{'Rectum'}});
robustData.pln = struct('propOpt',struct());

intervalConfig = planWorkflow.precompute.IntervalDoseInfluence.doseConfig( ...
    workflow.intervalDoseInfluenceContext(),robustData);
cacheContext = workflow.intervalCacheContextPublic(robustData);

verifyTrue(testCase,intervalConfig.UseParallel);
verifyTrue(testCase,isfield(intervalConfig,'parallelOptions'));
verifyEqual(testCase, ...
    intervalConfig.parallelOptions.minWorkerMemoryBytes,4 * 1024^3);
verifyFalse(testCase,isfield(cacheContext.interval,'UseParallel'));
verifyFalse(testCase,isfield(cacheContext.interval,'parallelOptions'));

robustData.planConfig.robustnessOptions.radiusMode = 'extreme';
intervalConfig = planWorkflow.precompute.IntervalDoseInfluence.doseConfig( ...
    workflow.intervalDoseInfluenceContext(),robustData);
cacheContext = workflow.intervalCacheContextPublic(robustData);

verifyEqual(testCase,intervalConfig.RadiusMode,'extreme');
verifyFalse(testCase,isfield(intervalConfig,'KMode'));
verifyFalse(testCase,isfield(cacheContext.interval,'KMode'));
end

function testScenarioBatchDoseConfigCarriesSecondPassOptions(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'interval2_001';
cacheRoot = fullfile(tempdir,'planWorkflow_interval_cache');
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2','Interval2','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
config.precompute.robustPlans.dosePrecompute.useScenarioBatch = true;
config.precompute.robustPlans.dosePrecompute.SecondPassStrategy = 'recompute';
config.precompute.robustPlans.dosePrecompute.KeepCache = true;
config.precompute.robustPlans.dosePrecompute.CacheRoot = cacheRoot;
workflow = planWorkflowTest.EngineProbe(config);

robustData = intervalRobustData(workflow);
robustData.ct = struct('refScen',1);
robustData.cst = cell(1,6);
robustData.cst{1,2} = 'PTV';
robustData.objectiveInfo = struct( ...
    'ixTarget',1, ...
    'robustOarNames',{{'Rectum'}});
robustData.pln = struct('propOpt',struct());

legacyConfig = planWorkflow.precompute.IntervalDoseInfluence.doseConfig( ...
    workflow.intervalDoseInfluenceContext(),robustData);
scenarioBatchConfig = planWorkflow.precompute.IntervalDoseInfluence.doseConfig( ...
    workflow.intervalDoseInfluenceContext(),robustData,true);

verifyFalse(testCase,isfield(legacyConfig,'SecondPassStrategy'));
verifyFalse(testCase,isfield(legacyConfig,'UseParallel'));
verifyEqual(testCase,scenarioBatchConfig.SecondPassStrategy,'recompute');
verifyTrue(testCase,scenarioBatchConfig.UseParallel);
verifyTrue(testCase,isfield(scenarioBatchConfig,'parallelOptions'));
verifyEqual(testCase, ...
    scenarioBatchConfig.parallelOptions.minWorkerMemoryBytes,4 * 1024^3);
verifyTrue(testCase,scenarioBatchConfig.KeepCache);
verifyEqual(testCase,scenarioBatchConfig.CacheRoot,cacheRoot);
end

function testProb2ScenarioBatchDoseConfigCarriesSecondPassOptions(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'PROB2_001';
config.precompute.robustPlans = robustPlanConfig( ...
    'probPlan','PROB2','MeanVariance','PROB2','wcScen', ...
    [5 10 5],robustVariantConfig('variant_1','Variant 1',1,1,1,1));
config.precompute.robustPlans.dosePrecompute.useScenarioBatch = true;
config.precompute.robustPlans.dosePrecompute.KeepCache = true;
workflow = planWorkflowTest.EngineProbe(config);

robustData = struct();
robustData.planConfig = workflow.runConfig.precompute.robustPlans(1);
robustData.strategy = planWorkflow.robustness.Prob2Strategy();
robustData.ct = struct('refScen',1);
robustData.cst = cell(1,6);
robustData.cst{1,2} = 'PTV';
robustData.objectiveInfo = struct( ...
    'ixTarget',1, ...
    'robustOarNames',{{'Rectum'}});
robustData.pln = struct('propOpt',struct());

probConfig = planWorkflow.precompute.ProbDoseInfluence.doseConfig( ...
    workflow.intervalDoseInfluenceContext(),robustData,true);

verifyEqual(testCase,probConfig.SecondPassStrategy,'disk');
verifyTrue(testCase,probConfig.UseParallel);
verifyTrue(testCase,isfield(probConfig,'parallelOptions'));
verifyEqual(testCase, ...
    probConfig.parallelOptions.minWorkerMemoryBytes,4 * 1024^3);
verifyTrue(testCase,probConfig.KeepCache);
verifyFalse(testCase,isfield(probConfig,'CacheRoot'));
end

function testDoseParallelismUsesEngineCapabilityAndResources(testCase)
pln = parallelScenarioPlan( ...
    DoseEngines.matRad_PhotonPencilBeamSVDEngine(),3);

pln = planWorkflow.plan.Plan.applyDoseParallelism(pln);

verifyFalse(testCase,pln.propDoseCalc.UseParallel);
verifyEqual(testCase,pln.propDoseCalc.parallelOptions,struct());

pln = parallelScenarioPlan( ...
    DoseEngines.matRad_ParticleHongPencilBeamEngine(),3);
runConfig.resources = planWorkflow.config.Resources.defaults();
runConfig.resources.doseCalculation.workerUpperBound = 4;
pln = planWorkflow.plan.Plan.applyDoseParallelism(pln,runConfig);

if exist('matRad_supportsParallelScenarioDij','file') == 2
    verifyTrue(testCase,pln.propDoseCalc.UseParallel);
    verifyEqual(testCase,pln.propDoseCalc.parallelOptions.workerUpperBound,4);
    verifyEqual(testCase, ...
        pln.propDoseCalc.parallelOptions.minWorkerMemoryBytes,4 * 1024^3);
else
    verifyFalse(testCase,pln.propDoseCalc.UseParallel);
    verifyEqual(testCase,pln.propDoseCalc.parallelOptions,struct());
end
end

function testReferenceCompactCacheIdentityUsesReferencePlan(testCase)
config = baseEngineConfig(testCase);
config.precompute.reference.robustnessMode = 'PROB2';
pln = struct('propOpt',struct());
cacheContext = struct('prob',struct('mode','PROB2'));

descriptor = planWorkflow.cache.CacheIdentity.build( ...
    config,'prob_reference',pln,cacheContext);
metadata = planWorkflow.cache.CacheIdentity.artifactMetadata( ...
    config,'prob_reference');

verifyEqual(testCase,descriptor.artifact.kind,'prob');
verifyEqual(testCase,descriptor.artifact.planId,'reference');
verifyEqual(testCase,descriptor.artifact.robustnessMode,'PROB2');
verifyEqual(testCase,metadata.planId,'reference');
verifyEqual(testCase,metadata.objectiveSetName,'reference');
end

function testPlanTaskResourceDetailsIncludeDoseInfluenceAndIterations(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));

dij = referenceDij();
referenceTiming = planWorkflow.performance.PrecomputeTiming.single( ...
    10,'reference','Reference','dij',[]);
referenceSize = planWorkflow.performance.PrecomputeSize.single( ...
    10,'reference','Reference','dij',[]);
detail = workflow.planTaskResourceDetailPublic( ...
    'precompute','reference','Reference','doseInfluence','','', ...
    {dij,referenceTiming,referenceSize});
detailData = jsondecode(detail);
verifyEqual(testCase,detailData.dij.numberOfScenarios,1);
verifyEqual(testCase,detailData.dij.matrix.dimensions,'1x3');
verifyGreaterThan(testCase,detailData.dij.matrix.size.bytes,0);
verifyGreaterThan(testCase,detailData.dij.size.bytes,0);
verifyEqual(testCase,detailData.dijPrecomputingTiming.totalTimeSeconds, ...
    10);
verifyEqual(testCase,detailData.dijPrecomputingTiming.relativeTime,1);
verifyEqual(testCase,detailData.dijPrecomputingSize.totalSizeBytes,10);
verifyEqual(testCase,detailData.dijPrecomputingSize.relativeSize,1);

robustData = struct();
robustData.dijRobust = referenceDij();
robustData.dij_interval = intervalDij(3);
robustData.dijPrecomputingTiming = ...
    sampleDijPrecomputingTiming('dij_interval');
robustData.dijPrecomputingSize = ...
    sampleDijPrecomputingSize('dij_interval');
detail = workflow.planTaskResourceDetailPublic( ...
    'precompute','robust','INTERVAL2','intervalDoseInfluence', ...
    'interval2','',{robustData});
detailData = jsondecode(detail);
verifyEqual(testCase,detailData.dij_robust.matrix.dimensions,'1x3');
verifyEqual(testCase,detailData.dij_interval.numberOfScenarios,2);
verifyEqual(testCase,detailData.dij_interval.center.dimensions,'2x3');
verifyEqual(testCase,detailData.dij_interval.radius.dimensions,'2x3');
verifyEqual(testCase,detailData.dij_interval.radiusComponents.count,2);
verifyFalse(testCase, ...
    isfield(detailData.dij_interval.radiusComponents,'components'));
verifyEqual(testCase, ...
    detailData.dij_interval.radiusComponents.representation, ...
    'OARRadiusFactors');
verifyEqual(testCase, ...
    detailData.dij_interval.radiusComponents.memoryModel, ...
    'retainedOARRadiusFactors');
verifyEqual(testCase, ...
    detailData.dij_interval.radiusComponents.OARRadiusFactor.count,2);
verifyEqual(testCase, ...
    detailData.dij_interval.radiusComponents.OARRadiusFactor.totalRows,6);
verifyEqual(testCase, ...
    detailData.dij_interval.radiusComponents.OARRadiusFactor.totalColumns,3);
verifyEqual(testCase, ...
    detailData.dij_interval.radiusComponents.OARRadiusRank.sum,3);
verifyGreaterThan(testCase, ...
    detailData.dij_interval.radiusComponents.totalSize.bytes,0);
verifyGreaterThan(testCase,detailData.dij_interval.totalSize.bytes,0);
verifyEqual(testCase,detailData.dijPrecomputingTiming.relativeTime,3);
verifyEqual(testCase,detailData.dijPrecomputingSize.relativeSize,3);
verifyFalse(testCase,contains(jsonencode(detailData.dij_interval), ...
    ['OAR covariance/' 'SVD estimated memory']));

probData = struct();
probData.dij_prob = probDij(3);
probData.dijPrecomputingTiming = sampleDijPrecomputingTiming('dij_prob');
probData.dijPrecomputingSize = sampleDijPrecomputingSize('dij_prob');
detail = workflow.planTaskResourceDetailPublic( ...
    'precompute','robust','PROB2','probDoseInfluence', ...
    'prob','',{probData});
detailData = jsondecode(detail);
verifyEqual(testCase,detailData.dij_prob.numberOfScenarios,2);
verifyEqual(testCase,detailData.dij_prob.expected.dimensions,'2x3');
verifyEqual(testCase, ...
    detailData.dij_prob.omegaComponents.representation, ...
    'probabilisticOmegaByStructure');
verifyEqual(testCase, ...
    detailData.dij_prob.omegaComponents.Omega.count,2);
verifyEqual(testCase, ...
    detailData.dij_prob.omegaComponents.Omega.totalRows,6);
verifyEqual(testCase, ...
    detailData.dij_prob.omegaComponents.Omega.totalColumns,6);
verifyEqual(testCase, ...
    detailData.dij_prob.omegaComponents.voiSubIx.sum,6);
verifyEqual(testCase,detailData.dijPrecomputingTiming.relativeTime,3);
verifyEqual(testCase,detailData.dijPrecomputingSize.relativeSize,3);

resultGUI = struct();
resultGUI.info = struct('iterations',17);
detail = workflow.planTaskResourceDetailPublic( ...
    'optimize','robust','INTERVAL2 (theta1=5)', ...
    'fluenceOptimization','interval2','theta_5',{resultGUI});
detailData = jsondecode(detail);
verifyEqual(testCase,detailData.iterations,17);
end

function testCacheRejectsEmptyActiveScenarioDoseMatrices(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));
scenarioModel = matRad_WorstCaseScenarios();
scenarioModel.scenarioDimensionActive = {'ct','setup'};
scenarioModel.shiftSD = [1 2 3];
scenarioModel.wcSigma = 1;
pln.multScen = scenarioModel;

cached.cacheMetadata = workflow.cacheMetadataPublic('reference',pln);
cached.dij.numOfScenarios = scenarioModel.numScenarios();
cached.dij.physicalDose = cell(size(scenarioModel.scenMask));
for i = 1:numel(cached.dij.physicalDose)
    cached.dij.physicalDose{i} = sparse(1,1,1);
end

verifyTrue(testCase,workflow.isCacheCompatiblePublic(cached,pln));

cached.dij.physicalDose{2} = sparse(1,1);

verifyFalse(testCase,workflow.isCacheCompatiblePublic(cached,pln));
end

function testCachedIntervalDijCanOptimizeWithoutRobustDij(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2','Interval2','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
config.precompute.robustPlans.hasNominalObjectives = false;
config.precompute.robustPlans.requiresNominalDij = false;
config.precompute.robustPlans.requiresIntervalDij = true;
config.dose_pulling2 = false;
workflow = planWorkflowTest.EngineProbe(config);
workflow.data.optimizationInput.dij = referenceDij();

scenarioModel = matRad_WorstCaseScenarios();
scenarioModel.scenarioDimensionActive = {'ct','setup'};
scenarioModel.shiftSD = [1 2 3];
scenarioModel.wcSigma = 1;

robustData = intervalRobustData(workflow);
robustData.ct = struct('numOfCtScen',1);
robustData.cst = {1};
robustData.pln.multScen = scenarioModel;
robustData.pln.propOpt = struct();
robustData.stf = stfForBixels(workflow.data.optimizationInput.dij.totalNumOfBixels);

cacheContext = workflow.intervalCacheContextPublic(robustData);
intervalTag = workflow.intervalDoseCacheTagPublic(robustData);
cacheFile = workflow.cacheFilePublic(intervalTag,robustData.pln, ...
    cacheContext);
mkdir(fileparts(cacheFile));
dij_interval = intervalDij(workflow.data.optimizationInput.dij.totalNumOfBixels);
dijIntervalContext = intervalDijContext(dij_interval); %#ok<NASGU>
cacheMetadata = workflow.cacheMetadataPublic( ...
    intervalTag,robustData.pln,cacheContext);
cacheMetadata.intervalMode = 'INTERVAL2';
cacheMetadata.scenarioFingerprint = ...
    planWorkflow.cache.CacheIdentity.scenarioFingerprint(scenarioModel);
cacheMetadata.dijPrecomputingTiming = ...
    sampleDijPrecomputingTiming('dij_interval');
cacheMetadata.dijPrecomputingSize = ...
    sampleDijPrecomputingSize('dij_interval');
builtin('save',cacheFile,'dij_interval','dijIntervalContext', ...
    'cacheMetadata','-v7.3');

[cacheHit,robustData] = workflow.loadCachedIntervalDoseInfluencePublic( ...
    robustData);
robustData = workflow.useIntervalDijForOptimizationPublic( ...
    robustData);

verifyTrue(testCase,cacheHit);
verifyTrue(testCase,isfield(robustData,'dij_interval'));
verifyTrue(testCase,isfield(robustData,'dijPrecomputingTiming'));
verifyTrue(testCase,isfield(robustData,'dijPrecomputingSize'));
verifyEqual(testCase,robustData.dijPrecomputingTiming.relativeTime,3);
verifyEqual(testCase,robustData.dijPrecomputingSize.relativeSize,3);
verifyFalse(testCase,isfield(robustData.pln.propOpt,'dij_interval'));
verifyTrue(testCase,isfield(robustData,'plnForOptimization'));
verifyEqual(testCase,robustData.pln.multScen.numScenarios(), ...
    scenarioModel.numScenarios());
verifyEqual(testCase,robustData.plnForOptimization.multScen.numScenarios(),1);
verifyEqual(testCase, ...
    robustData.plnForOptimization.multScen.getDijScenarioIndex(1),1);
verifyFalse(testCase,isfield( ...
    robustData.plnForOptimization.propOpt,'dij_interval'));
verifyFalse(testCase,isfield(robustData,'robustDijWasLoaded'));
verifyTrue(testCase,robustData.usesIntervalDijForOptimization);
verifyEqual(testCase,robustData.dijIntervalContext.totalNumOfBixels, ...
    workflow.data.optimizationInput.dij.totalNumOfBixels);
verifyEqual(testCase,robustData.dijIntervalContext.numOfScenarios,1);
verifyEqual(testCase,robustData.dijIntervalContext.physicalDose{1}, ...
    robustData.dij_interval.center);

robustData.optimizationInput = ...
    planWorkflow.precompute.OptimizationInput.build( ...
    robustData.ct,robustData.cst, ...
    planWorkflow.precompute.IntervalDoseInfluence.optimizationPlan( ...
    robustData),robustData.stf,robustData.dijIntervalContext, ...
    'interval','test');
planForOptimization = workflow.planForRobustDataPlanIndexPublic( ...
    robustData,1);
verifyEqual(testCase,planForOptimization.multScen.numScenarios(),1);
verifyEqual(testCase,planForOptimization.multScen.getDijScenarioIndex(1),1);
verifyTrue(testCase,isfield(planForOptimization.propOpt,'dij_interval'));
verifyEqual(testCase,planForOptimization.propOpt.dij_interval, ...
    robustData.dij_interval);
end

function testCachedIntervalDijWithInvalidPrecomputeSizeIsRejected(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2','Interval2','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
config.precompute.robustPlans.requiresIntervalDij = true;
workflow = planWorkflowTest.EngineProbe(config);
workflow.data.optimizationInput.dij = referenceDij();

scenarioModel = matRad_WorstCaseScenarios();
scenarioModel.scenarioDimensionActive = {'ct','setup'};
scenarioModel.shiftSD = [1 2 3];
scenarioModel.wcSigma = 1;

robustData = intervalRobustData(workflow);
robustData.pln.multScen = scenarioModel;
robustData.pln.propOpt = struct();
robustData.stf = stfForBixels(workflow.data.optimizationInput.dij.totalNumOfBixels);

cacheContext = workflow.intervalCacheContextPublic(robustData);
intervalTag = workflow.intervalDoseCacheTagPublic(robustData);
cacheFile = workflow.cacheFilePublic(intervalTag,robustData.pln, ...
    cacheContext);
mkdir(fileparts(cacheFile));
dij_interval = intervalDij(workflow.data.optimizationInput.dij.totalNumOfBixels);
dijIntervalContext = intervalDijContext(dij_interval); %#ok<NASGU>
cacheMetadata = workflow.cacheMetadataPublic( ...
    intervalTag,robustData.pln,cacheContext);
cacheMetadata.intervalMode = 'INTERVAL2';
cacheMetadata.scenarioFingerprint = ...
    planWorkflow.cache.CacheIdentity.scenarioFingerprint(scenarioModel);
cacheMetadata.dijPrecomputingTiming = ...
    sampleDijPrecomputingTiming('dij_interval');
cacheMetadata.dijPrecomputingSize = struct( ...
    'schemaVersion',1, ...
    'totalSizeBytes',NaN, ...
    'relativeSize',NaN);
builtin('save',cacheFile,'dij_interval','dijIntervalContext', ...
    'cacheMetadata','-v7.3');

[cacheHit,robustData] = workflow.loadCachedIntervalDoseInfluencePublic( ...
    robustData);

verifyFalse(testCase,cacheHit);
verifyFalse(testCase,isfield(robustData,'dijPrecomputingSize'));
end

function testCachedProbDijCanOptimizeWithoutRobustDij(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'PROB2_001';
config.precompute.robustPlans = robustPlanConfig( ...
    'probPlan','PROB2','MeanVariance','PROB2','wcScen', ...
    [5 10 5],robustVariantConfig('variant_1','Variant 1',1,1,1,1));
config.precompute.robustPlans.hasNominalObjectives = false;
config.precompute.robustPlans.requiresNominalDij = false;
config.precompute.robustPlans.requiresScenarioDij = false;
config.precompute.robustPlans.requiresIntervalDij = false;
config.precompute.robustPlans.requiresProbDij = true;
config.dose_pulling2 = false;
workflow = planWorkflowTest.EngineProbe(config);
workflow.data.optimizationInput.dij = referenceDij();

scenarioModel = matRad_WorstCaseScenarios();
scenarioModel.scenarioDimensionActive = {'ct','setup'};
scenarioModel.shiftSD = [1 2 3];
scenarioModel.wcSigma = 1;

robustData = struct();
robustData.planConfig = workflow.runConfig.precompute.robustPlans(1);
robustData.planConfig.hasNominalObjectives = false;
robustData.planConfig.requiresNominalDij = false;
robustData.strategy = planWorkflow.robustness.Prob2Strategy();
robustData.ct = struct('numOfCtScen',1);
robustData.cst = {1};
robustData.pln.multScen = scenarioModel;
robustData.pln.propOpt = struct();
robustData.stf = stfForBixels(workflow.data.optimizationInput.dij.totalNumOfBixels);

cacheContext = workflow.probCacheContextPublic(robustData);
probTag = workflow.probDoseCacheTagPublic(robustData);
cacheFile = workflow.cacheFilePublic(probTag,robustData.pln, ...
    cacheContext);
mkdir(fileparts(cacheFile));
dij_prob = probDij(workflow.data.optimizationInput.dij.totalNumOfBixels);
dijProbContext = probDijContext(dij_prob); %#ok<NASGU>
cacheMetadata = workflow.cacheMetadataPublic( ...
    probTag,robustData.pln,cacheContext);
cacheMetadata.probabilisticMode = 'PROB';
cacheMetadata.scenarioFingerprint = ...
    planWorkflow.cache.CacheIdentity.scenarioFingerprint(scenarioModel);
cacheMetadata.dijPrecomputingTiming = ...
    sampleDijPrecomputingTiming('dij_prob');
cacheMetadata.dijPrecomputingSize = ...
    sampleDijPrecomputingSize('dij_prob');
builtin('save',cacheFile,'dij_prob','dijProbContext', ...
    'cacheMetadata','-v7.3');

[cacheHit,robustData] = workflow.loadCachedProbDoseInfluencePublic( ...
    robustData);
robustData = workflow.useProbDijForOptimizationPublic(robustData);

verifyTrue(testCase,cacheHit);
verifyTrue(testCase,isfield(robustData,'dij_prob'));
verifyTrue(testCase,isfield(robustData,'dijPrecomputingTiming'));
verifyTrue(testCase,isfield(robustData,'dijPrecomputingSize'));
verifyEqual(testCase,robustData.dijPrecomputingTiming.relativeTime,3);
verifyEqual(testCase,robustData.dijPrecomputingSize.relativeSize,3);
verifyFalse(testCase,isfield(robustData.pln.propOpt,'dij_prob'));
verifyTrue(testCase,isfield(robustData,'plnForOptimization'));
verifyEqual(testCase,robustData.pln.multScen.numScenarios(), ...
    scenarioModel.numScenarios());
verifyEqual(testCase,robustData.dijProbContext.totalNumOfBixels, ...
    workflow.data.optimizationInput.dij.totalNumOfBixels);
verifyEqual(testCase,robustData.dijProbContext.physicalDose{1}, ...
    robustData.dij_prob.expected);
verifyTrue(testCase,robustData.usesProbDijForOptimization);

robustData.optimizationInput = ...
    planWorkflow.precompute.OptimizationInput.build( ...
    robustData.ct,robustData.cst, ...
    planWorkflow.precompute.ProbDoseInfluence.optimizationPlan( ...
    robustData),robustData.stf,robustData.dijProbContext, ...
    'prob','test');
planForOptimization = workflow.planForRobustDataPlanIndexPublic( ...
    robustData,1);
verifyTrue(testCase,isfield(planForOptimization.propOpt,'dij_prob'));
verifyEqual(testCase,planForOptimization.propOpt.dij_prob, ...
    robustData.dij_prob);
end

function testCachedProbDijUsesContextNominalDij(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'PROB2_001';
config.precompute.robustPlans = robustPlanConfig( ...
    'probPlan','PROB2','MeanVariance','PROB2','wcScen', ...
    [5 10 5],robustVariantConfig('variant_1','Variant 1',1,1,1,1));
config.precompute.robustPlans.hasNominalObjectives = true;
config.precompute.robustPlans.requiresNominalDij = true;
config.precompute.robustPlans.requiresScenarioDij = false;
config.precompute.robustPlans.requiresIntervalDij = false;
config.precompute.robustPlans.requiresProbDij = true;
workflow = planWorkflowTest.EngineProbe(config);
workflow.data.optimizationInput.dij = referenceDij();

scenarioModel = matRad_WorstCaseScenarios();
scenarioModel.scenarioDimensionActive = {'ct','setup'};
scenarioModel.shiftSD = [1 2 3];
scenarioModel.wcSigma = 1;

robustData = struct();
robustData.planConfig = workflow.runConfig.precompute.robustPlans(1);
robustData.strategy = planWorkflow.robustness.Prob2Strategy();
robustData.pln.multScen = scenarioModel;
robustData.pln.propOpt = struct();
robustData.stf = stfForBixels(workflow.data.optimizationInput.dij.totalNumOfBixels);

cacheContext = workflow.probCacheContextPublic(robustData);
probTag = workflow.probDoseCacheTagPublic(robustData);
cacheFile = workflow.cacheFilePublic(probTag,robustData.pln, ...
    cacheContext);
mkdir(fileparts(cacheFile));
dij_prob = probDij(workflow.data.optimizationInput.dij.totalNumOfBixels);
dijProbContext = probDijContext(dij_prob);
dijProbContext.physicalDose = {sparse(1,1,5, ...
    size(dij_prob.expected,1),size(dij_prob.expected,2))}; %#ok<NASGU>
cacheMetadata = workflow.cacheMetadataPublic( ...
    probTag,robustData.pln,cacheContext);
cacheMetadata.probabilisticMode = 'PROB';
cacheMetadata.scenarioFingerprint = ...
    planWorkflow.cache.CacheIdentity.scenarioFingerprint(scenarioModel);
cacheMetadata.dijPrecomputingTiming = ...
    sampleDijPrecomputingTiming('dij_prob');
cacheMetadata.dijPrecomputingSize = ...
    sampleDijPrecomputingSize('dij_prob');
builtin('save',cacheFile,'dij_prob','dijProbContext', ...
    'cacheMetadata','-v7.3');

[cacheHit,robustData] = workflow.loadCachedProbDoseInfluencePublic( ...
    robustData);

verifyTrue(testCase,cacheHit);
verifyTrue(testCase,isfield(robustData,'dijNominal'));
verifyEqual(testCase,robustData.dijNominal,robustData.dijProbContext);
verifyFalse(testCase,isfield(robustData.plnNominal.propOpt, ...
    'dij_prob'));
end

function testCachedIntervalDijUsesContextNominalDij(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2','Interval2','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
config.precompute.robustPlans.hasNominalObjectives = true;
config.precompute.robustPlans.requiresNominalDij = true;
config.precompute.robustPlans.requiresIntervalDij = true;
workflow = planWorkflowTest.EngineProbe(config);
workflow.data.optimizationInput.dij = referenceDij();

scenarioModel = matRad_WorstCaseScenarios();
scenarioModel.scenarioDimensionActive = {'ct','setup'};
scenarioModel.shiftSD = [1 2 3];
scenarioModel.wcSigma = 1;

robustData = intervalRobustData(workflow);
robustData.ct = struct('numOfCtScen',1);
robustData.cst = {1};
robustData.pln.multScen = scenarioModel;
robustData.pln.propOpt = struct();
robustData.stf = stfForBixels(workflow.data.optimizationInput.dij.totalNumOfBixels);

cacheContext = workflow.intervalCacheContextPublic(robustData);
intervalTag = workflow.intervalDoseCacheTagPublic(robustData);
cacheFile = workflow.cacheFilePublic(intervalTag,robustData.pln, ...
    cacheContext);
mkdir(fileparts(cacheFile));
dij_interval = intervalDij(workflow.data.optimizationInput.dij.totalNumOfBixels);
dijIntervalContext = intervalDijContext(dij_interval);
dijIntervalContext.physicalDose = {sparse(1,1,7, ...
    size(dij_interval.center,1),size(dij_interval.center,2))}; %#ok<NASGU>
cacheMetadata = workflow.cacheMetadataPublic( ...
    intervalTag,robustData.pln,cacheContext);
cacheMetadata.intervalMode = 'INTERVAL2';
cacheMetadata.scenarioFingerprint = ...
    planWorkflow.cache.CacheIdentity.scenarioFingerprint(scenarioModel);
cacheMetadata.dijPrecomputingTiming = ...
    sampleDijPrecomputingTiming('dij_interval');
cacheMetadata.dijPrecomputingSize = ...
    sampleDijPrecomputingSize('dij_interval');
builtin('save',cacheFile,'dij_interval','dijIntervalContext', ...
    'cacheMetadata','-v7.3');

[cacheHit,robustData] = workflow.loadCachedIntervalDoseInfluencePublic( ...
    robustData);

verifyTrue(testCase,cacheHit);
verifyTrue(testCase,isfield(robustData,'dijNominal'));
verifyTrue(testCase,isfield(robustData,'dijPrecomputingTiming'));
verifyEqual(testCase,robustData.dijPrecomputingTiming.relativeTime,3);
verifyEqual(testCase,robustData.dijNominal.totalNumOfBixels, ...
    size(robustData.dij_interval.center,2));
verifyEqual(testCase,robustData.dijNominal, ...
    robustData.dijIntervalContext);
verifyFalse(testCase,isfield(robustData.pln.propOpt,'dij_interval'));
verifyFalse(testCase,isfield(robustData.plnNominal.propOpt, ...
    'dij_interval'));

robustData.plnForOptimization = robustData.plnNominal;
planWithIntervalPayload = ...
    planWorkflow.precompute.IntervalDoseInfluence.optimizationPlan( ...
    robustData);
robustData = rmfield(robustData,'plnForOptimization');
robustData.optimizationInput = ...
    planWorkflow.precompute.OptimizationInput.build( ...
    robustData.ct,robustData.cst,planWithIntervalPayload, ...
    robustData.stf,robustData.dijNominal,'nominal', ...
    'interval-nominal');
planForOptimization = workflow.planForRobustDataPlanIndexPublic( ...
    robustData,1);
verifyTrue(testCase,isfield(planForOptimization.propOpt,'dij_interval'));
verifyEqual(testCase,planForOptimization.propOpt.dij_interval, ...
    robustData.dij_interval);
verifyEqual(testCase,robustData.optimizationInput.dij.physicalDose{1}, ...
    robustData.dijNominal.physicalDose{1});
end

function testNominalOptimizationSelectionRequiresPlanSpecificPlan(testCase)
robustData = nominalSelectionData('robust_1','nominal-plan', ...
    'none',false);

robustData = ...
    planWorkflow.stages.PrecomputeStage.selectOptimizationDoseInfluence( ...
    robustData);

verifyEqual(testCase,robustData.optimizationInput.dij.source, ...
    'nominal-plan');
verifyEqual(testCase,robustData.optimizationInput.pln.source, ...
    'nominal-plan');
verifyEqual(testCase,robustData.optimizationInput.stf.source, ...
    'nominal-plan-stf');
verifyEqual(testCase,robustData.optimizationInput.dijKind,'nominal');

missingDij = nominalSelectionData('robust_1','nominal-plan', ...
    'none',false);
missingDij = rmfield(missingDij,'dijNominal');
verifyError(testCase,@() ...
    planWorkflow.stages.PrecomputeStage.selectOptimizationDoseInfluence( ...
    missingDij), ...
    'planWorkflow:stages:PrecomputeStage:MissingNominalDij');

missingPlan = nominalSelectionData('robust_1','nominal-plan', ...
    'none',false);
missingPlan = rmfield(missingPlan,'plnNominal');
verifyError(testCase,@() ...
    planWorkflow.stages.PrecomputeStage.selectOptimizationDoseInfluence( ...
    missingPlan), ...
    'planWorkflow:stages:PrecomputeStage:MissingNominalPlan');
end

function testScenarioOptimizationDoesNotRequireNominalDij(testCase)
robustData = nominalSelectionData('robust_1','nominal-plan', ...
    'COWC',false);
robustData.planConfig.hasNominalObjectives = true;
robustData.planConfig.requiresNominalDij = false;
robustData.planConfig.requiresScenarioDij = true;
robustData = rmfield(robustData,{'dijNominal','plnNominal', ...
    'stfNominal'});
robustData.dijRobust = struct('source','scenario-plan');

robustData = ...
    planWorkflow.stages.PrecomputeStage.selectOptimizationDoseInfluence( ...
    robustData);

verifyEqual(testCase,robustData.optimizationInput.dij.source, ...
    'scenario-plan');
verifyEqual(testCase,robustData.optimizationInput.pln.source, ...
    'robust_1-robust-plan');
verifyEqual(testCase,robustData.optimizationInput.stf.source, ...
    'robust_1-robust-stf');
verifyEqual(testCase,robustData.optimizationInput.dijKind,'scenario');
verifyFalse(testCase,isfield(robustData,'dijNominal'));
end

function testNominalAndIntervalSelectionKeepPlanSpecificDij(testCase)
referenceDij = struct('source','reference');
nominalData = nominalSelectionData('robust_1','nominal-plan', ...
    'none',false);
intervalData = nominalSelectionData('robust_2','interval-plan', ...
    'INTERVAL2',true);
probData = nominalSelectionData('robust_3','prob-nominal-plan', ...
    'PROB2',false,true);

nominalData = ...
    planWorkflow.stages.PrecomputeStage.selectOptimizationDoseInfluence( ...
    nominalData);
intervalData = ...
    planWorkflow.stages.PrecomputeStage.selectOptimizationDoseInfluence( ...
    intervalData);
probData = ...
    planWorkflow.stages.PrecomputeStage.selectOptimizationDoseInfluence( ...
    probData);

verifyEqual(testCase,nominalData.optimizationInput.dij.source, ...
    'nominal-plan');
verifyEqual(testCase,intervalData.optimizationInput.dij.source, ...
    'interval-plan');
verifyEqual(testCase,probData.optimizationInput.dij.source, ...
    'prob-nominal-plan');
verifyNotEqual(testCase,nominalData.optimizationInput.dij.source, ...
    referenceDij.source);
verifyNotEqual(testCase,intervalData.optimizationInput.dij.source, ...
    referenceDij.source);
verifyNotEqual(testCase,probData.optimizationInput.dij.source, ...
    referenceDij.source);
verifyNotEqual(testCase,nominalData.optimizationInput.dij.source, ...
    intervalData.optimizationInput.dij.source);
verifyNotEqual(testCase,intervalData.optimizationInput.dij.source, ...
    probData.optimizationInput.dij.source);
verifyEqual(testCase,intervalData.optimizationInput.dijKind,'nominal');
verifyEqual(testCase,probData.optimizationInput.dijKind,'nominal');
verifyEqual(testCase,nominalData.optimizationInput.stf.source, ...
    'nominal-plan-stf');
verifyEqual(testCase,intervalData.optimizationInput.stf.source, ...
    'robust_2-robust-stf');
verifyEqual(testCase,probData.optimizationInput.stf.source, ...
    'robust_3-robust-stf');
end

function testReferenceNominalIntervalSelectionKeepsCompactPayload(testCase)
referenceData = nominalSelectionData('reference','reference-nominal', ...
    'INTERVAL2',true,false);
referenceData.dij_interval = intervalDij(3);
referenceData.dijIntervalContext = ...
    intervalDijContext(referenceData.dij_interval);

referenceData = ...
    planWorkflow.stages.PrecomputeStage.selectReferenceOptimizationDoseInfluence( ...
    referenceData);

verifyEqual(testCase,referenceData.optimizationInput.dij.source, ...
    'reference-nominal');
verifyEqual(testCase,referenceData.optimizationInput.pln.source, ...
    'reference-nominal');
verifyEqual(testCase,referenceData.optimizationInput.dijKind,'nominal');
verifyTrue(testCase,isfield(referenceData.optimizationInput.pln.propOpt, ...
    'dij_interval'));
verifyEqual(testCase,referenceData.optimizationInput.pln.propOpt.dij_interval, ...
    referenceData.dij_interval);
end

function testReferenceNominalProb2SelectionKeepsCompactPayload(testCase)
referenceData = nominalSelectionData('reference','reference-nominal', ...
    'PROB2',false,true);
referenceData.dij_prob = probDij(3);
referenceData.dijProbContext = probDijContext(referenceData.dij_prob);

referenceData = ...
    planWorkflow.stages.PrecomputeStage.selectReferenceOptimizationDoseInfluence( ...
    referenceData);

verifyEqual(testCase,referenceData.optimizationInput.dij.source, ...
    'reference-nominal');
verifyEqual(testCase,referenceData.optimizationInput.pln.source, ...
    'reference-nominal');
verifyEqual(testCase,referenceData.optimizationInput.dijKind,'nominal');
verifyTrue(testCase,isfield(referenceData.optimizationInput.pln.propOpt, ...
    'dij_prob'));
verifyEqual(testCase,referenceData.optimizationInput.pln.propOpt.dij_prob, ...
    referenceData.dij_prob);
end

function testCachedIntervalDijRejectsNominalDijWithBadQuantitySize(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2','Interval2','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
config.precompute.robustPlans.hasNominalObjectives = true;
config.precompute.robustPlans.requiresNominalDij = true;
config.precompute.robustPlans.requiresIntervalDij = true;
workflow = planWorkflowTest.EngineProbe(config);
workflow.data.optimizationInput.dij = referenceDij();

scenarioModel = matRad_WorstCaseScenarios();
scenarioModel.scenarioDimensionActive = {'ct','setup'};
scenarioModel.shiftSD = [1 2 3];
scenarioModel.wcSigma = 1;

robustData = intervalRobustData(workflow);
robustData.pln.multScen = scenarioModel;
robustData.pln.propOpt = struct();
robustData.stf = stfForBixels(workflow.data.optimizationInput.dij.totalNumOfBixels);

cacheContext = workflow.intervalCacheContextPublic(robustData);
intervalTag = workflow.intervalDoseCacheTagPublic(robustData);
cacheFile = workflow.cacheFilePublic(intervalTag,robustData.pln, ...
    cacheContext);
mkdir(fileparts(cacheFile));
dij_interval = intervalDij(workflow.data.optimizationInput.dij.totalNumOfBixels);
dij_interval.quantity = 'RBExD';
dij_interval.quantityField = 'RBExDose';
dijIntervalContext = intervalDijContext(dij_interval);
dijIntervalContext.RBExDose = ...
    {sparse(1,size(dij_interval.center,2))}; %#ok<NASGU>
cacheMetadata = workflow.cacheMetadataPublic( ...
    intervalTag,robustData.pln,cacheContext);
cacheMetadata.intervalMode = 'INTERVAL2';
cacheMetadata.scenarioFingerprint = ...
    planWorkflow.cache.CacheIdentity.scenarioFingerprint(scenarioModel);
cacheMetadata.dijPrecomputingTiming = ...
    sampleDijPrecomputingTiming('dij_interval');
cacheMetadata.dijPrecomputingSize = ...
    sampleDijPrecomputingSize('dij_interval');
builtin('save',cacheFile,'dij_interval','dijIntervalContext', ...
    'cacheMetadata','-v7.3');

cacheHit = workflow.loadCachedIntervalDoseInfluencePublic(robustData);

verifyFalse(testCase,cacheHit);
end

function testStaleIntervalDijCacheIsRejected(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2','Interval2','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
workflow = planWorkflowTest.EngineProbe(config);
workflow.data.optimizationInput.dij = referenceDij();

scenarioModel = matRad_WorstCaseScenarios();
scenarioModel.scenarioDimensionActive = {'ct','setup'};
scenarioModel.shiftSD = [1 2 3];
scenarioModel.wcSigma = 1;
robustData = intervalRobustData(workflow);
robustData.pln.multScen = scenarioModel;
robustData.pln.propOpt = struct();
robustData.stf = stfForBixels(workflow.data.optimizationInput.dij.totalNumOfBixels);

cacheContext = workflow.intervalCacheContextPublic(robustData);
intervalTag = workflow.intervalDoseCacheTagPublic(robustData);
cacheFile = workflow.cacheFilePublic(intervalTag,robustData.pln, ...
    cacheContext);
mkdir(fileparts(cacheFile));
dij_interval = intervalDij(workflow.data.optimizationInput.dij.totalNumOfBixels);
dijIntervalContext = intervalDijContext(dij_interval); %#ok<NASGU>
cacheMetadata = workflow.cacheMetadataPublic( ...
    intervalTag,robustData.pln,cacheContext);
cacheMetadata.intervalMode = 'INTERVAL2';
cacheMetadata.scenarioFingerprint = 'different-scenario';
cacheMetadata.dijPrecomputingTiming = ...
    sampleDijPrecomputingTiming('dij_interval');
cacheMetadata.dijPrecomputingSize = ...
    sampleDijPrecomputingSize('dij_interval');
builtin('save',cacheFile,'dij_interval','dijIntervalContext', ...
    'cacheMetadata','-v7.3');

cacheHit = workflow.loadCachedIntervalDoseInfluencePublic(robustData);

verifyFalse(testCase,cacheHit);
end

function testIntervalCacheContextIncludesPrecomputeStfGeometry(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2','Interval2','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
workflow = planWorkflowTest.EngineProbe(config);
scenarioModel = matRad_WorstCaseScenarios();
scenarioModel.scenarioDimensionActive = {'ct','setup'};
scenarioModel.shiftSD = [1 2 3];
scenarioModel.wcSigma = 1;

robustDataA = intervalRobustData(workflow);
robustDataA.pln.multScen = scenarioModel;
robustDataA.pln.propOpt = struct();
robustDataA.stf = stfForBixels(3);
robustDataB = robustDataA;
robustDataB.stf = stfForBixels(4);

contextA = workflow.intervalCacheContextPublic(robustDataA);
contextB = workflow.intervalCacheContextPublic(robustDataB);

verifyTrue(testCase,isfield(contextA,'stf'));
verifyEqual(testCase,contextA.stf.totalNumOfBixels,3);
verifyEqual(testCase,contextB.stf.totalNumOfBixels,4);
intervalTagA = workflow.intervalDoseCacheTagPublic(robustDataA);
intervalTagB = workflow.intervalDoseCacheTagPublic(robustDataB);
verifyNotEqual(testCase, ...
    workflow.cacheDescriptorPublic(intervalTagA, ...
    robustDataA.pln,contextA).identityHash, ...
    workflow.cacheDescriptorPublic(intervalTagB, ...
    robustDataB.pln,contextB).identityHash);
end

function testSamplingScenarioFieldsUpdateSamplingBasisOnly(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));
workflow.configureStagePublic('sample',struct( ...
    'sampling_scen_mode','impScen_permuted5', ...
    'sampling_wcSigma',2.5, ...
    'sampling_size',17));

verifyEqual(testCase,workflow.runConfig.precompute.reference.scenario.mode, ...
    'nomScen');
verifyEqual(testCase,workflow.runConfig.precompute.reference.scenario.wcSigma,1);
verifyEqual(testCase,workflow.runConfig.sampling_scen_mode, ...
    'impScen_permuted5');
verifyEqual(testCase,workflow.runConfig.sampling_wcSigma,2.5);
verifyEqual(testCase,workflow.runConfig.sampling_size,17);
end

function testSamplingScenarioParametersAreAccepted(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));
workflow.configureStagePublic('sample',struct( ...
    'sampling_scen_mode','impScen_permuted7', ...
    'sampling_ctActive',false, ...
    'sampling_ctReferenceScenId',2, ...
    'sampling_setupActive',true, ...
    'sampling_rangeActive',true, ...
    'sampling_shiftSD',[2 3 4], ...
    'sampling_rangeAbsSD',0.8, ...
    'sampling_rangeRelSD',2.5, ...
    'sampling_numOfRangeGridPoints',3));

verifyEqual(testCase,workflow.runConfig.sampling_scen_mode, ...
    'impScen_permuted7');
verifyFalse(testCase,workflow.runConfig.sampling_ctActive);
verifyEqual(testCase,workflow.runConfig.sampling_ctReferenceScenId,2);
verifyTrue(testCase,workflow.runConfig.sampling_setupActive);
verifyTrue(testCase,workflow.runConfig.sampling_rangeActive);
verifyEqual(testCase,workflow.runConfig.sampling_shiftSD,[2 3 4]);
verifyEqual(testCase,workflow.runConfig.sampling_rangeAbsSD,0.8);
verifyEqual(testCase,workflow.runConfig.sampling_rangeRelSD,2.5);
verifyEqual(testCase,workflow.runConfig.sampling_numOfRangeGridPoints,3);
end

function testGuiAcceptedRunConfigDefaultsHiddenSamplingScenarioFields(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));
editedRunConfig = workflow.runConfig;
editedRunConfig.sampling_scen_mode = 'random';
editedRunConfig.sampling_ctActive = false;
editedRunConfig.sampling_ctReferenceScenId = 1;
editedRunConfig.sampling_setupActive = true;
editedRunConfig.sampling_rangeActive = false;
editedRunConfig.sampling_gantryActive = true;
editedRunConfig.sampling_couchActive = true;
editedRunConfig.sampling_gantryAngleSD = 1;
editedRunConfig.sampling_couchAngleSD = 1;
editedRunConfig = rmfield(editedRunConfig,{ ...
    'sampling_ctScenProb','sampling_wcSigma', ...
    'sampling_numOfRangeGridPoints'});
workflow.setEditorResponse( ...
    workflow.activePlanTemplatePublic(),editedRunConfig,true,[],'');

workflow.gui();

verifyEqual(testCase,workflow.runConfig.sampling_scen_mode,'random');
verifyFalse(testCase,workflow.runConfig.sampling_ctActive);
verifyEqual(testCase,workflow.runConfig.sampling_ctReferenceScenId,1);
verifyEqual(testCase,workflow.runConfig.sampling_ctScenProb,[]);
verifyEqual(testCase,workflow.runConfig.sampling_wcSigma,1.0);
verifyEqual(testCase,workflow.runConfig.sampling_numOfRangeGridPoints,1);
end

function testGuiAcceptedRunConfigDefaultsHiddenDosePullingFields(testCase)
config = baseEngineConfig(testCase);
config.dose_pulling1 = true;
config.dose_pulling1_target = {'PTV'};
config.dose_pulling1_criteria = {'D99'};
config.dose_pulling1_limit = 0.91;
config.dose_pulling1_start = 12;
config.dose_pulling2 = true;
config.dose_pulling2_target = {'Bladder'};
config.dose_pulling2_criteria = 'meanQiOAR';
config.dose_pulling2_limit = 0.33;
config.dose_pulling2_start = 14;
config.dose_pulling_strategy = 'heuristicMultiObjective';
config.dose_pulling_local_window = 3;
config.dose_pulling_patience = 7;
config.dose_pulling_target_tol = 2e-3;
config.dose_pulling_selection_policy = 'weightedSum';
config.dose_pulling_target_weight = 5;
config.dose_pulling_oar_weight = 6;
config.dose_pulling_step_weight = 7e-6;
config.dose_pulling_max_vmax_percent = 80;
config.dose_pulling_use_warm_start = false;
workflow = planWorkflowTest.EngineProbe(config);

editedRunConfig = workflow.runConfig;
editedRunConfig.dose_pulling1 = false;
editedRunConfig.dose_pulling2 = false;
editedRunConfig.dose_pulling_strategy = 'Threshold';
hiddenFields = {'dose_pulling1_target','dose_pulling1_criteria', ...
    'dose_pulling1_limit','dose_pulling1_start', ...
    'dose_pulling2_target','dose_pulling2_criteria', ...
    'dose_pulling2_limit','dose_pulling2_start', ...
    'dose_pulling_search_schedule','dose_pulling_local_window', ...
    'dose_pulling_patience','dose_pulling_target_tol', ...
    'dose_pulling_selection_policy','dose_pulling_target_weight', ...
    'dose_pulling_oar_weight','dose_pulling_step_weight', ...
    'dose_pulling_max_vmax_percent','dose_pulling_use_warm_start'};
editedRunConfig = rmfield( ...
    editedRunConfig,hiddenFields(isfield(editedRunConfig,hiddenFields)));
workflow.setEditorResponse( ...
    workflow.activePlanTemplatePublic(),editedRunConfig,true,[],'');

workflow.gui();

verifyFalse(testCase,workflow.runConfig.dose_pulling1);
verifyFalse(testCase,workflow.runConfig.dose_pulling2);
verifyEqual(testCase,workflow.runConfig.dose_pulling_strategy,'Threshold');
verifyEqual(testCase,workflow.runConfig.dose_pulling1_target,{'CTV'});
verifyEqual(testCase,workflow.runConfig.dose_pulling1_criteria,{'COV1'});
verifyEqual(testCase,workflow.runConfig.dose_pulling1_limit,0.98);
verifyEqual(testCase,workflow.runConfig.dose_pulling1_start,0);
verifyEqual(testCase,workflow.runConfig.dose_pulling2_target,{'CTV'});
verifyEqual(testCase,workflow.runConfig.dose_pulling2_criteria, ...
    'meanQiTarget');
verifyEqual(testCase,workflow.runConfig.dose_pulling2_limit,0.80);
verifyEqual(testCase,workflow.runConfig.dose_pulling2_start,0);
verifyEqual(testCase,workflow.runConfig.dose_pulling_local_window,8);
verifyEqual(testCase,workflow.runConfig.dose_pulling_patience,3);
verifyEqual(testCase,workflow.runConfig.dose_pulling_target_tol,1e-3);
verifyEqual(testCase,workflow.runConfig.dose_pulling_selection_policy, ...
    'normalizedKnee');
verifyEqual(testCase,workflow.runConfig.dose_pulling_target_weight,1);
verifyEqual(testCase,workflow.runConfig.dose_pulling_oar_weight,1);
verifyEqual(testCase,workflow.runConfig.dose_pulling_step_weight,1e-6);
verifyEqual(testCase,workflow.runConfig.dose_pulling_max_vmax_percent,100);
verifyTrue(testCase,workflow.runConfig.dose_pulling_use_warm_start);
end

function testSamplingLinksToOptimizationByDefault(testCase)
config = baseEngineConfig(testCase);
config.dicomMetadata = struct('patientID','OPT-1');

workflow = planWorkflow.Workflow(config);

verifyTrue(testCase,workflow.runConfig.sampling_linkToOptimization);
verifyEqual(testCase,workflow.runConfig.sampling_caseID, ...
    workflow.runConfig.caseID);
verifyEqual(testCase,workflow.runConfig.sampling_AcquisitionType, ...
    workflow.runConfig.AcquisitionType);
verifyEqual(testCase,workflow.runConfig.sampling_dicomMetadata.patientID, ...
    'OPT-1');
end

function testSamplingCaseSelectionDisablesOptimizationLink(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));
workflow.configureStagePublic('sample',struct( ...
    'caseID','sampling-case', ...
    'AcquisitionType','mat'));

verifyFalse(testCase,workflow.runConfig.sampling_linkToOptimization);
verifyEqual(testCase,workflow.runConfig.sampling_caseID,'sampling-case');
verifyEqual(testCase,workflow.runConfig.sampling_AcquisitionType,'mat');
end

function testSamplingLinkCanBeExplicitlyDisabled(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));
workflow.configureStagePublic('sample',struct( ...
    'linkToOptimization',false));

verifyFalse(testCase,workflow.runConfig.sampling_linkToOptimization);
verifyEqual(testCase,workflow.runConfig.sampling_caseID, ...
    workflow.runConfig.caseID);
verifyEqual(testCase,workflow.runConfig.sampling_AcquisitionType, ...
    workflow.runConfig.AcquisitionType);
end

function testNestedStageConfigIsExpanded(testCase)
config = baseEngineConfig(testCase);
config = rmfield(config,{'radiationMode','description','caseID', ...
    'sampling_scen_mode','sampling_wcSigma'});
config.prepare.radiationMode = 'photons';
config.prepare.description = 'prostate';
config.prepare.plan_template = 'interval2_001';
config.prepare.caseID = 'nested-case';
config.prepare.plan_beams = '7F';
robustPlan = robustPlanConfig('intervalPlan','INTERVAL2 plan','Interval2', ...
    'INTERVAL2','wcScen',[5 10 5], ...
    robustVariantConfig('theta_1','Variant 1',1,1,1,1));
robustPlan.scenario.wcSigma = 1.25;
config.precompute.robustPlans = robustPlan;
config.pullDose.step1Enabled = true;
config.pullDose.step1Target = {'CTV','PTV'};
config.pullDose.step1Criteria = {'COV1','D99'};
config.pullDose.step1Limit = [0.90 0.95];
config.pullDose.step1Start = 8;
config.pullDose.strategy = 'heuristicMultiObjective';
config.pullDose.searchSchedule = 'exponential';
config.pullDose.localWindow = 6;
config.pullDose.patience = 4;
config.pullDose.targetTol = 5e-4;
config.pullDose.selectionPolicy = 'weightedSum';
config.pullDose.targetWeight = 2.0;
config.pullDose.oarWeight = 3.0;
config.pullDose.stepWeight = 4e-6;
config.pullDose.maxVmaxPercent = 95;
config.pullDose.useWarmStart = false;
config.optimize.optimizer = 'IPOPT';
config.sampling.sampling_scen_mode = 'impScen_permuted5';
config.sampling.sampling_wcSigma = 2.5;
config.analysis.evaluationMode = 'total';

workflow = planWorkflow.Workflow(config);

verifyEqual(testCase,workflow.runConfig.caseID,'nested-case');
verifyEqual(testCase,workflow.runConfig.radiationMode,'photons');
verifyEqual(testCase,workflow.runConfig.description,'prostate');
verifyEqual(testCase,workflow.runConfig.plan_template,'interval2_001');
verifyEqual(testCase,workflow.runConfig.plan_beams,'7F');
verifyEqual(testCase,workflow.runConfig.precompute.robustPlans(1).robustnessMode, ...
    'INTERVAL2');
verifyEqual(testCase, ...
    workflow.runConfig.precompute.robustPlans(1).scenario.mode,'wcScen');
verifyEqual(testCase, ...
    workflow.runConfig.precompute.robustPlans(1).scenario.wcSigma,1.25);
verifyTrue(testCase,workflow.runConfig.dose_pulling1);
verifyEqual(testCase,workflow.runConfig.dose_pulling1_target, ...
    {'CTV','PTV'});
verifyEqual(testCase,workflow.runConfig.dose_pulling1_criteria, ...
    {'COV1','D99'});
verifyEqual(testCase,workflow.runConfig.dose_pulling1_limit,[0.90 0.95]);
verifyEqual(testCase,workflow.runConfig.dose_pulling1_start,8);
verifyEqual(testCase,workflow.runConfig.dose_pulling_strategy, ...
    'heuristicMultiObjective');
verifyEqual(testCase,workflow.runConfig.dose_pulling_search_schedule, ...
    'exponential');
verifyEqual(testCase,workflow.runConfig.dose_pulling_local_window,6);
verifyEqual(testCase,workflow.runConfig.dose_pulling_patience,4);
verifyEqual(testCase,workflow.runConfig.dose_pulling_target_tol,5e-4);
verifyEqual(testCase,workflow.runConfig.dose_pulling_selection_policy, ...
    'weightedSum');
verifyEqual(testCase,workflow.runConfig.dose_pulling_target_weight,2.0);
verifyEqual(testCase,workflow.runConfig.dose_pulling_oar_weight,3.0);
verifyEqual(testCase,workflow.runConfig.dose_pulling_step_weight,4e-6);
verifyEqual(testCase,workflow.runConfig.dose_pulling_max_vmax_percent,95);
verifyFalse(testCase,workflow.runConfig.dose_pulling_use_warm_start);
verifyEqual(testCase,workflow.runConfig.optimizer,'IPOPT');
verifyEqual(testCase,workflow.runConfig.sampling_scen_mode, ...
    'impScen_permuted5');
verifyEqual(testCase,workflow.runConfig.sampling_wcSigma,2.5);
verifyEqual(testCase,workflow.runConfig.analysis.evaluationMode,'total');
end

function testPrecomputeScenarioParametersAreAccepted(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));
robustPlan = robustPlanConfig('randomPlan','Random plan','Interval2', ...
    'INTERVAL2','random',[1 2 3], ...
    robustVariantConfig('theta_1','Variant 1',1,1,1,1));
robustPlan.scenario.setupActive = true;
robustPlan.scenario.rangeActive = true;
robustPlan.scenario.rangeAbsSD = 1.2;
robustPlan.scenario.rangeRelSD = 3.4;
robustPlan.scenario.random_size = 12;
robustPlan.scenario.randomSeed = 123;
workflow.configureStagePublic('precompute',struct( ...
    'doseResolution',[4 5 6], ...
    'robustPlans',robustPlan));

robustPlan = workflow.runConfig.precompute.robustPlans(1);
verifyEqual(testCase,robustPlan.scenario.mode,'random');
verifyEqual(testCase,workflow.runConfig.doseResolution,[4 5 6]);
verifyTrue(testCase,robustPlan.scenario.setupActive);
verifyTrue(testCase,robustPlan.scenario.rangeActive);
verifyEqual(testCase,robustPlan.scenario.shiftSD,[1 2 3]);
verifyEqual(testCase,robustPlan.scenario.rangeAbsSD,1.2);
verifyEqual(testCase,robustPlan.scenario.rangeRelSD,3.4);
verifyEqual(testCase,robustPlan.scenario.random_size,12);
verifyEqual(testCase,robustPlan.scenario.randomSeed,123);
end

function testActiveDimensionScaleValidation(testCase)
config = baseEngineConfig(testCase);
robustPlan = robustPlanConfig('badPlan','Bad plan','Interval2', ...
    'INTERVAL2','wcScen',[5 10 5], ...
    robustVariantConfig('theta_1','Variant 1',1,1,1,1));
robustPlan.scenario.rangeActive = true;
config.precompute.robustPlans = robustPlan;

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:scenario:InvalidActiveDimensionScale');
end

function testActiveAngularDimensionScaleValidation(testCase)
config = baseEngineConfig(testCase);
robustPlan = robustPlanConfig('badPlan','Bad plan','Interval2', ...
    'INTERVAL2','random',[5 10 5], ...
    robustVariantConfig('theta_1','Variant 1',1,1,1,1));
robustPlan.scenario.gantryActive = true;
config.precompute.robustPlans = robustPlan;

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:scenario:InvalidActiveDimensionScale');
end

function testCtReferenceScenarioIsApplied(testCase)
config = genericScenarioConfig();
config.ctActive = false;
config.ctReferenceScenId = 2;
ct = struct('numOfCtScen',3);

multScen = planWorkflow.scenario.createModel( ...
    ct,'nomScen',config,'optimization');

verifyEqual(testCase,multScen.ctScenProb,[2 1]);
verifyTrue(testCase,all(multScen.scenarioCtScenIds == 2));
verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive, ...
    'setup')));
verifyFalse(testCase,any(strcmp(multScen.scenarioDimensionActive, ...
    'ct')));
end

function testCtScenarioProbabilitiesDefaultToUniform(testCase)
config = genericScenarioConfig();
ct = struct('numOfCtScen',4);

multScen = planWorkflow.scenario.createModel( ...
    ct,'nomScen',config,'optimization');

verifyEqual(testCase,multScen.ctScenProb, ...
    [(1:4)' repmat(0.25,4,1)]);
end

function testCtScenarioProbabilitiesAreExplicitlyApplied(testCase)
config = genericScenarioConfig();
config.ctScenProb = [0.2 0.3 0.5];
ct = struct('numOfCtScen',3);

multScen = planWorkflow.scenario.createModel( ...
    ct,'nomScen',config,'optimization');

verifyEqual(testCase,multScen.ctScenProb, ...
    [(1:3)' [0.2;0.3;0.5]]);
end

function testSamplingScenarioUsesSamplingCtScenarioProbabilities(testCase)
config = genericScenarioConfig();
config.ctScenProb = [0.5 0.5];
config.sampling_ctScenProb = [0.8 0.2];
ct = struct('numOfCtScen',2);

multScen = planWorkflow.scenario.createModel( ...
    ct,'nomScen',config,'sampling');

verifyEqual(testCase,multScen.ctScenProb, ...
    [(1:2)' [0.8;0.2]]);
end

function testCtScenarioProbabilityLengthIsValidated(testCase)
config = genericScenarioConfig();
config.ctScenProb = [0.5 0.5];
ct = struct('numOfCtScen',3);

verifyError(testCase,@() planWorkflow.scenario.createModel( ...
    ct,'nomScen',config,'optimization'), ...
    'planWorkflow:config:ScenarioSpec:InvalidCtScenProb');
end

function testCtScenarioProbabilitiesRequireActiveCt(testCase)
config = genericScenarioConfig();
config.ctActive = false;
config.ctScenProb = [0.5 0.5];
ct = struct('numOfCtScen',2);

verifyError(testCase,@() planWorkflow.scenario.createModel( ...
    ct,'nomScen',config,'optimization'), ...
    'planWorkflow:config:ScenarioSpec:IncompatibleCtScenProb');
end

function testGriddedSamplingScenarioAcceptsSetupWithoutRange(testCase)
config = genericScenarioConfig();
config.scen_mode = 'impScen_permuted5';
config.ctActive = true;
config.setupActive = true;
config.rangeActive = false;
config.rangeAbsSD = 0;
config.rangeRelSD = 0;
config.numOfRangeGridPoints = 1;
ct = struct('numOfCtScen',2);

multScen = planWorkflow.scenario.createModel( ...
    ct,'impScen_permuted5',config,'sampling');

verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive,'ct')));
verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive,'setup')));
verifyFalse(testCase,any(strcmp(multScen.scenarioDimensionActive,'range')));
end

function testPrepareDoseCalculationFieldsAreRejected(testCase)
config = baseEngineConfig(testCase);
config.prepare.doseResolution = [3 3 3];

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:WorkflowBase:UnsupportedStageConfigField');
end

function testPrepareShiftSdFieldIsRejected(testCase)
config = baseEngineConfig(testCase);
config.prepare.shiftSD = [1 2 3];

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:WorkflowBase:UnsupportedStageConfigField');
end

function testDoseResolutionCanBeAppliedAtPrecomputeTime(testCase)
config = baseEngineConfig(testCase);
config.doseResolution = [7 8 9];
pln = struct();

pln = planWorkflow.plan.Plan.applyDoseResolution(config,pln);

verifyEqual(testCase,pln.propDoseCalc.doseGrid.resolution.x,7);
verifyEqual(testCase,pln.propDoseCalc.doseGrid.resolution.y,8);
verifyEqual(testCase,pln.propDoseCalc.doseGrid.resolution.z,9);
end

function testRandomOptimizationScenarioUsesRandomSize(testCase)
config = genericScenarioConfig();
config.random_size = 13;
config.sampling_size = 21;
config.rangeAbsSD = 1;
config.rangeRelSD = 1;
config.rangeActive = true;

multScen = planWorkflow.scenario.createModel( ...
    [],'random',config,'optimization');

verifyEqual(testCase,multScen.nSamples,13);
verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive,'ct')));
verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive,'setup')));
verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive,'range')));
end

function testSupportedScenarioModesIncludeTruncatedRndScen(testCase)
modes = planWorkflow.matRadCapabilitiesReader.supportedScenarioModes();

verifyTrue(testCase,any(strcmp(modes,'truncatedRndScen')));
end

function testTruncatedRndScenOptimizationScenarioUsesRandomSize(testCase)
config = genericScenarioConfig();
config.random_size = 13;
config.sampling_size = 21;
config.rangeAbsSD = 1;
config.rangeRelSD = 1;
config.rangeActive = true;

multScen = planWorkflow.scenario.createModel( ...
    [],'truncatedRndScen',config,'optimization');

verifyEqual(testCase,multScen.nSamples,13);
verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive,'ct')));
verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive,'setup')));
verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive,'range')));
verifyEqual(testCase,multScen.shortName,'truncatedRndScen');
end

function testRandomSamplingScenarioUsesSamplingSize(testCase)
config = genericScenarioConfig();
config.random_size = 13;
config.sampling_size = 21;
config.rangeAbsSD = 1;
config.rangeRelSD = 1;
config.rangeActive = true;

multScen = planWorkflow.scenario.createModel( ...
    [],'random',config,'sampling');

verifyEqual(testCase,multScen.nSamples,21);
end

function testTruncatedRndScenSamplingScenarioUsesSamplingSize(testCase)
config = genericScenarioConfig();
config.random_size = 13;
config.sampling_size = 21;
config.rangeAbsSD = 1;
config.rangeRelSD = 1;
config.rangeActive = true;

multScen = planWorkflow.scenario.createModel( ...
    [],'truncatedRndScen',config,'sampling');

verifyEqual(testCase,multScen.nSamples,21);
verifyEqual(testCase,multScen.shortName,'truncatedRndScen');
end

function testRandomScenarioAppliesOptionalRandomSeed(testCase)
config = genericScenarioConfig();
config.randomSeed = 42;
config.rangeAbsSD = 1;
config.rangeRelSD = 1;
config.rangeActive = true;

multScen = planWorkflow.scenario.createModel( ...
    [],'random',config,'optimization');

verifyEqual(testCase,multScen.randomSeed,42);
end

function testTruncatedRndScenAppliesOptionalRandomSeed(testCase)
config = genericScenarioConfig();
config.randomSeed = 42;
config.rangeAbsSD = 1;
config.rangeRelSD = 1;
config.rangeActive = true;

multScen = planWorkflow.scenario.createModel( ...
    [],'truncatedRndScen',config,'optimization');

verifyEqual(testCase,multScen.randomSeed,42);
verifyEqual(testCase,multScen.shortName,'truncatedRndScen');
end

function testInvalidRandomSeedIsRejected(testCase)
config = baseEngineConfig(testCase);
robustPlan = robustPlanConfig('badPlan','Bad plan','Interval2', ...
    'INTERVAL2','wcScen',[5 10 5], ...
    robustVariantConfig('theta_1','Variant 1',1,1,1,1));
robustPlan.scenario.randomSeed = 1.5;
config.precompute.robustPlans = robustPlan;

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:config:ScenarioSpec:InvalidOptionalInteger');
end

function testRandomScenarioAcceptsAngularDimensions(testCase)
config = genericScenarioConfig();
config.scen_mode = 'random';
config.gantryActive = true;
config.couchActive = true;
config.gantryAngleSD = 2;
config.couchAngleSD = 3;
config.numOfBeams = 2;

multScen = planWorkflow.scenario.createModel( ...
    [],'random',config,'optimization');

verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive,'gantry')));
verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive,'couch')));
verifyEqual(testCase,multScen.gantryAngleSD,2);
verifyEqual(testCase,multScen.couchAngleSD,3);
verifyEqual(testCase,multScen.numOfBeams,2);
end

function testTruncatedRndScenAcceptsAngularDimensions(testCase)
config = genericScenarioConfig();
config.scen_mode = 'truncatedRndScen';
config.gantryActive = true;
config.couchActive = true;
config.gantryAngleSD = 2;
config.couchAngleSD = 3;
config.numOfBeams = 2;

multScen = planWorkflow.scenario.createModel( ...
    [],'truncatedRndScen',config,'optimization');

verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive,'gantry')));
verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive,'couch')));
verifyEqual(testCase,multScen.gantryAngleSD,2);
verifyEqual(testCase,multScen.couchAngleSD,3);
verifyEqual(testCase,multScen.numOfBeams,2);
verifyEqual(testCase,multScen.shortName,'truncatedRndScen');
end

function testRandomScenarioAcceptsGantryOnlyAngularDimension(testCase)
config = genericScenarioConfig();
config.scen_mode = 'random';
config.gantryActive = true;
config.couchActive = false;
config.gantryAngleSD = 2;
config.couchAngleSD = 0;
config.numOfBeams = 2;

multScen = planWorkflow.scenario.createModel( ...
    [],'random',config,'optimization');

verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive,'gantry')));
verifyFalse(testCase,any(strcmp(multScen.scenarioDimensionActive,'couch')));
verifyEqual(testCase,multScen.gantryAngleSD,2);
verifyEqual(testCase,multScen.couchAngleSD,0);
verifyEqual(testCase,multScen.numOfBeams,2);
verifyEqual(testCase,multScen.scenarioStoragePolicy, ...
    'compact-realization');
verifyEqual(testCase,size(multScen.scenarioStorageSubscripts,2),2);
verifyEqual(testCase,multScen.numScenarios(),config.random_size);
verifyTrue(testCase,any(abs(multScen.gantryAngleOffset(:)) > 0));
verifyTrue(testCase,all(abs(multScen.couchAngleOffset(:)) <= eps));
end

function testRandomScenarioAcceptsCouchOnlyAngularDimension(testCase)
config = genericScenarioConfig();
config.scen_mode = 'random';
config.gantryActive = false;
config.couchActive = true;
config.gantryAngleSD = 0;
config.couchAngleSD = 3;
config.numOfBeams = 2;

multScen = planWorkflow.scenario.createModel( ...
    [],'random',config,'optimization');

verifyFalse(testCase,any(strcmp(multScen.scenarioDimensionActive,'gantry')));
verifyTrue(testCase,any(strcmp(multScen.scenarioDimensionActive,'couch')));
verifyEqual(testCase,multScen.gantryAngleSD,0);
verifyEqual(testCase,multScen.couchAngleSD,3);
verifyEqual(testCase,multScen.numOfBeams,2);
verifyEqual(testCase,multScen.scenarioStoragePolicy, ...
    'compact-realization');
verifyEqual(testCase,size(multScen.scenarioStorageSubscripts,2),2);
verifyEqual(testCase,multScen.numScenarios(),config.random_size);
verifyTrue(testCase,all(abs(multScen.gantryAngleOffset(:)) <= eps));
verifyTrue(testCase,any(abs(multScen.couchAngleOffset(:)) > 0));
end

function testRandomScenarioAcceptsBeamCountWithoutAngularDimensions(testCase)
config = genericScenarioConfig();
config.scen_mode = 'random';
config.ctActive = false;
config.gantryActive = false;
config.couchActive = false;
config.numOfBeams = 9;
ct = struct('numOfCtScen',1);

multScen = planWorkflow.scenario.createModel( ...
    ct,'random',config,'sampling');

verifyEqual(testCase,multScen.numScenarios(),config.sampling_size);
verifyFalse(testCase,any(strcmp(multScen.scenarioDimensionActive,'gantry')));
verifyFalse(testCase,any(strcmp(multScen.scenarioDimensionActive,'couch')));
verifyEqual(testCase,size(multScen.linearMask,1), ...
    multScen.numScenarios());
end

function testRandomAndTruncatedRndScenFingerprintsDiffer(testCase)
config = genericScenarioConfig();
config.random_size = 11;
config.randomSeed = 7;
config.rangeAbsSD = 1;
config.rangeRelSD = 1;
config.rangeActive = true;

randomScen = planWorkflow.scenario.createModel( ...
    [],'random',config,'optimization');
truncatedScen = planWorkflow.scenario.createModel( ...
    [],'truncatedRndScen',config,'optimization');

randomFingerprint = ...
    planWorkflow.cache.CacheIdentity.scenarioFingerprint(randomScen);
truncatedFingerprint = ...
    planWorkflow.cache.CacheIdentity.scenarioFingerprint(truncatedScen);

verifyNotEqual(testCase,randomFingerprint,truncatedFingerprint);
end

function testAngularDimensionsRequireSampledScenarioMode(testCase)
config = genericScenarioConfig();
config.gantryActive = true;
config.gantryAngleSD = 2;
config.numOfBeams = 2;

verifyError(testCase,@() planWorkflow.scenario.createModel( ...
    [],'wcScen',config,'optimization'), ...
    ['planWorkflow:scenario:createModel:' ...
     'AngularDimensionsRequireSampledScenario']);
end

function testConflictingNestedStageConfigIsRejected(testCase)
config = baseEngineConfig(testCase);
config.plan_beams = '9F';
config.prepare.plan_beams = '7F';

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:Engine:ConflictingStageConfig');
end

function testUnknownNestedStageConfigFieldIsRejected(testCase)
config = baseEngineConfig(testCase);
config.prepare.unknownField = true;

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:WorkflowBase:UnsupportedStageConfigField');
end

function testSkinConfigFieldsAreAccepted(testCase)
config = baseEngineConfig(testCase);
config.skinMode = 'targetRegion';
config.skinThicknessMm = 5;
config.skinTargetDistanceMm = 25;

workflow = planWorkflow.Workflow(config);

verifyEqual(testCase,workflow.runConfig.skinMode,'targetRegion');
verifyEqual(testCase,workflow.runConfig.skinThicknessMm,5);
verifyEqual(testCase,workflow.runConfig.skinTargetDistanceMm,25);
end

function testDicomMetadataConfigFieldsAreAccepted(testCase)
config = baseEngineConfig(testCase);
config.dicomMetadata = struct('patientID','PATIENT-1','useDoseGrid',false);

workflow = planWorkflow.Workflow(config);

verifyEqual(testCase,workflow.runConfig.dicomMetadata.patientID,'PATIENT-1');
verifyFalse(testCase,workflow.runConfig.dicomMetadata.useDoseGrid);
end

function testPlanTemplateConfigFieldIsAccepted(testCase)
config = baseEngineConfig(testCase);
config = rmfield(config,'description');
config.prepare.description = 'prostate';
config.prepare.plan_template = 'interval2_001';

workflow = planWorkflow.Workflow(config);

verifyEqual(testCase,workflow.runConfig.plan_template,'interval2_001');
end

function testTemplateDefaultsFollowRadiationMode(testCase)
config = baseEngineConfig(testCase);
config.radiationMode = 'carbon';
config.plan_template = 'interval2_001';
config.plan_beams = '';
config.machine = '';
config.bioModel = '';

workflow = planWorkflow.Workflow(config);

verifyEqual(testCase,workflow.runConfig.radiationMode,'carbon');
verifyEqual(testCase,workflow.runConfig.plan_beams,'2F');
verifyEqual(testCase,workflow.runConfig.machine,'Generic');
verifyEqual(testCase,workflow.runConfig.bioModel,'LEM');
verifyEqual(testCase,workflow.runConfig.quantityOpt,'RBExD');
end

function testNestedPrepareRadiationModeOverridesPhotonDefault(testCase)
config = baseEngineConfig(testCase);
config = rmfield(config,'radiationMode');
config.prepare.radiationMode = 'protons';
config.prepare.plan_template = 'interval2_001';

workflow = planWorkflow.Workflow(config);

verifyEqual(testCase,workflow.runConfig.radiationMode,'protons');
verifyEqual(testCase,workflow.runConfig.plan_beams,'2F');
verifyEqual(testCase,workflow.runConfig.machine,'Generic');
verifyEqual(testCase,workflow.runConfig.bioModel,'constRBE');
verifyEqual(testCase,workflow.runConfig.quantityOpt,'RBExD');
end

function testNestedPrepareQuantityOptOverridesBioModelDefault(testCase)
config = baseEngineConfig(testCase);
config = rmfield(config,'radiationMode');
config.prepare.radiationMode = 'protons';
config.prepare.bioModel = 'none';
config.prepare.quantityOpt = 'physicalDose';
config.prepare.plan_template = 'interval2_001';

workflow = planWorkflow.Workflow(config);

verifyEqual(testCase,workflow.runConfig.radiationMode,'protons');
verifyEqual(testCase,workflow.runConfig.bioModel,'none');
verifyEqual(testCase,workflow.runConfig.quantityOpt,'physicalDose');
end

function testTemplateRejectsRadiationModeNotDeclaredByTemplate(testCase)
config = baseEngineConfig(testCase);
config.description = 'breast';
config.radiationMode = 'carbon';
config.plan_template = 'PTV_001';
config.plan_beams = '';
config.machine = '';
config.bioModel = '';

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:templates:PlanTemplate:RadiationModeMismatch');
end

function testDoseCacheKeyUsesDoseInputsForReadableFolders(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'interval2_001';
workflow = planWorkflowTest.EngineProbe(config);

cacheKey = workflow.cacheKeyPublic('reference');

verifyTrue(testCase,contains(cacheKey,'prostate'));
verifyTrue(testCase,contains(cacheKey,'9F'));
end

function testPlanTemplateHashDoesNotAffectDoseCacheKey(testCase)
config = baseEngineConfig(testCase);
config.plan_template_hash = repmat('a',1,96);
workflow = planWorkflowTest.EngineProbe(config);

cacheKey = workflow.cacheKeyPublic('reference');
[~,fileStem] = fileparts(cacheKey);

verifyFalse(testCase,contains(cacheKey,workflow.runConfig.plan_template));
verifyFalse(testCase,contains(cacheKey,config.plan_template_hash));
verifyLessThanOrEqual(testCase,numel(fileStem),32);
end

function testRobustScenarioParametersAffectDoseCacheKey(testCase)
configA = baseEngineConfig(testCase);
configA.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2 plan','Interval2','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
configB = baseEngineConfig(testCase);
configB.precompute.robustPlans = configA.precompute.robustPlans;
configB.precompute.robustPlans(1).scenario.wcSigma = ...
    configA.precompute.robustPlans(1).scenario.wcSigma + 0.5;

workflowA = planWorkflowTest.EngineProbe(configA);
workflowB = planWorkflowTest.EngineProbe(configB);

verifyNotEqual(testCase,workflowA.cacheKeyPublic('robust_Interval2'), ...
    workflowB.cacheKeyPublic('robust_Interval2'));
end

function testRobustDoseCacheRejectsStrategyOnlyTag(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'comparison_001';
config.precompute.robustPlans = robustPlanConfig( ...
    'cowcPlan','COWC plan','Minimax','COWC','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
workflow = planWorkflowTest.EngineProbe(config);

verifyError(testCase,@() workflow.cacheKeyPublic('robust_COWC'), ...
    'planWorkflow:cache:CacheIdentity:UnknownRobustPlanId');
end

function testDoseInfluenceCacheTagsUsePlanId(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig('customPlanId','INTERVAL2', ...
    'Interval2','INTERVAL2','wcScen',[5 10 5], ...
    robustVariantConfig('theta_10','Variant 1',1,1,10,1));
workflow = planWorkflowTest.EngineProbe(config);

robustData = intervalRobustData(workflow);
robustTag = workflow.robustDoseCacheTagPublic(robustData);
intervalTag = workflow.intervalDoseCacheTagPublic(robustData);
robustKey = workflow.cacheKeyPublic(robustTag);
intervalKey = workflow.cacheKeyPublic(intervalTag);

verifyEqual(testCase,robustTag,'robust_Interval2');
verifyEqual(testCase,intervalTag,'interval_Interval2');
verifyTrue(testCase,contains(intervalKey, ...
    fullfile('interval','INTERVAL2')));
verifyFalse(testCase,contains(intervalKey,'customPlanId'));
verifyTrue(testCase,contains(intervalKey,'INTERVAL2'));
verifyDerivedKeyUsesInputStem(testCase,intervalKey,robustKey);
end

function testProb2DoseCacheUsesProbFolderAndInputStem(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'PROB2_001';
config.precompute.robustPlans = robustPlanConfig('probPlan','PROB2', ...
    'MeanVariance','PROB2','wcScen',[5 10 5], ...
    robustVariantConfig('variant_1','Variant 1',1,1,1,1));
workflow = planWorkflowTest.EngineProbe(config);

robustData = intervalRobustData(workflow);
robustTag = workflow.robustDoseCacheTagPublic(robustData);
probTag = workflow.probDoseCacheTagPublic(robustData);
probContext = workflow.probCacheContextPublic(robustData);
robustKey = workflow.cacheKeyPublic(robustTag);
probKey = workflow.cacheKeyPublic(probTag,struct(),probContext);
cacheMetadata = workflow.cacheMetadataPublic( ...
    probTag,struct(),probContext);

verifyEqual(testCase,probTag,'prob_MeanVariance');
verifyTrue(testCase,contains(probKey,fullfile('prob','PROB2')));
verifyFalse(testCase,contains(probKey,fullfile('other')));
verifyEqual(testCase,cacheMetadata.artifact.kind,'prob');
verifyEqual(testCase,cacheMetadata.planId,'MeanVariance');
verifyEqual(testCase,cacheMetadata.robustnessMode,'PROB2');
verifyDerivedKeyUsesInputStem(testCase,probKey,robustKey);
end

function testDerivedDoseCacheContextChangesOnlyDerivedHash(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig('intervalPlan','INTERVAL2', ...
    'Interval2','INTERVAL2','wcScen',[5 10 5], ...
    robustVariantConfig('theta_10','Variant 1',1,1,10,1));
workflow = planWorkflowTest.EngineProbe(config);
robustData = intervalRobustData(workflow);
intervalTag = workflow.intervalDoseCacheTagPublic(robustData);
intervalContextA = workflow.intervalCacheContextPublic(robustData);
intervalContextB = intervalContextA;
intervalContextB.interval.targetName = 'Changed target';
intervalKeyA = workflow.cacheKeyPublic(intervalTag,struct(), ...
    intervalContextA);
intervalKeyB = workflow.cacheKeyPublic(intervalTag,struct(), ...
    intervalContextB);

verifyNotEqual(testCase,intervalKeyA,intervalKeyB);
verifyEqual(testCase,derivedInputStem(intervalKeyA), ...
    derivedInputStem(intervalKeyB));

config = baseEngineConfig(testCase);
config.plan_template = 'PROB2_001';
config.precompute.robustPlans = robustPlanConfig('probPlan','PROB2', ...
    'MeanVariance','PROB2','wcScen',[5 10 5], ...
    robustVariantConfig('variant_1','Variant 1',1,1,1,1));
workflow = planWorkflowTest.EngineProbe(config);
robustData = intervalRobustData(workflow);
probTag = workflow.probDoseCacheTagPublic(robustData);
probContextA = workflow.probCacheContextPublic(robustData);
probContextB = probContextA;
probContextB.prob.targetName = 'Changed target';
probKeyA = workflow.cacheKeyPublic(probTag,struct(),probContextA);
probKeyB = workflow.cacheKeyPublic(probTag,struct(),probContextB);

verifyNotEqual(testCase,probKeyA,probKeyB);
verifyEqual(testCase,derivedInputStem(probKeyA), ...
    derivedInputStem(probKeyB));
end

function testRobustNominalDoseCacheTagKeepsPlanIdAndNominalScenario(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig('customPlanId','INTERVAL2', ...
    'Interval2','INTERVAL2','wcScen',[5 10 5], ...
    robustVariantConfig('theta_10','Variant 1',1,1,10,1));
workflow = planWorkflowTest.EngineProbe(config);

descriptor = workflow.cacheDescriptorPublic( ...
    'robustNominal_Interval2',struct());
cacheMetadata = workflow.cacheMetadataPublic( ...
    'robustNominal_Interval2',struct());

verifyEqual(testCase,descriptor.artifact.kind,'robust');
verifyEqual(testCase,descriptor.artifact.planId,'Interval2');
verifyEqual(testCase,descriptor.artifact.role,'nominal');
verifyEqual(testCase,descriptor.identity.scenario.scen_mode,'nomScen');
verifyEqual(testCase,cacheMetadata.planId,'Interval2');
verifyEqual(testCase,cacheMetadata.artifact.role,'nominal');
verifyTrue(testCase,contains(descriptor.relativeKey,'nomScen'));
verifyFalse(testCase,contains(descriptor.relativeKey,'wcScen'));
end

function testRobustNominalCacheArtifactsArePlanSpecific(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'comparison_001';
config.precompute.robustPlans = [ ...
    robustPlanConfig('robust_1','Nominal plan','PTV', ...
    'none','wcScen',[5 10 5], ...
    robustVariantConfig('variant_1','Variant 1',1,1,1,1)); ...
    robustPlanConfig('robust_2','Interval plan','Interval2', ...
    'INTERVAL2','wcScen',[5 10 5], ...
    robustVariantConfig('theta_1','Variant 1',1,1,1,1))];
workflow = planWorkflowTest.EngineProbe(config);

referenceMetadata = workflow.cacheMetadataPublic('reference',struct());
nominalMetadataA = workflow.cacheMetadataPublic( ...
    'robustNominal_PTV',struct());
nominalMetadataB = workflow.cacheMetadataPublic( ...
    'robustNominal_Interval2',struct());
descriptorA = workflow.cacheDescriptorPublic( ...
    'robustNominal_PTV',struct());
descriptorB = workflow.cacheDescriptorPublic( ...
    'robustNominal_Interval2',struct());

verifyFalse(testCase,isfield(referenceMetadata,'planId') && ...
    ~isempty(referenceMetadata.planId));
verifyEqual(testCase,nominalMetadataA.planId,'PTV');
verifyEqual(testCase,nominalMetadataB.planId,'Interval2');
verifyNotEqual(testCase,nominalMetadataA.planId, ...
    nominalMetadataB.planId);
verifyEqual(testCase,nominalMetadataA.artifact.role,'nominal');
verifyEqual(testCase,nominalMetadataB.artifact.role,'nominal');
verifyEqual(testCase,descriptorA.tag,'robustNominal_PTV');
verifyEqual(testCase,descriptorB.tag,'robustNominal_Interval2');
verifyEqual(testCase,descriptorA.identity.scenario.scen_mode,'nomScen');
verifyEqual(testCase,descriptorB.identity.scenario.scen_mode,'nomScen');
end

function testDoseCacheMetadataIsReferenceOrPlanSpecific(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'comparison_001';
config.precompute.reference.robustnessMode = 'none';
config.precompute.robustPlans = [ ...
    robustPlanConfig('planA','Plan A','PTV','none','wcScen', ...
    [5 10 5],robustVariantConfig('variant_1','Variant 1',1,1,1,1)); ...
    robustPlanConfig('planB','Plan B','Interval2','INTERVAL2','wcScen', ...
    [7 8 9],robustVariantConfig('theta_1','Variant 1',1,1,1,1))];
workflow = planWorkflowTest.EngineProbe(config);

referenceMetadata = workflow.cacheMetadataPublic('reference',struct());
planAMetadata = workflow.cacheMetadataPublic('robust_PTV',struct());
planBMetadata = workflow.cacheMetadataPublic('robust_Interval2',struct());
planAKey = workflow.cacheKeyPublic('robust_PTV');
planBKey = workflow.cacheKeyPublic('robust_Interval2');

verifyEqual(testCase,referenceMetadata.robustnessMode,'none');
verifyFalse(testCase,isfield(referenceMetadata,'planId') && ...
    ~isempty(referenceMetadata.planId));
verifyEqual(testCase,planAMetadata.planId,'PTV');
verifyEqual(testCase,planBMetadata.planId,'Interval2');
verifyTrue(testCase,contains(planAKey,fullfile('dij')));
verifyTrue(testCase,contains(planBKey,fullfile('dij')));
verifyFalse(testCase,contains(planAKey,'planA'));
verifyFalse(testCase,contains(planBKey,'planB'));
verifyNotEqual(testCase,planAKey,planBKey);
end

function testPhysicallyEquivalentRobustPlansShareDoseCacheKey(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'comparison_001';
config.precompute.robustPlans = [ ...
    robustPlanConfig('planA','Plan A','PTV','none','wcScen', ...
    [5 10 5],robustVariantConfig('variant_1','Variant 1',1,1,1,1)); ...
    robustPlanConfig('planB','Plan B','Interval2','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,2,1))];
workflow = planWorkflowTest.EngineProbe(config);

planAKey = workflow.cacheKeyPublic('robust_PTV');
planBKey = workflow.cacheKeyPublic('robust_Interval2');

verifyEqual(testCase,planAKey,planBKey);
end

function testRobustDataContextMustBeExplicit(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig('intervalPlan','INTERVAL2', ...
    'Interval2','INTERVAL2','wcScen',[5 10 5], ...
    robustVariantConfig('theta_10','Variant 1',1,1,10,1));
workflow = planWorkflowTest.EngineProbe(config);

verifyError(testCase,@() workflow.robustDoseCacheTagPublic(struct()), ...
    ['planWorkflow:cache:DoseInfluenceCacheService:' ...
    'MissingRobustPlanConfig']);

robustData.planConfig = workflow.runConfig.precompute.robustPlans(1);
verifyError(testCase,@() workflow.robustDoseCacheTagPublic(robustData), ...
    ['planWorkflow:cache:DoseInfluenceCacheService:' ...
    'MissingRobustStrategy']);
end

function testPlanTemplateMustBeRelativeToDescription(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'prostate/interval2_001';

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:templates:PlanTemplate:InvalidTemplateId');
end

function testPlanTargetFieldIsRejected(testCase)
config = baseEngineConfig(testCase);
config.prepare.plan_target = 'CTV';

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:WorkflowBase:UnsupportedStageConfigField');
end

function testPlanObjectivesFieldIsRejected(testCase)
config = baseEngineConfig(testCase);
fieldName = ['plan_' 'objectives'];
config.(fieldName) = '4';

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:Engine:UnsupportedConfigField');
end

function testSamplingDicomMetadataAliasUpdatesSamplingOnly(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));
metadata = struct('ctSeriesUIDs',{{'sample-series'}});
workflow.configureStagePublic('sample',struct('dicomMetadata',metadata));

verifyFalse(testCase,isfield(workflow.runConfig.dicomMetadata,'ctSeriesUIDs'));
verifyEqual(testCase,workflow.runConfig.sampling_dicomMetadata.ctSeriesUIDs, ...
    {'sample-series'});
end

function testSamplingLegacyScenarioAliasesAreRejected(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));

verifyError(testCase, ...
    @() workflow.configureStagePublic('sample',struct( ...
    'wcSigma',1.0)), ...
    'planWorkflow:WorkflowBase:UnsupportedStageConfigField');
end

function testConflictingSamplingDicomMetadataAliasesAreRejected(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));

verifyError(testCase, ...
    @() workflow.configureStagePublic('sample',struct( ...
    'dicomMetadata',struct('patientID','A'), ...
    'sampling_dicomMetadata',struct('patientID','B'))), ...
    'planWorkflow:Engine:ConflictingSamplingConfig');
end

function varargout = passthroughTask(~,~,~,~,~,~,taskFunction)
[varargout{1:nargout}] = taskFunction();
end

function config = baseEngineConfig(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
config = struct();
config.radiationMode = 'photons';
config.workflowType = 'test';
config.description = 'prostate';
config.caseID = 'case';
config.precompute = planWorkflow.config.RobustPlanConfig.defaults();
config.sampling_scen_mode = 'impScen_permuted5';
config.sampling_ctActive = true;
config.sampling_ctReferenceScenId = 1;
config.sampling_ctScenProb = [];
config.sampling_setupActive = true;
config.sampling_rangeActive = false;
config.sampling_gantryActive = false;
config.sampling_couchActive = false;
config.sampling_shiftSD = [5 10 5];
config.sampling_wcSigma = 1.5;
config.sampling_rangeAbsSD = 0;
config.sampling_rangeRelSD = 0;
config.sampling_numOfRangeGridPoints = 1;
config.sampling_gantryAngleSD = 0;
config.sampling_couchAngleSD = 0;
config.sampling_size = 50;
config.sampling_randomSeed = [];
config.runId = 'engine-config-test';
config.outputRootPath = fullfile(fixture.Folder,'output');
config.patientDataPath = fullfile(fixture.Folder,'patients');
config.cacheRootPath = fullfile(fixture.Folder,'cache');
end

function config = genericScenarioConfig()
config = struct();
config.scen_mode = 'nomScen';
config.ctActive = true;
config.ctReferenceScenId = 1;
config.ctScenProb = [];
config.setupActive = true;
config.rangeActive = false;
config.gantryActive = false;
config.couchActive = false;
config.shiftSD = [5 10 5];
config.wcSigma = 1;
config.rangeAbsSD = 0;
config.rangeRelSD = 0;
config.numOfRangeGridPoints = 1;
config.gantryAngleSD = 0;
config.couchAngleSD = 0;
config.random_size = 50;
config.randomSeed = [];
config.sampling_size = 50;
config.sampling_ctScenProb = [];
end

function plan = robustPlanConfig(id,label,objectiveSetName,robustness, ...
        scenMode,shiftSD,variants)
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = id;
plan.label = label;
plan.objectiveSetName = objectiveSetName;
plan.robustnessMode = robustness;
plan.scenario = planWorkflow.config.RobustPlanConfig.defaultScenario( ...
    scenMode);
plan.scenario.shiftSD = shiftSD;
plan.scenario.random_size = 12;
plan.variants = robustVariantsForStrategy(variants,robustness);
end

function ix = robustPlanIx(robustPlans,objectiveSetName)
ix = find(strcmp({robustPlans.objectiveSetName},objectiveSetName),1);
if isempty(ix)
    ix = find(strcmp({robustPlans.id},objectiveSetName),1);
end
end

function ct = multiScenarioCt(numScenarios)
ct = struct();
ct.numOfCtScen = numScenarios;
ct.cubeDim = [1 1 1];
ct.resolution = struct('x',1,'y',1,'z',1);
ct.cube = cell(1,numScenarios);
ct.cubeHU = cell(1,numScenarios);
for scenarioIx = 1:numScenarios
    ct.cube{scenarioIx} = scenarioIx;
    ct.cubeHU{scenarioIx} = scenarioIx * 100;
end
end

function cst = multiScenarioCst(numScenarios)
cst = cell(1,6);
cst{1,1} = 0;
cst{1,2} = 'CTV';
cst{1,3} = 'TARGET';
cst{1,4} = cell(1,numScenarios);
for scenarioIx = 1:numScenarios
    cst{1,4}{scenarioIx} = sprintf('ct%d-voi1',scenarioIx);
end
cst{1,5} = struct();
cst{1,6} = [];
end

function pln = parallelScenarioPlan(engine,numScenarios)
pln = struct();
pln.propDoseCalc = engine;
pln.multScen = struct('totNumScen',numScenarios);
end

function verifyDerivedKeyUsesInputStem(testCase,derivedKey,robustKey)
[~,robustStem] = fileparts(robustKey);
verifyEqual(testCase,derivedInputStem(derivedKey),robustStem);
end

function inputStem = derivedInputStem(cacheKey)
[~,fileStem] = fileparts(cacheKey);
inputStem = fileStem(1:end - 17);
end

function variant = robustVariantConfig(id,label,p1,p2,theta1,theta2)
variant = struct();
variant.id = id;
variant.label = label;
variant.p1 = p1;
variant.p2 = p2;
variant.theta1 = theta1;
variant.theta2 = theta2;
variant.KMode = 'dynamic';
variant.kmax = 10;
variant.retentionThreshold = 1.0;
end

function variants = robustVariantsForStrategy(variants,strategy)
inputVariants = variants(:)';
variants = repmat( ...
    planWorkflow.config.RobustPlanConfig.defaultVariant(strategy,1), ...
    1,numel(inputVariants));
for i = 1:numel(inputVariants)
    variant = inputVariants(i);
    clean = struct('id',variant.id,'label',variant.label);
    switch char(strategy)
        case 'c-COWC'
            clean.p1 = variant.p1;
            clean.p2 = variant.p2;
        case 'INTERVAL2'
            clean.theta1 = variant.theta1;
        case 'INTERVAL3'
            clean.theta1 = variant.theta1;
            clean.theta2 = variant.theta2;
    end
    variants(i) = clean;
end
end

function robustData = robustDataForLabel(label,robustness,variant)
robustData = struct();
robustData.planConfig = struct();
robustData.planConfig.label = label;
robustData.planConfig.robustnessMode = robustness;
robustData.planConfig.variants = robustVariantsForStrategy(variant,robustness);
end

function robustData = intervalRobustData(workflow)
robustData = struct();
robustData.planConfig = workflow.runConfig.precompute.robustPlans(1);
robustData.strategy = planWorkflow.robustness.AbstractStrategy.create( ...
    robustData.planConfig.robustnessMode);
end

function robustData = nominalSelectionData(planId,source,robustness, ...
        requiresIntervalDij,requiresProbDij)
if nargin < 5
    requiresProbDij = false;
end
robustData = struct();
robustData.planConfig = planWorkflow.config.RobustPlanConfig.defaultPlan();
robustData.planConfig.id = planId;
robustData.planConfig.robustnessMode = robustness;
robustData.planConfig.hasNominalObjectives = true;
robustData.planConfig.requiresNominalDij = true;
robustData.planConfig.requiresScenarioDij = false;
robustData.planConfig.requiresIntervalDij = logical(requiresIntervalDij);
robustData.planConfig.requiresProbDij = logical(requiresProbDij);
robustData.ct = struct('numOfCtScen',1);
robustData.cst = {1};
robustData.pln = struct('source',[planId '-robust-plan'], ...
    'propOpt',struct());
robustData.stf = struct('source',[planId '-robust-stf'], ...
    'totalNumOfBixels',1);
robustData.stfNominal = struct('source',[source '-stf'], ...
    'totalNumOfBixels',1);
robustData.dijNominal = struct('source',source);
robustData.plnNominal = struct('source',source,'propOpt',struct());
end

function dij = referenceDij()
dij = struct();
dij.totalNumOfBixels = 3;
dij.physicalDose = {sparse(1,3)};
dij.scenarioModel = matRad_NominalScenario();
end

function timing = sampleDijPrecomputingTiming(artifact)
referenceTiming = planWorkflow.performance.PrecomputeTiming.single( ...
    10,'reference','Reference','dij',[]);
inputTiming = planWorkflow.performance.PrecomputeTiming.single( ...
    20,'input','Robust','dij_robust',referenceTiming);
timing = planWorkflow.performance.PrecomputeTiming.combine( ...
    inputTiming,'derived',artifact,10,'Robust');
end

function sizeData = sampleDijPrecomputingSize(artifact)
referenceSize = planWorkflow.performance.PrecomputeSize.single( ...
    10,'reference','Reference','dij',[]);
inputSize = planWorkflow.performance.PrecomputeSize.single( ...
    20,'input','Robust','dij_robust',referenceSize);
sizeData = planWorkflow.performance.PrecomputeSize.combine( ...
    inputSize,'derived',artifact,10,'Robust');
end

function dij = intervalNominalDij(dij_interval)
dij = struct();
numRows = size(dij_interval.center,1);
numColumns = size(dij_interval.center,2);
dij.totalNumOfBixels = numColumns;
dij.physicalDose = {sparse(numRows,numColumns)};
if isfield(dij_interval,'quantityField') && ...
        ~isempty(dij_interval.quantityField) && ...
        ~strcmp(char(dij_interval.quantityField),'physicalDose')
    dij.(char(dij_interval.quantityField)) = ...
        {sparse(numRows,numColumns)};
end
dij.scenarioModel = matRad_NominalScenario();
end

function dij_interval = intervalDij(numOfBixels)
dij_interval = struct();
dij_interval.center = sparse(2,numOfBixels);
dij_interval.radius = sparse(2,numOfBixels);
dij_interval.scenarioDijIx = [1;2];
dij_interval.targetSubIx = [1;2];
dij_interval.OARSubIx = [4;5];
dij_interval.radiusMode = 'std';
dij_interval.OARRadiusRank = [1;2];
dij_interval.OARRadiusFactor = { ...
    sparse(numOfBixels,1), ...
    sparse(numOfBixels,2)};
dij_interval.quantity = 'physicalDose';
dij_interval.quantityField = 'physicalDose';
end

function dij = intervalDijContext(dij_interval)
dij = struct();
dij.totalNumOfBixels = size(dij_interval.center,2);
dij.physicalDose = {dij_interval.center};
dij.numOfScenarios = 1;
dij.scenarioModel = matRad_NominalScenario();
end

function dij_prob = probDij(numOfBixels)
dij_prob = struct();
dij_prob.expected = sparse(2,numOfBixels);
dij_prob.Omega = {sparse(numOfBixels,numOfBixels), ...
    sparse(numOfBixels,numOfBixels)};
dij_prob.voiSubIx = {[1;2],3};
dij_prob.scenarioDijIx = [1;2];
dij_prob.scenarioWeights = [0.4;0.6];
dij_prob.refScen = 1;
dij_prob.probabilisticMode = 'PROB';
dij_prob.quantity = 'physicalDose';
dij_prob.quantityField = 'physicalDose';
end

function dij = probDijContext(dij_prob)
dij = struct();
dij.totalNumOfBixels = size(dij_prob.expected,2);
dij.physicalDose = {dij_prob.expected};
dij.numOfScenarios = 1;
dij.scenarioModel = matRad_NominalScenario();
dij.doseGrid = struct('dimensions',[size(dij_prob.expected,1) 1 1]);
end

function stf = stfForBixels(numOfBixels)
stf = struct();
stf.totalNumOfBixels = numOfBixels;
stf.numOfRays = 1;
stf.numOfBixelsPerRay = numOfBixels;
stf.gantryAngle = 0;
stf.couchAngle = 0;
stf.bixelWidth = 5;
stf.isoCenter = [0 0 0];
stf.ray = struct();
stf.ray.targetPoint_bev = [0 0 0];
stf.ray.rayPos_bev = [(1:numOfBixels)' zeros(numOfBixels,2)];
end
