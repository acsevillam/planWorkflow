function tests = testMultiPlanSamplingArchitecture
tests = functiontests(localfunctions);
end

function testWorkflowIdentityIncludesEveryRobustPlan(testCase)
runConfigA = makeRunConfig();
runConfigB = runConfigA;
runConfigB.precompute.robustPlans(2).scenario.shiftSD = [9 9 9];

identityA = planWorkflow.results.WorkflowIdentity.fromRunConfig(runConfigA);
identityB = planWorkflow.results.WorkflowIdentity.fromRunConfig(runConfigB);

verifyEqual(testCase,identityA.robustPlanCount,2);
verifyEqual(testCase,{identityA.robustPlans.id}, ...
    {'robust_1','robust_2'});
verifyEqual(testCase,identityA.robustVariantCount,2);
verifyTrue(testCase,startsWith(identityA.robustPathLabel,'robust_multi_'));
verifyNotEqual(testCase,identityA.robustPathLabel, ...
    identityB.robustPathLabel);
verifyNotEqual(testCase,identityA.robustShiftLabel, ...
    identityB.robustShiftLabel);
end

function testEnginePathUsesAggregateRobustIdentity(testCase)
runConfigA = makeRunConfig();
runConfigB = runConfigA;
runConfigB.precompute.robustPlans(2).scenario.shiftSD = [9 9 9];

workflowA = planWorkflowTest.EngineProbe(runConfigA);
workflowB = planWorkflowTest.EngineProbe(runConfigB);
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','comparison_001');
robustObjectiveSets = ...
    planWorkflow.templates.PlanTemplate.robustObjectiveSets(template);

verifyNotEmpty(testCase,strfind(workflowA.rootPath,'robust_multi_'));
verifyNotEqual(testCase,workflowA.rootPath,workflowB.rootPath);
verifyEqual(testCase,numel(workflowA.data.workflowIdentity.robustPlans), ...
    numel(robustObjectiveSets));
verifyTrue(testCase,any(strcmp( ...
    {workflowA.data.workflowIdentity.robustPlans.id},'PTV')));
verifyTrue(testCase,any(strcmp( ...
    {workflowA.data.workflowIdentity.robustPlans.id},'Interval2')));
end

function testSamplingPlanSetUsesOneTransversalSamplingConfig(testCase)
runConfig = makeRunConfig();
data = samplingData(runConfig);

planSet = planWorkflow.sampling.SamplingPlanSet.fromData( ...
    runConfig,data);

verifyEqual(testCase,{planSet.entries.role}, ...
    {'reference','robust','robust'});
verifyEqual(testCase,{planSet.entries.planId}, ...
    {'reference','robust_1','robust_2'});
verifyEqual(testCase,planSet.samplingConfig.sampling_size,37);
verifyEqual(testCase,planSet.samplingConfig.sampling_scen_mode, ...
    'impScen_permuted5');
verifyEqual(testCase,numel(planSet.metadata),3);
end

function testSamplingScenarioBasisStoresEffectiveCtProbabilities(testCase)
runConfig = makeRunConfig();
data = samplingData(runConfig);
planSet = planWorkflow.sampling.SamplingPlanSet.fromData( ...
    runConfig,data);
samplingScenarioConfig = planWorkflow.config.ScenarioSpec.fromRunConfig( ...
    runConfig,'sampling');
samplingScenarioConfig = planWorkflow.config.ScenarioSpec.matRadScenario( ...
    samplingScenarioConfig);
samplingScenarioConfig = ...
    planWorkflow.sampling.SamplingPlanSet.withPlanSetBeamCount( ...
    samplingScenarioConfig,planSet);
effectiveCtScenProb = [1 0.5; 2 0.5];

basis = planWorkflow.sampling.SamplingPlanSet.scenarioBasis( ...
    planSet,samplingScenarioConfig,effectiveCtScenProb);

verifyEqual(testCase,basis.sampling.ctScenProb,effectiveCtScenProb);
verifyEqual(testCase,basis.sampling.ctScenProbMode,'uniform');
end

function testSamplingStructureValidationUsesSamplingCstOnly(testCase)
runConfig = makeRunConfigWithoutDescriptionEndpoints();
data = samplingData(runConfig);
data.robustPlans{2}.cst{2,2} = 'RENAMED_CTV';
context = struct('runConfig',runConfig,'data',data);

planWorkflow.sampling.SamplingService.validateStructures( ...
    context,minimalCst());
end

function testSamplingStructureValidationIgnoresStructureOrder(testCase)
runConfig = makeRunConfigWithoutDescriptionEndpoints();
data = samplingData(runConfig);
context = struct('runConfig',runConfig,'data',data);
cstSampling = minimalCst();
cstSampling = cstSampling([2 1 3],:);

planWorkflow.sampling.SamplingService.validateStructures( ...
    context,cstSampling);
