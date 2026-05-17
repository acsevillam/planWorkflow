function tests = testScenarioBatchPrecomputeReal
tests = functiontests(localfunctions);
end

function testInterval2ScenarioBatchPrecomputeUsesRealMatRadFunction(testCase)
assumeRealScenarioBatchFunction(testCase,'matRad_calcDoseInterval');
[ct,cst,pln,stf,objectiveInfo] = photonScenarioBatchFixture(testCase);
context = realScenarioBatchContext();
robustData = realScenarioBatchRobustData( ...
    'INTERVAL2',ct,cst,pln,stf,objectiveInfo);

robustData = ...
    planWorkflow.precompute.IntervalDoseInfluence.precompute( ...
    context,robustData);

verifyFalse(testCase,isfield(robustData,'dij'));
verifyPrecomputeSize(testCase,robustData.dij_interval, ...
    robustData.dijPrecomputingSize,context.data.dijPrecomputingSize);
verifyEqual(testCase, ...
    robustData.dij_interval.precomputeMode,'scenario-batch');
verifyEqual(testCase, ...
    robustData.dij_interval.secondPassStrategy,'recompute');
verifyEqual(testCase,robustData.dij_interval.intervalMode,'INTERVAL2');
verifyEqual(testCase,size(robustData.dij_interval.center,2), ...
    robustData.dijIntervalContext.totalNumOfBixels);
verifyGreaterThan(testCase,nnz(robustData.dij_interval.center),0);
verifyFalse(testCase,isfield(robustData.dij_interval,'cacheDir'));
end

function testProb2ScenarioBatchPrecomputeUsesRealMatRadFunction(testCase)
assumeRealScenarioBatchFunction(testCase, ...
    'matRad_calculateProbabilisticQuantities');
[ct,cst,pln,stf,objectiveInfo] = photonScenarioBatchFixture(testCase);
context = realScenarioBatchContext();
robustData = realScenarioBatchRobustData( ...
    'PROB2',ct,cst,pln,stf,objectiveInfo);

robustData = ...
    planWorkflow.precompute.ProbDoseInfluence.precompute( ...
    context,robustData);

verifyFalse(testCase,isfield(robustData,'dij'));
verifyPrecomputeSize(testCase,robustData.dij_prob, ...
    robustData.dijPrecomputingSize,context.data.dijPrecomputingSize);
verifyEqual(testCase,robustData.dij_prob.precomputeMode,'scenario-batch');
verifyEqual(testCase,robustData.dij_prob.secondPassStrategy,'recompute');
verifyEqual(testCase,robustData.dij_prob.probabilisticMode,'PROB');
verifyEqual(testCase,size(robustData.dij_prob.expected,2), ...
    robustData.dijProbContext.totalNumOfBixels);
verifyGreaterThan(testCase,nnz(robustData.dij_prob.expected),0);
verifyFalse(testCase,isfield(robustData.dij_prob,'cacheDir'));
end

function assumeRealScenarioBatchFunction(testCase,functionName)
functionPath = which(functionName);
assumeNotEmpty(testCase,functionPath, ...
    sprintf('%s must be available on the matRad path.',functionName));
assumeFalse(testCase,contains(functionPath,'scenarioBatchStubs'), ...
    sprintf('%s must resolve to the real matRad implementation.', ...
    functionName));
end

function [ct,cst,pln,stf,objectiveInfo] = photonScenarioBatchFixture(testCase)
matRadRoot = matRadRootFromPath(testCase);
testDataPath = fullfile(matRadRoot,'test','testData', ...
    'photons_testData.mat');
assumeTrue(testCase,isfile(testDataPath), ...
    ['photons_testData.mat must be available for real scenario-batch ' ...
     'smoke tests.']);
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
    ['matRad must be initialized before running real scenario-batch ' ...
     'smoke tests.']);
matRadRoot = fileparts(matRadRc);
end

function objectiveInfo = robustObjectiveInfo(testCase,cst)
targetRows = structureRowsByRole(cst,'TARGET');
oarRows = structureRowsByRole(cst,'OAR');
assumeFalse(testCase,isempty(targetRows), ...
    ['Real scenario-batch smoke test requires at least one target ' ...
     'structure.']);
assumeFalse(testCase,isempty(oarRows), ...
    'Real scenario-batch smoke test requires at least one OAR structure.');
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

function context = realScenarioBatchContext()
context = struct();
context.runConfig = struct('writeCache',false,'useCache',false);
context.data = struct('quantityOpt','physicalDose', ...
    'dijPrecomputingSize', ...
    planWorkflow.performance.PrecomputeSize.single( ...
    1024,'reference','Reference','dij',[]));
context.log = @(message) [];
end

function verifyPrecomputeSize(testCase,compactDij,sizeData,referenceSize)
verifyTrue(testCase,isfield(compactDij,'precomputeSize'));
precomputeSize = compactDij.precomputeSize;
verifyGreaterThan(testCase,precomputeSize.compactBytes,0);
verifyGreaterThanOrEqual(testCase,precomputeSize.auxiliaryPeakBytes,0);
verifyEqual(testCase,precomputeSize.totalPrecomputingBytes, ...
    precomputeSize.compactBytes + precomputeSize.auxiliaryPeakBytes, ...
    'AbsTol',1e-12);
verifyTrue(testCase, ...
    planWorkflow.performance.PrecomputeSize.isValid(sizeData));
verifyEqual(testCase,sizeData.totalSizeBytes, ...
    precomputeSize.totalPrecomputingBytes,'AbsTol',1e-12);
verifyEqual(testCase,sizeData.relativeSize, ...
    precomputeSize.totalPrecomputingBytes / referenceSize.totalSizeBytes, ...
    'AbsTol',1e-12);
end

function robustData = realScenarioBatchRobustData( ...
        mode,ct,cst,pln,stf,objectiveInfo)
planConfig = planWorkflow.config.RobustPlanConfig.defaultPlan();
planConfig.id = ['realScenarioBatch' mode];
planConfig.label = ['Real scenario-batch ' mode];
planConfig.objectiveSetName = planConfig.id;
planConfig.robustnessMode = mode;
planConfig.hasNominalObjectives = false;
planConfig.requiresNominalDij = false;
planConfig.requiresScenarioDij = false;
planConfig.requiresIntervalDij = any(strcmp(mode,{'INTERVAL2','INTERVAL3'}));
planConfig.requiresProbDij = strcmp(mode,'PROB2');
planConfig.robustnessOptions = ...
    planWorkflow.config.RobustPlanConfig.defaultRobustnessOptions(mode);
planConfig.variants = ...
    planWorkflow.config.RobustPlanConfig.defaultVariants(mode);
planConfig.dosePrecompute.useScenarioBatch = true;
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
