function tests = testPenaltyVariantsRuntime
tests = functiontests(localfunctions);
end

function testOptimizeStageUsesCstForInternalPenaltyVariant(testCase)
stubCleanup = installFluenceOptimizationStub(testCase); %#ok<NASGU>
planConfig = penaltyPlanConfig();
runConfig = runtimeRunConfig(planConfig);
data = workflowData(planConfig);
context = planWorkflow.stages.OptimizeStage.context( ...
    runConfig,data,@runTask,@(~) []);

patch = planWorkflow.stages.OptimizeStage.run(context);

results = patch.data.robustPlans{1}.variantResults;
verifyNumElements(testCase,results,2);
verifyEqual(testCase,results(1).resultGUI.w,[5 11]);
verifyEqual(testCase,results(2).resultGUI.w,[5 22]);
end

function testDosePullingUsesCstForInternalPenaltyVariant(testCase)
planConfig = penaltyPlanConfig();
robustData = robustDataWithPenaltyVariants(planConfig);
robustData.cst = pullingCst(0);
robustData.cstByVariant = {pullingCst(1),pullingCst(5)};
context = planWorkflow.precompute.DosePulling.context( ...
    dosePullingRunConfig(),@runPullingOptimization,@runAnalysis, ...
    @runMetrics,@runPolicy,@(~) []);

[robustData,report] = planWorkflow.precompute.DosePulling.runRobust( ...
    context,robustData);

verifyEqual(testCase,robustData.cstByVariant{1}{1,6}{1}.parameters,{2});
verifyEqual(testCase,robustData.cstByVariant{2}{1,6}{1}.parameters,{6});
verifyEqual(testCase,robustData.initialWeights{1},2);
verifyEqual(testCase,robustData.initialWeights{2},6);
verifyEqual(testCase,numel(report.plans{1}.history),2);
verifyEqual(testCase,numel(report.plans{2}.history),2);
end

function testSamplingPlanSetUsesCstForInternalPenaltyVariant(testCase)
planConfig = penaltyPlanConfig();
runConfig = runtimeRunConfig(planConfig);
data = workflowData(planConfig);
robustData = data.robustPlans{1};
robustData.variantResults = [ ...
    planWorkflow.results.VariantResults.create( ...
    robustData,1,struct('w',1)) ...
    planWorkflow.results.VariantResults.create( ...
    robustData,2,struct('w',2))];
data.robustPlans{1} = robustData;

planSet = planWorkflow.sampling.SamplingPlanSet.fromData( ...
    runConfig,data);

verifyEqual(testCase,{planSet.entries.role}, ...
    {'reference','robust','robust'});
verifyEqual(testCase,planSet.entries(2).variantId,'theta_5_v1_p1');
verifyEqual(testCase,planSet.entries(3).variantId,'theta_5_v1_p2');
verifyFalse(testCase,isfield(planSet.entries,'cst'));
verifyEqual(testCase, ...
    data.robustPlans{1}.cstByVariant{1}{1,6}{1}.penalty,11);
verifyEqual(testCase, ...
    data.robustPlans{1}.cstByVariant{2}{1,6}{1}.penalty,22);
end

function testRobustDataFactoryPreservesOarPenaltyVariants(testCase)
stubCleanup = installRobustPrecomputeStubs(testCase); %#ok<NASGU>
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
template.objectiveSets.robustPlans(1) = setObjectiveParameter( ...
    template.objectiveSets.robustPlans(1),'structureObjectives', ...
    'BLADDER',1,'penalty',[3 7]);
runConfig = robustBuildRunConfig();
runConfig = ...
    planWorkflow.config.WorkflowContractValidator.alignRobustPlansWithTemplate( ...
    runConfig,template);
planConfig = runConfig.precompute.robustPlans(1);
sourceData = robustBuildSourceData();

robustData = planWorkflow.precompute.RobustDataFactory.build( ...
    runConfig,template,planConfig,sourceData);

bladderIx = findStructureIndex(robustData.cstByVariant{1},'BLADDER');
verifyEqual(testCase, ...
    robustData.cstByVariant{1}{bladderIx,6}{1}.penalty,3);
verifyEqual(testCase, ...
    robustData.cstByVariant{2}{bladderIx,6}{1}.penalty,7);
verifyEqual(testCase, ...
    robustData.cstByVariant{1}{bladderIx,6}{1}.robustness, ...
    'INTERVAL2');