end

function testSamplingStructureValidationRejectsDuplicateNames(testCase)
runConfig = makeRunConfig();
data = samplingData(runConfig);
context = struct('runConfig',runConfig,'data',data);
cstSampling = minimalCst();
cstSampling{3,2} = 'CTV';

verifyError(testCase,@() ...
    planWorkflow.sampling.SamplingService.validateStructures( ...
    context,cstSampling), ...
    'planWorkflow:sampling:SamplingService:SamplingStructureMismatch');
end

function testSamplingStructureValidationRejectsMissingRoles(testCase)
runConfig = makeRunConfig();
data = samplingData(runConfig);
context = struct('runConfig',runConfig,'data',data);
cstSampling = minimalCst();
cstSampling{2,3} = '';

verifyError(testCase,@() ...
    planWorkflow.sampling.SamplingService.validateStructures( ...
    context,cstSampling), ...
    'planWorkflow:sampling:SamplingService:SamplingStructureMismatch');
end

function testSamplingPrepareStructuresDoesNotMutateRoles(testCase)
runConfig = makeRunConfigWithoutDescriptionEndpoints();
data = samplingData(runConfig);
data.objectiveInfo.targetName = 'PTV';
data.objectiveInfo.ixTarget = 3;
data.cst{3,3} = 'TARGET';
for planIx = 1:numel(data.robustPlans)
    data.robustPlans{planIx}.objectiveInfo.targetName = 'PTV';
    data.robustPlans{planIx}.objectiveInfo.ixTarget = 3;
    data.robustPlans{planIx}.cst{3,3} = 'TARGET';
end
context = struct('runConfig',runConfig,'data',data);
cstSampling = minimalCst();
cstSampling{3,3} = 'TARGET';

cstSampling = planWorkflow.sampling.SamplingService.prepareStructures( ...
    context,cstSampling);

verifyEqual(testCase,cstSampling{3,3},'TARGET');
end

function testSamplingValidationDoesNotRequireOptimizationTarget(testCase)
runConfig = makeRunConfigWithoutDescriptionEndpoints();
data = samplingData(runConfig);
data.objectiveInfo.targetName = 'PTV';
data.objectiveInfo.ixTarget = 2;
context = struct('runConfig',runConfig,'data',data);
cstSampling = minimalCst();
cstSampling(3,:) = [];

planWorkflow.sampling.SamplingService.prepareStructures( ...
    context,cstSampling);
end

function testSamplingValidationUsesExplicitEndpointContract(testCase)
runConfig = makeRunConfig();
runConfig.analysis.endpoints = struct( ...
    'structureNames',{{'RECTUM'}}, ...
    'metric','Dmean', ...
    'kind','mean', ...
    'goal','lowerIsBetter', ...
    'doseQuantity','physicalDose', ...
    'outputDoseMode','totalDose', ...
    'unit','Gy');
data = samplingData(runConfig);
context = struct('runConfig',runConfig,'data',data);

verifyError(testCase,@() ...
    planWorkflow.sampling.SamplingService.validateStructures( ...
    context,minimalCst()), ...
    'planWorkflow:sampling:SamplingService:SamplingStructureMismatch');
end

function testSamplingValidationUsesDescriptionEndpointContract(testCase)
runConfig = makeRunConfig();
runConfig.description = 'prostate';
data = samplingData(runConfig);
context = struct('runConfig',runConfig,'data',data);

verifyError(testCase,@() ...
    planWorkflow.sampling.SamplingService.validateStructures( ...
    context,minimalCst()), ...
    'planWorkflow:sampling:SamplingService:SamplingStructureMismatch');
end

function testSamplingValidationUsesRobustnessTargetContract(testCase)
runConfig = makeRunConfig();
runConfig.analysis.robustnessTargetMode = 'include';
runConfig.analysis.robustnessTargets = {'RECTUM'};
data = samplingData(runConfig);
context = struct('runConfig',runConfig,'data',data);

verifyError(testCase,@() ...
    planWorkflow.sampling.SamplingService.validateStructures( ...
    context,minimalCst()), ...
    'planWorkflow:sampling:SamplingService:SamplingStructureMismatch');
end

function testSamplingPlanSetDerivesVariantPlanFromConfig(testCase)
runConfig = makeRunConfig();
data = samplingData(runConfig);
data.robustPlans{2}.planConfig.variants(1).theta1 = 5;
data.robustPlans{2}.pln.propOpt.theta1 = 1;
data.robustPlans{2}.variantResults = ...
    planWorkflow.results.VariantResults.create( ...
    data.robustPlans{2},1,struct('w',1));

planSet = planWorkflow.sampling.SamplingPlanSet.fromData( ...
    runConfig,data);

verifyEqual(testCase,planSet.entries(3).pln.propOpt.theta1,5);
verifyFalse(testCase,isfield(data.robustPlans{2}.variantResults,'pln'));
end

