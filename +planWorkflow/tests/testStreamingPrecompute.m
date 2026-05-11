function tests = testStreamingPrecompute
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
stubFolder = fullfile(fileparts(mfilename('fullpath')), ...
    'fixtures','streamingStubs');
addpath(stubFolder,'-begin');
clearStreamingFunctions();
testCase.TestData.stubFolder = stubFolder;
end

function teardownOnce(testCase)
rmpath(testCase.TestData.stubFolder);
clearStreamingFunctions();
end

function testInterval2StreamingPrecomputeCallsStreamingWithoutDij(testCase)
context = compactContext();
robustData = intervalRobustData('INTERVAL2');

robustData = ...
    planWorkflow.precompute.IntervalDoseInfluence.precompute( ...
    context,robustData);

verifyFalse(testCase,isfield(robustData,'dij'));
verifyEqual(testCase,robustData.dij_interval.stubMode,'INTERVAL2');
verifyEqual(testCase,robustData.dij_interval.stubNargin,5);
verifyEqual(testCase,robustData.dij_intervalContext.stubNargin,5);
verifyTrue(testCase, ...
    planWorkflow.performance.PrecomputeTiming.isValid( ...
    robustData.dijPrecomputingTiming));
verifyTrue(testCase, ...
    planWorkflow.performance.PrecomputeSize.isValid( ...
    robustData.dijPrecomputingSize));
verifyEqual(testCase, ...
    robustData.dijPrecomputingSize.totalSizeBytes, ...
    robustData.dij_interval.streamingSize.totalPrecomputingBytes, ...
    'AbsTol',1e-12);
verifyEqual(testCase, ...
    robustData.dijPrecomputingSize.relativeSize, ...
    robustData.dij_interval.streamingSize.totalPrecomputingBytes / ...
    context.data.dijPrecomputingSize.totalSizeBytes, ...
    'AbsTol',1e-12);
end

function testIntervalStreamingNominalObjectivesUseContextDij(testCase)
context = compactContext();
robustData = intervalRobustData('INTERVAL2');
robustData.planConfig.hasNominalObjectives = true;
robustData.planConfig.requiresNominalDij = true;

robustData = ...
    planWorkflow.precompute.IntervalDoseInfluence.precompute( ...
    context,robustData);

verifyFalse(testCase,isfield(robustData,'dij'));
verifyEqual(testCase,robustData.dijNominal, ...
    robustData.dij_intervalContext);
verifyEqual(testCase,robustData.stfNominal,robustData.stf);
verifyFalse(testCase,isfield(robustData.plnNominal.propOpt, ...
    'dij_interval'));
end

function testInterval3StreamingPrecomputeCallsStreamingWithoutDij(testCase)
context = compactContext();
robustData = intervalRobustData('INTERVAL3');

robustData = ...
    planWorkflow.precompute.IntervalDoseInfluence.precompute( ...
    context,robustData);

verifyFalse(testCase,isfield(robustData,'dij'));
verifyEqual(testCase,robustData.dij_interval.stubMode,'INTERVAL3');
verifyEqual(testCase,robustData.dij_interval.stubNargin,5);
verifyEqual(testCase,robustData.dij_intervalContext.stubNargin,5);
end

function testReferenceIntervalStreamingPrecomputeIsSelfReferenced(testCase)
context = compactContext();
robustData = referenceRobustData(intervalRobustData('INTERVAL2'));

robustData = ...
    planWorkflow.precompute.IntervalDoseInfluence.precompute( ...
    context,robustData);

verifyEqual(testCase,robustData.dijPrecomputingTiming.relativeTime,1, ...
    'AbsTol',1e-12);
verifyEqual(testCase, ...
    robustData.dijPrecomputingTiming.reference.timeSeconds, ...
    robustData.dijPrecomputingTiming.totalTimeSeconds,'AbsTol',1e-12);
verifyEqual(testCase,robustData.dijPrecomputingSize.relativeSize,1, ...
    'AbsTol',1e-12);
verifyEqual(testCase, ...
    robustData.dijPrecomputingSize.reference.sizeBytes, ...
    robustData.dijPrecomputingSize.totalSizeBytes,'AbsTol',1e-12);
end

function testProb2StreamingPrecomputeCallsStreamingWithoutDij(testCase)
context = compactContext();
robustData = prob2RobustData();

robustData = ...
    planWorkflow.precompute.Prob2DoseInfluence.precompute( ...
    context,robustData);

verifyFalse(testCase,isfield(robustData,'dij'));
verifyEqual(testCase,robustData.dij_prob2.stubMode,'PROB2');
verifyEqual(testCase,robustData.dij_prob2.stubNargin,5);
verifyEqual(testCase,robustData.dij_prob2Context.stubNargin,5);
verifyTrue(testCase, ...
    planWorkflow.performance.PrecomputeTiming.isValid( ...
    robustData.dijPrecomputingTiming));
verifyTrue(testCase, ...
    planWorkflow.performance.PrecomputeSize.isValid( ...
    robustData.dijPrecomputingSize));
