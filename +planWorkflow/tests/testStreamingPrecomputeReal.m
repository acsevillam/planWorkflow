function tests = testStreamingPrecomputeReal
tests = functiontests(localfunctions);
end

function testInterval2StreamingPrecomputeUsesRealMatRadFunction(testCase)
assumeRealStreamingFunction(testCase,'matRad_calcDoseInterval2Streaming');
[ct,cst,pln,stf,objectiveInfo] = photonStreamingFixture(testCase);
context = realStreamingContext();
robustData = realStreamingRobustData( ...
    'INTERVAL2',ct,cst,pln,stf,objectiveInfo);

robustData = ...
    planWorkflow.precompute.IntervalDoseInfluence.precompute( ...
    context,robustData);

verifyFalse(testCase,isfield(robustData,'dij'));
verifyEqual(testCase, ...
    robustData.dij_interval.precomputeMode,'streaming');
verifyEqual(testCase, ...
    robustData.dij_interval.secondPassStrategy,'recompute');
verifyEqual(testCase,robustData.dij_interval.intervalMode,'INTERVAL2');
verifyEqual(testCase,size(robustData.dij_interval.center,2), ...
    robustData.dij_intervalContext.totalNumOfBixels);
verifyGreaterThan(testCase,nnz(robustData.dij_interval.center),0);
verifyFalse(testCase,isfield(robustData.dij_interval,'cacheDir'));
end

function testProb2StreamingPrecomputeUsesRealMatRadFunction(testCase)
assumeRealStreamingFunction(testCase,'matRad_calcDoseProb2Streaming');
[ct,cst,pln,stf,objectiveInfo] = photonStreamingFixture(testCase);
context = realStreamingContext();
robustData = realStreamingRobustData( ...
    'PROB2',ct,cst,pln,stf,objectiveInfo);

robustData = ...
    planWorkflow.precompute.Prob2DoseInfluence.precompute( ...
    context,robustData);

verifyFalse(testCase,isfield(robustData,'dij'));
verifyEqual(testCase,robustData.dij_prob2.precomputeMode,'streaming');
verifyEqual(testCase,robustData.dij_prob2.secondPassStrategy,'recompute');
verifyEqual(testCase,robustData.dij_prob2.probabilisticMode,'PROB2');
verifyEqual(testCase,size(robustData.dij_prob2.expected,2), ...
    robustData.dij_prob2Context.totalNumOfBixels);
verifyGreaterThan(testCase,nnz(robustData.dij_prob2.expected),0);
verifyFalse(testCase,isfield(robustData.dij_prob2,'cacheDir'));
end

function assumeRealStreamingFunction(testCase,functionName)
functionPath = which(functionName);
assumeNotEmpty(testCase,functionPath, ...
    sprintf('%s must be available on the matRad path.',functionName));
assumeFalse(testCase,contains(functionPath,'streamingStubs'), ...
    sprintf('%s must resolve to the real matRad implementation.', ...
    functionName));
end

function [ct,cst,pln,stf,objectiveInfo] = photonStreamingFixture(testCase)
matRadRoot = matRadRootFromPath(testCase);
testDataPath = fullfile(matRadRoot,'test','testData', ...
    'photons_testData.mat');
assumeTrue(testCase,isfile(testDataPath), ...
    'photons_testData.mat must be available for real streaming smoke tests.');
data = load(testDataPath,'ct','cst','pln','stf');
ct = data.ct;
cst = data.cst;
pln = data.pln;
stf = data.stf;
if ~isfield(ct,'refScen') || isempty(ct.refScen)
    ct.refScen = 1;
end
pln.propDoseCalc.engine = 'SVDPB';
if ~isfield(pln,'multScen') || isempty(pln.multScen)
    pln.multScen = matRad_NominalScenario();
end
objectiveInfo = robustObjectiveInfo(testCase,cst);
end

function matRadRoot = matRadRootFromPath(testCase)
matRadRc = which('matRad_rc');
assumeNotEmpty(testCase,matRadRc, ...
    'matRad must be initialized before running real streaming smoke tests.');
matRadRoot = fileparts(matRadRc);
end

function objectiveInfo = robustObjectiveInfo(testCase,cst)
targetRows = structureRowsByRole(cst,'TARGET');
oarRows = structureRowsByRole(cst,'OAR');
assumeFalse(testCase,isempty(targetRows), ...
    'Real streaming smoke test requires at least one target structure.');
assumeFalse(testCase,isempty(oarRows), ...
    'Real streaming smoke test requires at least one OAR structure.');
objectiveInfo = struct();
objectiveInfo.ixTarget = targetRows(1);
objectiveInfo.targetName = cst{targetRows(1),2};
objectiveInfo.robustOarNames = cst(oarRows(1),2);
end

function rows = structureRowsByRole(cst,role)
rows = [];
for rowIx = 1:size(cst,1)
    if size(cst,2) < 3 || isempty(cst{rowIx,3})
        continue;
    end
    if strcmpi(char(cst{rowIx,3}),role)
        rows(end + 1) = rowIx; %#ok<AGROW>
    end
end
end

function context = realStreamingContext()
context = struct();
context.runConfig = struct('writeCache',false,'useCache',false);
context.data = struct('quantityOpt','physicalDose');
context.log = @(message) [];
end

function robustData = realStreamingRobustData( ...
        mode,ct,cst,pln,stf,objectiveInfo)
planConfig = planWorkflow.config.RobustPlanConfig.defaultPlan();
planConfig.id = ['realStreaming' mode];
planConfig.label = ['Real streaming ' mode];
planConfig.objectiveSetName = planConfig.id;
planConfig.robustnessMode = mode;
planConfig.hasNominalObjectives = false;
planConfig.requiresNominalDij = false;
planConfig.requiresScenarioDij = false;
planConfig.requiresIntervalDij = any(strcmp(mode,{'INTERVAL2','INTERVAL3'}));
planConfig.requiresProb2Dij = strcmp(mode,'PROB2');
planConfig.robustnessOptions = ...
    planWorkflow.config.RobustPlanConfig.defaultRobustnessOptions(mode);
planConfig.variants = ...
    planWorkflow.config.RobustPlanConfig.defaultVariants(mode);
planConfig.dosePrecompute.useStreaming = true;
planConfig.dosePrecompute.SecondPassStrategy = 'recompute';
planConfig.dosePrecompute.KeepCache = false;

robustData = struct();
robustData.ct = ct;
robustData.cst = cst;
robustData.pln = pln;
robustData.stf = stf;
robustData.objectiveInfo = objectiveInfo;
robustData.planConfig = planConfig;
robustData.strategy = planWorkflow.robustness.AbstractStrategy.create(mode);
end