function testVariantResultsAreRequiredWhenResultGUIExists(testCase)
runConfig = makeRunConfig();
data = samplingData(runConfig);
data.robustPlans{1} = rmfield(data.robustPlans{1},'variantResults');
data.robustPlans{1}.resultGUI = {struct('w',1)};

verifyError(testCase,@() ...
    planWorkflow.sampling.SamplingPlanSet.fromData(runConfig,data), ...
    'planWorkflow:results:VariantResults:MissingVariantResults');
end

function testIncompleteVariantResultsAreRejected(testCase)
runConfig = makeRunConfig();
data = samplingData(runConfig);
data.robustPlans{1}.variantResults = ...
    planWorkflow.results.VariantResults.empty(1);

verifyError(testCase,@() ...
    planWorkflow.sampling.SamplingPlanSet.fromData(runConfig,data), ...
    'planWorkflow:results:VariantResults:IncompleteVariantResult');
end

function testMissingVariantWeightsAreRejected(testCase)
runConfig = makeRunConfig();
data = samplingData(runConfig);
data.robustPlans{1}.variantResults = ...
    planWorkflow.results.VariantResults.create( ...
    data.robustPlans{1},1,struct());

verifyError(testCase,@() ...
    planWorkflow.sampling.SamplingPlanSet.fromData(runConfig,data), ...
    'planWorkflow:results:VariantResults:MissingVariantWeights');
end

function runConfig = makeRunConfig()
runConfig = struct();
runConfig.radiationMode = 'photons';
runConfig.workflowType = 'test';
runConfig.description = 'prostate';
runConfig.caseID = 'case';
runConfig.plan_template = 'comparison_001';
runConfig.plan_beams = '9F';
runConfig.runId = 'multi-plan-test';
fixtureRoot = tempdir();
runConfig.outputRootPath = fullfile(fixtureRoot,'planWorkflowTests');
runConfig.cacheRootPath = fullfile(fixtureRoot,'planWorkflowTests','cache');
runConfig.precompute = planWorkflow.config.RobustPlanConfig.defaults();
runConfig.precompute.robustPlans = [ ...
    robustPlan('robust_1','PTV plan','none',[5 10 5]); ...
    robustPlan('robust_2','INTERVAL2 plan','INTERVAL2',[1 2 3])];
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
runConfig.sampling_size = 37;
runConfig.sampling_randomSeed = [];
end

function runConfig = makeRunConfigWithoutDescriptionEndpoints()
runConfig = makeRunConfig();
runConfig.description = 'test';
end

function plan = robustPlan(id,label,robustnessMode,shiftSD)
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = id;
plan.label = label;
switch char(id)
    case 'robust_1'
        plan.objectiveSetName = 'PTV';
    case 'robust_2'
        plan.objectiveSetName = 'Interval2';
    otherwise
        plan.objectiveSetName = id;
end
plan.robustnessMode = robustnessMode;
plan.scenario = planWorkflow.config.RobustPlanConfig.defaultScenario( ...
    'wcScen');
plan.scenario.shiftSD = shiftSD;
plan.variants = planWorkflow.config.RobustPlanConfig.defaultVariants( ...
    robustnessMode);
end

function data = samplingData(runConfig)
data = struct();
data.cst = minimalCst();
data.stf = struct('totalNumOfBixels',1);
data.pln = struct();
data.pln.propStf.isoCenter = [0 0 1];
data.resultGUIReference = struct('w',1);
data.objectiveInfo = objectiveInfo();
plans = planWorkflow.config.RobustPlanConfig.plansFromRunConfig( ...
    runConfig);
data.robustPlans = cell(1,numel(plans));
for planIx = 1:numel(plans)
    robustData = struct();
    robustData.planConfig = plans(planIx);
    robustData.cst = minimalCst();
    robustData.stf = data.stf;
    robustData.pln = data.pln;
    robustData.objectiveInfo = objectiveInfo();
    robustData.variantResults = ...
        planWorkflow.results.VariantResults.create( ...
        robustData,1,struct('w',planIx));
    data.robustPlans{planIx} = robustData;
end
end

function info = objectiveInfo()
info = struct();
info.targetName = 'CTV';
info.ixTarget = 2;
info.ixBody = 1;
info.ixCTV = 2;
info.ixRing1 = [];
info.ixRing2 = [];
info.ringIndices = [];
end

function cst = minimalCst()
cst = cell(3,6);
names = {'BODY','CTV','PTV'};
roles = {'OAR','TARGET','OAR'};
for i = 1:3
    cst{i,1} = i - 1;
    cst{i,2} = names{i};
    cst{i,3} = roles{i};
    cst{i,4} = {i};
    cst{i,5} = struct('Priority',i);
    cst{i,6} = [];
end
end