verifyEqual(testCase, ...
    robustData.dijPrecomputingSize.totalSizeBytes, ...
    robustData.dij_prob2.streamingSize.totalPrecomputingBytes, ...
    'AbsTol',1e-12);
verifyEqual(testCase, ...
    robustData.dijPrecomputingSize.relativeSize, ...
    robustData.dij_prob2.streamingSize.totalPrecomputingBytes / ...
    context.data.dijPrecomputingSize.totalSizeBytes, ...
    'AbsTol',1e-12);
end

function testReferenceProb2StreamingPrecomputeIsSelfReferenced(testCase)
context = compactContext();
robustData = referenceRobustData(prob2RobustData());

robustData = ...
    planWorkflow.precompute.Prob2DoseInfluence.precompute( ...
    context,robustData);

verifyEqual(testCase,robustData.dijPrecomputingTiming.relativeTime,1, ...
    'AbsTol',1e-12);
verifyEqual(testCase, ...
    robustData.dijPrecomputingTiming.reference.timeSeconds, ...
    robustData.dijPrecomputingTiming.totalTimeSeconds,'AbsTol',1e-12);
verifyEqual(testCase,robustData.dijPrecomputingSize.relativeSize,1, ...
    'AbsTol',1e-12);
verifyEqual(testCase, ...
    robustData.dijPrecomputingSize.reference.sizeBytes, ...
    robustData.dijPrecomputingSize.totalSizeBytes,'AbsTol',1e-12);
end

function testProb2StreamingNominalObjectivesUseContextDij(testCase)
context = compactContext();
robustData = prob2RobustData();
robustData.planConfig.hasNominalObjectives = true;
robustData.planConfig.requiresNominalDij = true;

robustData = ...
    planWorkflow.precompute.Prob2DoseInfluence.precompute( ...
    context,robustData);

verifyFalse(testCase,isfield(robustData,'dij'));
verifyEqual(testCase,robustData.dijNominal,robustData.dij_prob2Context);
verifyEqual(testCase,robustData.stfNominal,robustData.stf);
verifyFalse(testCase,isfield(robustData.plnNominal.propOpt, ...
    'dij_prob2'));
end

function context = compactContext()
context = struct();
context.runConfig = struct('writeCache',false,'useCache',false);
context.data = struct('quantityOpt','', ...
    'dijPrecomputingSize', ...
    planWorkflow.performance.PrecomputeSize.single( ...
    1024,'reference','Reference','dij',[]));
context.log = @(message) [];
end

function robustData = intervalRobustData(mode)
robustData = baseRobustData(mode);
robustData.planConfig.requiresIntervalDij = true;
robustData.planConfig.robustnessOptions = ...
    planWorkflow.config.RobustPlanConfig.defaultRobustnessOptions(mode);
robustData.planConfig.variants = ...
    planWorkflow.config.RobustPlanConfig.defaultVariants(mode);
robustData.strategy = planWorkflow.robustness.AbstractStrategy.create(mode);
end

function robustData = prob2RobustData()
robustData = baseRobustData('PROB2');
robustData.planConfig.requiresProb2Dij = true;
robustData.planConfig.robustnessOptions = ...
    planWorkflow.config.RobustPlanConfig.defaultRobustnessOptions('PROB2');
robustData.planConfig.variants = ...
    planWorkflow.config.RobustPlanConfig.defaultVariants('PROB2');
robustData.strategy = planWorkflow.robustness.AbstractStrategy.create('PROB2');
end

function robustData = baseRobustData(mode)
planConfig = planWorkflow.config.RobustPlanConfig.defaultPlan();
planConfig.id = ['streaming' mode];
planConfig.label = ['Streaming ' mode];
planConfig.objectiveSetName = planConfig.id;
planConfig.robustnessMode = mode;
planConfig.hasNominalObjectives = false;
planConfig.requiresNominalDij = false;
planConfig.requiresScenarioDij = false;
planConfig.requiresIntervalDij = false;
planConfig.requiresProb2Dij = false;
planConfig.dosePrecompute.useStreaming = true;

robustData = struct();
robustData.planConfig = planConfig;
robustData.ct = struct('refScen',1);
robustData.cst = cell(2,6);
robustData.cst{1,2} = 'PTV';
robustData.cst{2,2} = 'Rectum';
robustData.objectiveInfo = struct( ...
    'ixTarget',1, ...
    'robustOarNames',{{'Rectum'}});
robustData.pln = struct('propOpt',struct());
robustData.stf = struct('totalNumOfBixels',3);
end

function robustData = referenceRobustData(robustData)
robustData.planConfig.id = 'reference';
robustData.planConfig.label = 'Reference';
robustData.planConfig.objectiveSetName = 'reference';
end

function clearStreamingFunctions()
functionNames = { ...
    'matRad_calcDoseInterval2Streaming', ...
    'matRad_calcDoseInterval3Streaming', ...
    'matRad_calcDoseProb2Streaming'};
for functionIx = 1:numel(functionNames)
    clear(functionNames{functionIx});
end
end
