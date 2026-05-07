function tests = testEngineConfig
tests = functiontests(localfunctions);
end

function testUnsupportedRootAnalysisFieldIsRejected(testCase)
config = baseEngineConfig(testCase);
config.gammaCriteria = [3 3];

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:Engine:UnsupportedConfigField');
end

function testSingleRobustPlanUsesCanonicalRobustnessMode(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2 plan','robust_1','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
workflow = planWorkflow.Workflow(config);

robustPlans = workflow.runConfig.precompute.robustPlans;
verifyEqual(testCase,numel(robustPlans),1);
verifyEqual(testCase,robustPlans(1).robustnessMode,'INTERVAL2');
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
    robustPlanConfig('ptvPlan','PTV plan','robust_1', ...
    'none','wcScen',[5 10 5], ...
    robustVariantConfig('variant_1','Variant 1',1,1,1,1)); ...
    robustPlanConfig('intervalPlan','Interval plan','robust_2', ...
    'INTERVAL2','random',[1 2 3], ...
    [robustVariantConfig('theta_low','Theta low',1,1,10,1); ...
    robustVariantConfig('theta_high','Theta high',1,1,20,1)])];

workflow = planWorkflowTest.EngineProbe(config);

robustPlans = workflow.runConfig.precompute.robustPlans;
verifyEqual(testCase,numel(robustPlans),2);
verifyEqual(testCase,robustPlans(1).robustnessMode, ...
    'none');
verifyEqual(testCase,robustPlans(1).scenario.mode, ...
    'wcScen');
verifyEqual(testCase,robustPlans(2).robustnessMode, ...
    'INTERVAL2');
verifyEqual(testCase,robustPlans(2).scenario.mode, ...
    'random');
verifyEqual(testCase,robustPlans(2).scenario.shiftSD, ...
    [1 2 3]);
verifyEqual(testCase,[robustPlans(2).variants.theta1], ...
    [10 20]);
end

