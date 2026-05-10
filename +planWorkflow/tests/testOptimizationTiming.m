function tests = testOptimizationTiming
tests = functiontests(localfunctions);
end

function testReferenceAndRobustRtpi(testCase)
reference = optimizationTiming('reference','Reference',10,5);
robust = optimizationTiming('robust','Robust',30,5);

timings = planWorkflow.performance.OptimizationTiming.enrich( ...
    [reference robust]);

verifyEqual(testCase,timings(1).iterations,5);
verifyEqual(testCase,timings(1).timePerIterationSeconds,2, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings(1).rTPI,1,'AbsTol',1e-12);
verifyEqual(testCase,timings(1).rTPIReferenceLabel,'Reference');
verifyEqual(testCase,timings(1).rTPIReferenceTimePerIterationSeconds,2, ...
    'AbsTol',1e-12);

verifyEqual(testCase,timings(2).iterations,5);
verifyEqual(testCase,timings(2).timePerIterationSeconds,6, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings(2).rTPI,3,'AbsTol',1e-12);
verifyEqual(testCase,timings(2).rTPIReferenceLabel,'Reference');
verifyEqual(testCase,timings(2).rTPIReferenceTimePerIterationSeconds,2, ...
    'AbsTol',1e-12);

detail = jsondecode(timings(2).detail);
verifyEqual(testCase,detail.iterations,5);
verifyEqual(testCase,detail.timePerIterationSeconds,6, ...
    'AbsTol',1e-12);
verifyEqual(testCase,detail.rTPI,3,'AbsTol',1e-12);
verifyEqual(testCase,detail.rTPIReference.label,'Reference');
verifyEqual(testCase,detail.rTPIReference.timePerIterationSeconds,2, ...
    'AbsTol',1e-12);
end

function testInvalidTasksDoNotReceiveTimingMetrics(testCase)
failed = optimizationTiming('robust','Failed',30,5);
failed.status = 'failed';
notOptimization = optimizationTiming('robust','Analysis',30,5);
notOptimization.task = 'planAnalysis';
missingIterations = optimizationTiming('robust','Missing',30,[]);
zeroIterations = optimizationTiming('robust','Zero',30,0);

timings = planWorkflow.performance.OptimizationTiming.enrich( ...
    [failed notOptimization missingIterations zeroIterations]);

for timingIx = 1:numel(timings)
    verifyTrue(testCase,isnan(timings(timingIx).timePerIterationSeconds));
    verifyTrue(testCase,isnan(timings(timingIx).rTPI));
end
end

function testMostRecentReferenceIsUsed(testCase)
reference1 = optimizationTiming('reference','Reference 1',10,5);
robust1 = optimizationTiming('robust','Robust 1',20,5);
reference2 = optimizationTiming('reference','Reference 2',4,4);
robust2 = optimizationTiming('robust','Robust 2',12,4);

timings = planWorkflow.performance.OptimizationTiming.enrich( ...
    [reference1 robust1 reference2 robust2]);

verifyEqual(testCase,timings(1).timePerIterationSeconds,2, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings(2).timePerIterationSeconds,4, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings(2).rTPI,2,'AbsTol',1e-12);
verifyEqual(testCase,timings(2).rTPIReferenceLabel,'Reference 1');

verifyEqual(testCase,timings(3).timePerIterationSeconds,1, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings(4).timePerIterationSeconds,3, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings(4).rTPI,3,'AbsTol',1e-12);
verifyEqual(testCase,timings(4).rTPIReferenceLabel,'Reference 2');
end

function timing = optimizationTiming(role,label,wallTimeSeconds,iterations)
timing = baseTiming();
timing.stage = 'optimize';
timing.role = role;
timing.label = label;
timing.task = 'fluenceOptimization';
timing.status = 'completed';
timing.wallTimeSeconds = wallTimeSeconds;
if isempty(iterations)
    timing.detail = '{}';
else
    timing.detail = jsonencode(struct('iterations',iterations));
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