verifyEqual(testCase, ...
    robustData.cstByVariant{2}{bladderIx,6}{1}.robustness, ...
    'INTERVAL2');
verifyEqual(testCase, ...
    robustData.cstByVariant{1}{bladderIx,6}{2}.penalty,199);
verifyEqual(testCase, ...
    robustData.cstByVariant{2}{bladderIx,6}{2}.penalty,199);
end

function value = runTask(varargin)
task = varargin{end};
value = task();
end

function resultGUI = runPullingOptimization(~,cst,~,~)
resultGUI = struct('w',cst{1,6}{1}.parameters{1});
end

function [resultGUI,dvh,qi] = runAnalysis( ...
        ~,~,~,~,resultGUI,~) %#ok<INUSL>
dvh = [];
qi = [];
end

function metrics = runMetrics( ...
        cst,~,resultGUI,~,iteration,~) %#ok<INUSL>
value = cst{1,6}{1}.parameters{1};
metrics = struct('step',2,'iteration',iteration, ...
    'targetNames',{{'CTV'}},'criteria',{{'meanQiTarget'}}, ...
    'meanQiTarget',value,'minQiTarget',value, ...
    'selectedCriterion','meanQiTarget','selectedValues',resultGUI.w, ...
    'limits',2,'isSatisfied',value >= 2);
end

function tf = runPolicy(metrics)
tf = ~metrics.isSatisfied;
end

function runConfig = runtimeRunConfig(planConfig)
runConfig = struct();
runConfig.optimizer = 'STUB';
runConfig.analysis = planWorkflow.config.Analysis.defaults();
runConfig.precompute = planWorkflow.config.RobustPlanConfig.defaults();
runConfig.precompute.robustPlans = planConfig;
end

function runConfig = dosePullingRunConfig()
runConfig = struct();
runConfig.dose_pulling_strategy = 'Threshold';
runConfig.dose_pulling_max_iter = 1;
runConfig.dose_pulling2_start = 0;
runConfig.dose_pulling2_limit = 2;
runConfig.dose_pulling2_criteria = 'meanQiTarget';
end

function runConfig = robustBuildRunConfig()
runConfig = struct();
runConfig.plan_template = 'interval2_001';
runConfig.radiationMode = 'photons';
runConfig.description = 'prostate';
runConfig.plan_beams = '9F';
runConfig.dose_pulling1_start = 0;
runConfig.dose_pulling2_start = 0;
runConfig.precompute = planWorkflow.config.RobustPlanConfig.defaults();

plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = 'Interval2';
plan.label = 'Interval2';
plan.objectiveSetName = 'Interval2';
plan.robustnessMode = 'INTERVAL2';
plan.scenario = planWorkflow.config.ScenarioSpec.defaults('nomScen');
plan.scenario.ctActive = false;
plan.scenario.setupActive = false;
plan.scenario.rangeActive = false;
plan.scenario.gantryActive = false;
plan.scenario.couchActive = false;
plan.variants = planWorkflow.config.RobustPlanConfig.defaultVariants( ...
    'INTERVAL2');
runConfig.precompute.robustPlans = plan;
end

function data = workflowData(planConfig)
data = struct();
data.ct = struct();
data.cst = cstWithPenalty(99);
data.stf = struct('totalNumOfBixels',1);
data.pln = struct('propOpt',struct());
data.resultGUIReference = struct('w',0);
data.objectiveInfo = objectiveInfo();
data.optimizationInput = planWorkflow.precompute.OptimizationInput.build( ...
    data.ct,data.cst,data.pln,data.stf,referenceDij(), ...
    'nominal','reference');
data.robustPlans = {robustDataWithPenaltyVariants(planConfig)};
end

function robustData = robustDataWithPenaltyVariants(planConfig)
robustData = struct();
robustData.planConfig = planConfig;
robustData.cst = cstWithPenalty(11);
robustData.cstByVariant = {cstWithPenalty(11),cstWithPenalty(22)};
robustData.objectiveInfo = objectiveInfo();
robustData.objectiveInfoByVariant = {objectiveInfo(),objectiveInfo()};
robustData.ctScenProb = 1;
robustData.ct = struct();
robustData.pln = struct('propOpt',struct());
robustData.stf = struct('totalNumOfBixels',1);
robustData.optimizationInput = ...
    planWorkflow.precompute.OptimizationInput.build( ...
    robustData.ct,robustData.cst,robustData.pln, ...
    robustData.stf,referenceDij(),'nominal','robust');