function testNamedRobustPlansAreAcceptedForMacros(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'comparison_001';
config.precompute.robustPlans = struct();
config.precompute.robustPlans.robust_1.label = 'PTV';
config.precompute.robustPlans.robust_1.objectiveSetName = 'robust_1';
config.precompute.robustPlans.robust_1.scenario = ...
    planWorkflow.config.RobustPlanConfig.defaultScenario('nomScen');
config.precompute.robustPlans.robust_1.scenario.ctActive = false;
config.precompute.robustPlans.robust_1.scenario.setupActive = false;
config.precompute.robustPlans.robust_1.variants = ...
    robustVariantsForStrategy( ...
    robustVariantConfig('variant_1','Variant 1',1,1,1,1),'none');

config.precompute.robustPlans.robust_2.label = 'INTERVAL2';
config.precompute.robustPlans.robust_2.objectiveSetName = 'robust_2';
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
verifyEqual(testCase,numel(robustPlans),2);
verifyEqual(testCase,{robustPlans.id}, ...
    {'robust_1','robust_2'});
verifyEqual(testCase,{robustPlans.label}, ...
    {'PTV','INTERVAL2'});
verifyEqual(testCase,robustPlans(1).robustnessMode, ...
    'none');
verifyEqual(testCase,robustPlans(2).robustnessMode, ...
    'INTERVAL2');
verifyEqual(testCase,[robustPlans(2).variants.theta1], ...
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
intervalData.dij_intervalContext = struct('numOfScenarios',1);
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
    'robust_1','INTERVAL2','wcScen',[5 10 5], ...
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
    'robust_1','INTERVAL2','wcScen',[5 10 5], ...
    [robustVariantConfig('theta_1','Variant 1',1,1,1,1); ...
    robustVariantConfig('theta_5','Variant 2',1,1,5,1)]);
workflow = planWorkflowTest.EngineProbe(config);

verifyEqual(testCase, ...
    planWorkflow.results.PlanLabels.planTimingLabel( ...
	    workflow.runConfig,'INTERVAL2 / Variant 2','robust', ...
	    'robust_1','theta_5'), ...
	    'INTERVAL2 (theta1=5)');
end

function testAnalysisResultsDoNotWriteGuiLog(testCase)
messages = {};
results = struct();
results.reference = struct('label','Reference (Nominal)','qi',[]);
planWorkflow.analysis.ResultLogger.log(@captureMessage,results);

verifyNotEmpty(testCase,messages);

    function captureMessage(message)
        messages{end + 1} = message; %#ok<AGROW>
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

function testIntervalPlanApplies4DOptimizationConfig(testCase)
config = baseEngineConfig(testCase);
plan = robustPlanConfig('intervalPlan','INTERVAL2','robust_1', ...
    'INTERVAL2','wcScen',[5 10 5], ...
    robustVariantConfig('theta_5','theta1=5',1,1,5,1));
plan.scenario.ctActive = true;
config.precompute.robustPlans = plan;
workflow = planWorkflowTest.EngineProbe(config);

robustData = struct();
robustData.planConfig = workflow.runConfig.precompute.robustPlans(1);
robustData.strategy = planWorkflow.robustness.IntervalStrategy('INTERVAL2');
robustData.pln = struct('propOpt',struct());

pln = workflow.planForRobustDataPlanIndexPublic(robustData,1);

verifyEqual(testCase,pln.propOpt.theta1,5);
verifyEqual(testCase,pln.propOpt.scen4D,'all');
end

function testDisabled4DOptimizationRemovesScen4DFromPlan(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2','robust_1','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_5','theta1=5',1,1,5,1));
config.precompute.robustPlans.scenario.ctActive = false;
config.precompute.robustPlans.optimization4D.enabled = true;
workflow = planWorkflowTest.EngineProbe(config);

robustData = struct();
robustData.planConfig = workflow.runConfig.precompute.robustPlans(1);
robustData.strategy = planWorkflow.robustness.IntervalStrategy('INTERVAL2');
robustData.pln = struct('propOpt',struct('scen4D','all'));

pln = workflow.planForRobustDataPlanIndexPublic(robustData,1);

verifyFalse(testCase,isfield(pln.propOpt,'scen4D'));
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
    'intervalPlan','INTERVAL3','robust_1','INTERVAL3','wcScen', ...
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

function testInterval3DoseConfigEnablesParallelSvdWithoutCacheKey(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'interval3_001';
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL3','robust_1','INTERVAL3','wcScen', ...
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
verifyFalse(testCase,isfield(cacheContext.interval,'UseParallel'));
end

function testPlanTaskResourceDetailsIncludeDoseInfluenceAndIterations(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));

dij = referenceDij();
detail = workflow.planTaskResourceDetailPublic( ...
    'precompute','reference','Reference','doseInfluence','','',{dij});
detailData = jsondecode(detail);
verifyEqual(testCase,detailData.dij.numberOfScenarios,1);
verifyEqual(testCase,detailData.dij.matrix.dimensions,'1x3');
verifyGreaterThan(testCase,detailData.dij.matrix.size.bytes,0);
verifyGreaterThan(testCase,detailData.dij.size.bytes,0);

robustData = struct();
robustData.dij = referenceDij();
robustData.dij_interval = intervalDij(3);
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
    'truncatedOARSvdFactors');
verifyEqual(testCase, ...
    detailData.dij_interval.radiusComponents.memoryModel, ...
    'scenarioBixelMatrixScenarioGramRetainedFactors');
verifyEqual(testCase,detailData.dij_interval.radiusComponents.U.count,2);
verifyEqual(testCase,detailData.dij_interval.radiusComponents.U.totalRows,4);
verifyEqual(testCase,detailData.dij_interval.radiusComponents.U.totalColumns,3);
verifyEqual(testCase,detailData.dij_interval.radiusComponents.S.count,2);
verifyEqual(testCase,detailData.dij_interval.radiusComponents.S.totalRows,3);
verifyEqual(testCase,detailData.dij_interval.radiusComponents.S.totalColumns,3);
verifyEqual(testCase,detailData.dij_interval.radiusComponents.k.sum,3);
verifyGreaterThan(testCase, ...
    detailData.dij_interval.radiusComponents.totalSize.bytes,0);
verifyGreaterThan(testCase,detailData.dij_interval.totalSize.bytes,0);
verifyFalse(testCase,contains(jsonencode(detailData.dij_interval), ...
    ['OAR covariance/' 'SVD estimated memory']));

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
    'intervalPlan','INTERVAL2','robust_1','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
config.dose_pulling2 = false;
workflow = planWorkflowTest.EngineProbe(config);
workflow.data.dij = referenceDij();

scenarioModel = matRad_WorstCaseScenarios();
scenarioModel.scenarioDimensionActive = {'ct','setup'};
scenarioModel.shiftSD = [1 2 3];
scenarioModel.wcSigma = 1;

robustData = intervalRobustData(workflow);
robustData.pln.multScen = scenarioModel;
robustData.pln.propOpt = struct();
robustData.stf = stfForBixels(workflow.data.dij.totalNumOfBixels);

cacheContext = workflow.intervalCacheContextPublic(robustData);
intervalTag = workflow.intervalDoseCacheTagPublic(robustData);
cacheFile = workflow.cacheFilePublic(intervalTag,robustData.pln, ...
    cacheContext);
mkdir(fileparts(cacheFile));
dij_interval = intervalDij(workflow.data.dij.totalNumOfBixels); %#ok<NASGU>
dij_intervalContext = intervalDijContext(dij_interval); %#ok<NASGU>
cacheMetadata = workflow.cacheMetadataPublic( ...
    intervalTag,robustData.pln,cacheContext); %#ok<NASGU>
cacheMetadata.intervalMode = 'INTERVAL2';
cacheMetadata.scenarioFingerprint = scenarioModel.fingerprint();
builtin('save',cacheFile,'dij_interval','dij_intervalContext', ...
    'cacheMetadata','-v7.3');

[cacheHit,robustData] = workflow.loadCachedIntervalDoseInfluencePublic( ...
    robustData);
robustData = workflow.useIntervalDijForOptimizationPublic( ...
    robustData);

verifyTrue(testCase,cacheHit);
verifyTrue(testCase,isfield(robustData,'dij_interval'));
verifyTrue(testCase,isfield(robustData.pln.propOpt,'dij_interval'));
verifyTrue(testCase,isfield(robustData,'plnForOptimization'));
verifyEqual(testCase,robustData.pln.multScen.numScenarios(), ...
    scenarioModel.numScenarios());
verifyEqual(testCase,robustData.plnForOptimization.multScen.numScenarios(),1);
verifyEqual(testCase, ...
    robustData.plnForOptimization.multScen.getDijScenarioIndex(1),1);
verifyFalse(testCase,isfield(robustData,'robustDijWasLoaded'));
verifyTrue(testCase,robustData.usesIntervalDijForOptimization);
verifyEqual(testCase,robustData.dij.totalNumOfBixels, ...
    workflow.data.dij.totalNumOfBixels);
verifyEqual(testCase,robustData.dij.numOfScenarios,1);
verifyEqual(testCase,robustData.dij.physicalDose{1}, ...
    robustData.dij_interval.center);

planForOptimization = workflow.planForRobustDataPlanIndexPublic( ...
    robustData,1);
verifyEqual(testCase,planForOptimization.multScen.numScenarios(),1);
verifyEqual(testCase,planForOptimization.multScen.getDijScenarioIndex(1),1);
end

function testStaleIntervalDijCacheIsRejected(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2','robust_1','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
workflow = planWorkflowTest.EngineProbe(config);
workflow.data.dij = referenceDij();

scenarioModel = matRad_WorstCaseScenarios();
scenarioModel.scenarioDimensionActive = {'ct','setup'};
scenarioModel.shiftSD = [1 2 3];
scenarioModel.wcSigma = 1;
robustData = intervalRobustData(workflow);
robustData.pln.multScen = scenarioModel;
robustData.pln.propOpt = struct();
robustData.stf = stfForBixels(workflow.data.dij.totalNumOfBixels);

cacheContext = workflow.intervalCacheContextPublic(robustData);
intervalTag = workflow.intervalDoseCacheTagPublic(robustData);
cacheFile = workflow.cacheFilePublic(intervalTag,robustData.pln, ...
    cacheContext);
mkdir(fileparts(cacheFile));
dij_interval = intervalDij(workflow.data.dij.totalNumOfBixels); %#ok<NASGU>
dij_intervalContext = intervalDijContext(dij_interval); %#ok<NASGU>
cacheMetadata = workflow.cacheMetadataPublic( ...
    intervalTag,robustData.pln,cacheContext); %#ok<NASGU>
cacheMetadata.intervalMode = 'INTERVAL2';
cacheMetadata.scenarioFingerprint = 'different-scenario';
builtin('save',cacheFile,'dij_interval','dij_intervalContext', ...
    'cacheMetadata','-v7.3');

cacheHit = workflow.loadCachedIntervalDoseInfluencePublic(robustData);

verifyFalse(testCase,cacheHit);
end

function testIntervalCacheContextIncludesPrecomputeStfGeometry(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2','robust_1','INTERVAL2','wcScen', ...
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
robustPlan = robustPlanConfig('intervalPlan','INTERVAL2 plan','robust_1', ...
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
robustPlan = robustPlanConfig('randomPlan','Random plan','robust_1', ...
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
robustPlan = robustPlanConfig('badPlan','Bad plan','robust_1', ...
    'INTERVAL2','wcScen',[5 10 5], ...
    robustVariantConfig('theta_1','Variant 1',1,1,1,1));
robustPlan.scenario.rangeActive = true;
config.precompute.robustPlans = robustPlan;

verifyError(testCase,@() planWorkflow.Workflow(config), ...
    'planWorkflow:scenario:InvalidActiveDimensionScale');
end

function testActiveAngularDimensionScaleValidation(testCase)
config = baseEngineConfig(testCase);
robustPlan = robustPlanConfig('badPlan','Bad plan','robust_1', ...
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

function testInvalidRandomSeedIsRejected(testCase)
config = baseEngineConfig(testCase);
robustPlan = robustPlanConfig('badPlan','Bad plan','robust_1', ...
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

function testAngularDimensionsRequireRandomScenarioMode(testCase)
config = genericScenarioConfig();
config.gantryActive = true;
config.gantryAngleSD = 2;
config.numOfBeams = 2;

verifyError(testCase,@() planWorkflow.scenario.createModel( ...
    [],'wcScen',config,'optimization'), ...
    'planWorkflow:scenario:createModel:AngularDimensionsRequireRandom');
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
    'intervalPlan','INTERVAL2 plan','robust_1','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
configB = baseEngineConfig(testCase);
configB.precompute.robustPlans = configA.precompute.robustPlans;
configB.precompute.robustPlans(1).scenario.wcSigma = ...
    configA.precompute.robustPlans(1).scenario.wcSigma + 0.5;

workflowA = planWorkflowTest.EngineProbe(configA);
workflowB = planWorkflowTest.EngineProbe(configB);

verifyNotEqual(testCase,workflowA.cacheKeyPublic('robust_robust_1'), ...
    workflowB.cacheKeyPublic('robust_robust_1'));
end

function testRobustDoseCacheRejectsStrategyOnlyTag(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig( ...
    'intervalPlan','INTERVAL2 plan','robust_1','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,1,1));
workflow = planWorkflowTest.EngineProbe(config);

verifyError(testCase,@() workflow.cacheKeyPublic('robust_INTERVAL2'), ...
    'planWorkflow:cache:CacheIdentity:UnknownRobustPlanId');
end

function testDoseInfluenceCacheTagsUsePlanId(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig('customPlanId','INTERVAL2', ...
    'robust_1','INTERVAL2','wcScen',[5 10 5], ...
    robustVariantConfig('theta_10','Variant 1',1,1,10,1));
workflow = planWorkflowTest.EngineProbe(config);

robustData = intervalRobustData(workflow);
robustTag = workflow.robustDoseCacheTagPublic(robustData);
intervalTag = workflow.intervalDoseCacheTagPublic(robustData);
intervalKey = workflow.cacheKeyPublic(intervalTag);

verifyEqual(testCase,robustTag,'robust_robust_1');
verifyEqual(testCase,intervalTag,'interval_robust_1');
verifyTrue(testCase,contains(intervalKey, ...
    fullfile('interval','INTERVAL2')));
verifyFalse(testCase,contains(intervalKey,'customPlanId'));
verifyTrue(testCase,contains(intervalKey,'INTERVAL2'));
end

function testRobustNominalDoseCacheTagKeepsPlanIdAndNominalScenario(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig('customPlanId','INTERVAL2', ...
    'robust_1','INTERVAL2','wcScen',[5 10 5], ...
    robustVariantConfig('theta_10','Variant 1',1,1,10,1));
workflow = planWorkflowTest.EngineProbe(config);

descriptor = workflow.cacheDescriptorPublic( ...
    'robustNominal_robust_1',struct());
cacheMetadata = workflow.cacheMetadataPublic( ...
    'robustNominal_robust_1',struct());

verifyEqual(testCase,descriptor.artifact.kind,'robust');
verifyEqual(testCase,descriptor.artifact.planId,'robust_1');
verifyEqual(testCase,descriptor.artifact.role,'nominal');
verifyEqual(testCase,descriptor.identity.scenario.scen_mode,'nomScen');
verifyEqual(testCase,cacheMetadata.planId,'robust_1');
verifyEqual(testCase,cacheMetadata.artifact.role,'nominal');
verifyTrue(testCase,contains(descriptor.relativeKey,'nomScen'));
verifyFalse(testCase,contains(descriptor.relativeKey,'wcScen'));
end

function testDoseCacheMetadataIsReferenceOrPlanSpecific(testCase)
config = baseEngineConfig(testCase);
config.plan_template = 'comparison_001';
config.precompute.reference.robustnessMode = 'none';
config.precompute.robustPlans = [ ...
    robustPlanConfig('planA','Plan A','robust_1','none','wcScen', ...
    [5 10 5],robustVariantConfig('variant_1','Variant 1',1,1,1,1)); ...
    robustPlanConfig('planB','Plan B','robust_2','INTERVAL2','wcScen', ...
    [7 8 9],robustVariantConfig('theta_1','Variant 1',1,1,1,1))];
workflow = planWorkflowTest.EngineProbe(config);

referenceMetadata = workflow.cacheMetadataPublic('reference',struct());
planAMetadata = workflow.cacheMetadataPublic('robust_robust_1',struct());
planBMetadata = workflow.cacheMetadataPublic('robust_robust_2',struct());
planAKey = workflow.cacheKeyPublic('robust_robust_1');
planBKey = workflow.cacheKeyPublic('robust_robust_2');

verifyEqual(testCase,referenceMetadata.robustnessMode,'none');
verifyFalse(testCase,isfield(referenceMetadata,'planId') && ...
    ~isempty(referenceMetadata.planId));
verifyEqual(testCase,planAMetadata.planId,'robust_1');
verifyEqual(testCase,planBMetadata.planId,'robust_2');
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
    robustPlanConfig('planA','Plan A','robust_1','none','wcScen', ...
    [5 10 5],robustVariantConfig('variant_1','Variant 1',1,1,1,1)); ...
    robustPlanConfig('planB','Plan B','robust_2','INTERVAL2','wcScen', ...
    [5 10 5],robustVariantConfig('theta_1','Variant 1',1,1,2,1))];
workflow = planWorkflowTest.EngineProbe(config);

planAKey = workflow.cacheKeyPublic('robust_robust_1');
planBKey = workflow.cacheKeyPublic('robust_robust_2');

verifyEqual(testCase,planAKey,planBKey);
end

function testRobustDataContextMustBeExplicit(testCase)
config = baseEngineConfig(testCase);
config.precompute.robustPlans = robustPlanConfig('intervalPlan','INTERVAL2', ...
    'robust_1','INTERVAL2','wcScen',[5 10 5], ...
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

function dij = referenceDij()
dij = struct();
dij.totalNumOfBixels = 3;
dij.physicalDose = {sparse(1,3)};
dij.scenarioModel = matRad_NominalScenario();
end

function dij_interval = intervalDij(numOfBixels)
dij_interval = struct();
dij_interval.center = sparse(2,numOfBixels);
dij_interval.radius = sparse(2,numOfBixels);
dij_interval.scenarioDijIx = [1;2];
dij_interval.radiusComponents = struct();
dij_interval.radiusComponents.subIx = [4;5];
dij_interval.radiusComponents.k = [1;2];
dij_interval.radiusComponents.U = {sparse(2,1); sparse(2,2)};
dij_interval.radiusComponents.S = {sparse(1,1); sparse(2,2)};
dij_interval.radiusComponents.V = {sparse(3,1); sparse(3,2)};
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
