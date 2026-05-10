function tests = testPrecomputeTiming
tests = functiontests(localfunctions);
end

function testReferenceAndRobustRelativeDijPrecomputeTime(testCase)
referenceTiming = planWorkflow.performance.PrecomputeTiming.single( ...
    10,'reference','Reference','dij',[]);
robustTiming = planWorkflow.performance.PrecomputeTiming.single( ...
    30,'robust','Robust','dij_robust',referenceTiming);

timings = planWorkflow.performance.PrecomputeTiming.enrich( ...
    [planTiming('reference','Reference','doseInfluence', ...
    referenceTiming) ...
    planTiming('robust','Robust','robustDoseInfluence', ...
    robustTiming)]);

verifyEqual(testCase,timings(1).dijPrecomputingTimeSeconds,10, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings(1).relativeDijPrecomputingTime,1, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings(1).dijPrecomputingReferenceLabel, ...
    'Reference');
verifyEqual(testCase,timings(1).dijPrecomputingReferenceTimeSeconds,10, ...
    'AbsTol',1e-12);

verifyEqual(testCase,timings(2).dijPrecomputingTimeSeconds,30, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings(2).relativeDijPrecomputingTime,3, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings(2).dijPrecomputingReferenceLabel, ...
    'Reference');

detail = jsondecode(timings(2).detail);
verifyEqual(testCase,detail.dijPrecomputingTiming.totalTimeSeconds,30, ...
    'AbsTol',1e-12);
verifyEqual(testCase,detail.dijPrecomputingTiming.relativeTime,3, ...
    'AbsTol',1e-12);
end

function testCompositeTimingKeepsInputAndDerivedComponents(testCase)
referenceTiming = planWorkflow.performance.PrecomputeTiming.single( ...
    10,'reference','Reference','dij',[]);
inputTiming = planWorkflow.performance.PrecomputeTiming.single( ...
    30,'input','INTERVAL2','dij_robust',referenceTiming);
intervalTiming = planWorkflow.performance.PrecomputeTiming.combine( ...
    inputTiming,'derived','dij_interval',5,'INTERVAL2');

[normalized,tf] = planWorkflow.performance.PrecomputeTiming.normalize( ...
    intervalTiming);

verifyTrue(testCase,tf);
verifyEqual(testCase,normalized.totalTimeSeconds,35,'AbsTol',1e-12);
verifyEqual(testCase,normalized.relativeTime,3.5,'AbsTol',1e-12);
verifyNumElements(testCase,normalized.components,2);
verifyEqual(testCase,normalized.components(1).artifact,'dij_robust');
verifyEqual(testCase,normalized.components(1).role,'input');
verifyEqual(testCase,normalized.components(2).artifact,'dij_interval');
verifyEqual(testCase,normalized.components(2).role,'derived');
verifyEqual(testCase,normalized.components(2).timeSeconds,5, ...
    'AbsTol',1e-12);
end

function testCacheMetadataTimingCanBeCopiedToPlanTiming(testCase)
referenceTiming = planWorkflow.performance.PrecomputeTiming.single( ...
    10,'reference','Reference','dij',[]);
prob2Timing = planWorkflow.performance.PrecomputeTiming.combine( ...
    planWorkflow.performance.PrecomputeTiming.single( ...
    20,'input','PROB2','dij_robust',referenceTiming), ...
    'derived','dij_prob2',10,'PROB2');
cacheMetadata = struct('dijPrecomputingTiming',prob2Timing);

fromCache = planWorkflow.performance.PrecomputeTiming.fromCacheMetadata( ...
    cacheMetadata);
timing = planTiming('robust','PROB2', ...
    'prob2DoseInfluenceCacheRead',fromCache);
timings = planWorkflow.performance.PrecomputeTiming.enrich(timing);

verifyEqual(testCase,timings.dijPrecomputingTimeSeconds,30, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings.relativeDijPrecomputingTime,3, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings.dijPrecomputingReferenceLabel,'Reference');
end

function testInvalidTasksDoNotReceiveDijPrecomputeTiming(testCase)
missing = planTiming('robust','Missing','prepareRobustData',[]);
failed = planTiming('robust','Failed','robustDoseInfluence', ...
    planWorkflow.performance.PrecomputeTiming.single( ...
    30,'robust','Failed','dij_robust', ...
    planWorkflow.performance.PrecomputeTiming.single( ...
    10,'reference','Reference','dij',[])));
failed.status = 'failed';

timings = planWorkflow.performance.PrecomputeTiming.enrich([missing failed]);

for timingIx = 1:numel(timings)
    verifyTrue(testCase,isnan( ...
        timings(timingIx).dijPrecomputingTimeSeconds));
    verifyTrue(testCase,isnan( ...
        timings(timingIx).relativeDijPrecomputingTime));
end
end

function timing = planTiming(role,label,task,dijPrecomputingTiming)
timing = baseTiming();
timing.stage = 'precompute';
timing.role = role;
timing.label = label;
timing.task = task;
timing.status = 'completed';
if ~isempty(dijPrecomputingTiming)
    timing.detail = jsonencode(struct( ...
        'dijPrecomputingTiming',dijPrecomputingTiming));
end
end

function timing = baseTiming()
timing = struct();
timing.stage = '';
timing.role = '';
timing.label = '';
timing.task = '';
timing.robustPlanId = '';
timing.variantId = '';
timing.status = '';
timing.startTime = '';
timing.endTime = '';
timing.wallTimeSeconds = NaN;
timing.cpuTimeSeconds = NaN;
timing.iterations = NaN;
timing.timePerIterationSeconds = NaN;
timing.rTPI = NaN;
timing.rTPIReferenceLabel = '';
timing.rTPIReferenceTimePerIterationSeconds = NaN;
timing.dijPrecomputingTimeSeconds = NaN;
timing.relativeDijPrecomputingTime = NaN;
timing.dijPrecomputingReferenceLabel = '';
timing.dijPrecomputingReferenceTimeSeconds = NaN;
timing.detail = '';
timing.startProcessMemoryBytes = NaN;
timing.endProcessMemoryBytes = NaN;
timing.processMemoryDeltaBytes = NaN;
timing.maxObservedProcessMemoryBytes = NaN;
timing.startDataMemoryBytes = NaN;
timing.endDataMemoryBytes = NaN;
timing.dataMemoryDeltaBytes = NaN;
timing.memorySource = '';
timing.errorMessage = '';
end