robustData.strategy = struct('name','INTERVAL2');
end

function dij = referenceDij()
dij = struct('totalNumOfBixels',1);
end

function sourceData = robustBuildSourceData()
ct = makeCt([7 7 7]);
cst = makeProstateCst(ct.cubeDim);
bladderIx = findStructureIndex(cst,'BLADDER');
cst{bladderIx,6} = {sourceOarObjective(99),sourceOarObjective(199)};
sourceData = struct();
sourceData.ct = ct;
sourceData.cst = cst;
sourceData.pln = struct( ...
    'propStf',struct('numOfBeams',0), ...
    'propOpt',struct());
end

function plan = penaltyPlanConfig()
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = 'robust_1';
plan.label = 'Robust 1';
plan.objectiveSetName = 'robust_1';
plan.robustnessMode = 'INTERVAL2';
plan.variants = struct('id','theta_5','label','theta1=5','theta1',5);
plan = planWorkflow.config.RobustPlanConfig.normalizePlan(plan,1);
plan.variantsWithPenalties = [ ...
    penaltyVariant(plan.variants,1,11) ...
    penaltyVariant(plan.variants,2,22)];
end

function variant = penaltyVariant(baseVariant,combinationIx,penalty)
variant = baseVariant;
variant.id = sprintf('%s_v1_p%d',char(baseVariant.id),combinationIx);
variant.label = sprintf('%s / penalty=%g', ...
    char(baseVariant.label),penalty);
variant.baseVariantId = char(baseVariant.id);
variant.baseVariantLabel = char(baseVariant.label);
variant.baseVariantIndex = 1;
variant.penaltyCombinationIndex = combinationIx;
variant.penaltyCombinationCount = 2;
variant.penaltyAssignments = struct( ...
    'groupField','structureObjectives', ...
    'groupIx',1, ...
    'objectiveIx',1, ...
    'structureName','CTV', ...
    'value',penalty);
variant.penaltyLabel = sprintf('penalty=%g',penalty);
end

function cst = cstWithPenalty(penalty)
objective = struct('className','matRad_MaxDose', ...
    'parameters',{{penalty}},'penalty',penalty, ...
    'dosePulling',false);
cst = cell(1,6);
cst{1,1} = 0;
cst{1,2} = 'CTV';
cst{1,3} = 'TARGET';
cst{1,4} = {1};
cst{1,5} = struct('Priority',1);
cst{1,6} = {objective};
end

function objective = sourceOarObjective(penalty)
objective = struct( ...
    'className','DoseObjectives.matRad_MaxDVH', ...
    'parameters',{{60,0}}, ...
    'penalty',penalty, ...
    'robustness','none', ...
    'dosePulling',false);
end

function cst = pullingCst(parameter)
objective = struct( ...
    'parameters',{{parameter}}, ...
    'penalty',1, ...
    'dosePulling',true, ...
    'pullingStep',2, ...
    'objectivePullingRate',{{1}}, ...
    'penaltyPullingRate',0);
cst = cstWithPenalty(1);
cst{1,6} = {objective};
end

function info = objectiveInfo()
info = struct();
info.targetName = 'CTV';
info.ixTarget = 1;
info.ixBody = 1;
info.ixCTV = 1;
info.prescriptionDose = [];
info.ringIndices = [];
info.ixRing1 = [];
info.ixRing2 = [];
end

function objectiveSet = setObjectiveParameter( ...
        objectiveSet,groupField,groupName,objectiveIx,parameterName,value)
groups = objectiveSet.(groupField);
groupIx = find(strcmp({groups.name},char(groupName)),1);
if isempty(groupIx)
    error('testPenaltyVariantsRuntime:MissingObjectiveGroup', ...
        'Missing objective group "%s".',char(groupName));
end
objectives = groups(groupIx).objectives;
objective = objectiveAt(objectives,objectiveIx);
objective.parameters.(parameterName) = value;
objectives = setObjectiveAt(objectives,objectiveIx,objective);
groups(groupIx).objectives = objectives;
objectiveSet.(groupField) = groups;
end

function objective = objectiveAt(objectives,index)
if iscell(objectives)
    objective = objectives{index};
else
    objective = objectives(index);
end
end

function objectives = setObjectiveAt(objectives,index,objective)
if iscell(objectives)
    objectives{index} = objective;
else
    objectives(index) = objective;
end
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

function cst = setStructure(cst,ix,name,type,voxels,priority)
cst{ix,1} = ix - 1;
cst{ix,2} = name;
cst{ix,3} = type;
cst{ix,4}{1} = voxels(:);
cst{ix,5} = struct('Priority',priority,'Visible',true, ...
    'visibleColor',[0 1 0]);
cst{ix,6} = [];
end

function structureIx = findStructureIndex(cst,structureName)
structureIx = find(strcmp(cst(:,2),char(structureName)),1);
if isempty(structureIx)
    error('testPenaltyVariantsRuntime:MissingStructure', ...
        'Missing structure "%s".',char(structureName));
end
end

function cleanup = installFluenceOptimizationStub(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
stubFile = fullfile(fixture.Folder,'matRad_fluenceOptimization.m');
stubText = sprintf([ ...
    'function resultGUI = matRad_fluenceOptimization(~,cst,pln,varargin)\n' ...
    'theta = 0;\n' ...
    'if isfield(pln,''propOpt'') && isfield(pln.propOpt,''theta1'')\n' ...
    '    theta = pln.propOpt.theta1;\n' ...
    'end\n' ...
    'resultGUI = struct(''w'',[theta cst{1,6}{1}.penalty]);\n' ...
    'end\n']);
writeTextFile(stubFile,stubText);
addpath(fixture.Folder,'-begin');
clear matRad_fluenceOptimization;
cleanup = onCleanup(@() cleanupFluenceOptimizationStub(fixture.Folder));
end

function cleanup = installRobustPrecomputeStubs(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
scenarioClassFile = fullfile(fixture.Folder, ...
    'PlanWorkflowTestScenarioModel.m');
scenarioFactoryFile = fullfile(fixture.Folder, ...
    'matRad_createScenarioModel.m');
stfFile = fullfile(fixture.Folder,'matRad_generateStf.m');
scenarioClassText = sprintf([ ...
    'classdef PlanWorkflowTestScenarioModel < handle\n' ...
    '    properties\n' ...
    '        scenarioDimensionActive = {}\n' ...
    '        shiftSD = [0 0 0]\n' ...
    '        rangeAbsSD = 0\n' ...
    '        rangeRelSD = 0\n' ...
    '        ctScenProb = [1 1]\n' ...
    '        wcSigma = 1\n' ...
    '        numOfRangeGridPoints = 1\n' ...
    '        combinations = ''none''\n' ...
    '        combineRange = true\n' ...
    '        nSamples = 0\n' ...
    '        includeNominalScenario = true\n' ...
    '        randomSeed = []\n' ...
    '        numOfBeams = 0\n' ...
    '        gantryAngleSD = 0\n' ...
    '        couchAngleSD = 0\n' ...
    '    end\n' ...
    '    methods\n' ...
    '        function updateScenarios(~)\n' ...
    '        end\n' ...
    '    end\n' ...
    'end\n']);
scenarioFactoryText = sprintf([ ...
    'function multScen = matRad_createScenarioModel(~,~)\n' ...
    'multScen = PlanWorkflowTestScenarioModel();\n' ...
    'end\n']);
stfText = sprintf([ ...
    'function stf = matRad_generateStf(~,cst,pln)\n' ...
    'stf = struct(''numStructures'',size(cst,1),''pln'',pln);\n' ...
    'end\n']);
writeTextFile(scenarioClassFile,scenarioClassText);
writeTextFile(scenarioFactoryFile,scenarioFactoryText);
writeTextFile(stfFile,stfText);
addpath(fixture.Folder,'-begin');
clear matRad_createScenarioModel matRad_generateStf ...
    PlanWorkflowTestScenarioModel;
cleanup = onCleanup(@() cleanupRobustPrecomputeStubs(fixture.Folder));
end

function writeTextFile(fileName,text)
fid = fopen(fileName,'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s',char(text));
end

function cleanupFluenceOptimizationStub(folder)
try
    rmpath(folder);
catch
end
clear matRad_fluenceOptimization;
end

function cleanupRobustPrecomputeStubs(folder)
try
    rmpath(folder);
catch
end
clear matRad_createScenarioModel matRad_generateStf ...
    PlanWorkflowTestScenarioModel;
end
