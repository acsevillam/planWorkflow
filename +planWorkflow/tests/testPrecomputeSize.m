function tests = testPrecomputeSize
tests = functiontests(localfunctions);
end

function testReferenceAndRobustRelativeDijPrecomputeSize(testCase)
referenceSize = planWorkflow.performance.PrecomputeSize.single( ...
    100,'reference','Reference','dij',[]);
robustSize = planWorkflow.performance.PrecomputeSize.single( ...
    300,'robust','Robust','dij_robust',referenceSize);

timings = planWorkflow.performance.PrecomputeSize.enrich( ...
    [planTiming('reference','Reference','doseInfluence', ...
    referenceSize) ...
    planTiming('robust','Robust','robustDoseInfluence', ...
    robustSize)]);

verifyEqual(testCase,timings(1).dijPrecomputingSizeBytes,100, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings(1).relativeDijPrecomputingSize,1, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings(1).dijPrecomputingSizeReferenceLabel, ...
    'Reference');
verifyEqual(testCase,timings(1).dijPrecomputingSizeReferenceBytes,100, ...
    'AbsTol',1e-12);

verifyEqual(testCase,timings(2).dijPrecomputingSizeBytes,300, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings(2).relativeDijPrecomputingSize,3, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings(2).dijPrecomputingSizeReferenceLabel, ...
    'Reference');

detail = jsondecode(timings(2).detail);
verifyEqual(testCase,detail.dijPrecomputingSize.totalSizeBytes,300, ...
    'AbsTol',1e-12);
verifyEqual(testCase,detail.dijPrecomputingSize.relativeSize,3, ...
    'AbsTol',1e-12);
end

function testCompositeSizeKeepsInputAndDerivedComponents(testCase)
referenceSize = planWorkflow.performance.PrecomputeSize.single( ...
    100,'reference','Reference','dij',[]);
inputSize = planWorkflow.performance.PrecomputeSize.single( ...
    300,'input','INTERVAL2','dij_robust',referenceSize);
intervalSize = planWorkflow.performance.PrecomputeSize.combine( ...
    inputSize,'derived','dij_interval',50,'INTERVAL2');

[normalized,tf] = planWorkflow.performance.PrecomputeSize.normalize( ...
    intervalSize);

verifyTrue(testCase,tf);
verifyEqual(testCase,normalized.totalSizeBytes,350,'AbsTol',1e-12);
verifyEqual(testCase,normalized.relativeSize,3.5,'AbsTol',1e-12);
verifyNumElements(testCase,normalized.components,2);
verifyEqual(testCase,normalized.components(1).artifact,'dij_robust');
verifyEqual(testCase,normalized.components(1).role,'input');
verifyEqual(testCase,normalized.components(2).artifact,'dij_interval');
verifyEqual(testCase,normalized.components(2).role,'derived');
verifyEqual(testCase,normalized.components(2).sizeBytes,50, ...
    'AbsTol',1e-12);
end

function testStreamingArtifactUsesTotalPrecomputingBytes(testCase)
referenceSize = planWorkflow.performance.PrecomputeSize.single( ...
    100,'reference','Reference','dij',[]);
inputSize = planWorkflow.performance.PrecomputeSize.single( ...
    200,'input','PROB2','dij_robust',referenceSize);
streamingDij = struct();
streamingDij.streamingSize = struct( ...
    'compactBytes',40, ...
    'auxiliaryPeakBytes',60, ...
    'totalPrecomputingBytes',100);

prob2Size = planWorkflow.performance.PrecomputeSize.combine( ...
    inputSize,'derived','dij_prob2',streamingDij,'PROB2');

verifyEqual(testCase,prob2Size.totalSizeBytes,300,'AbsTol',1e-12);
verifyEqual(testCase,prob2Size.relativeSize,3,'AbsTol',1e-12);
verifyEqual(testCase,prob2Size.components(2).sizeBytes,100, ...
    'AbsTol',1e-12);
end

function testCompositeSizeCanBeRebasedAsReference(testCase)
inputSize = planWorkflow.performance.PrecomputeSize.single( ...
    200,'input','Reference','dij_robust',[]);
compactSize = planWorkflow.performance.PrecomputeSize.combine( ...
    inputSize,'derived','dij_prob2',100,'Reference');

referenceSize = planWorkflow.performance.PrecomputeSize.asReference( ...
    compactSize,'Reference');

verifyEqual(testCase,referenceSize.totalSizeBytes,300,'AbsTol',1e-12);
verifyEqual(testCase,referenceSize.relativeSize,1,'AbsTol',1e-12);
verifyEqual(testCase,referenceSize.reference.label,'Reference');
verifyEqual(testCase,referenceSize.reference.sizeBytes,300, ...
    'AbsTol',1e-12);
verifyEqual(testCase,referenceSize.components(1).relativeSize, ...
    200 / 300,'AbsTol',1e-12);
verifyEqual(testCase,referenceSize.components(2).relativeSize, ...
    100 / 300,'AbsTol',1e-12);
end

function testCacheOptionsDriveFromOptionsReferenceSize(testCase)
referenceSize = planWorkflow.performance.PrecomputeSize.single( ...
    100,'reference','Reference','dij',[]);
options = planWorkflow.performance.PrecomputeSize.cacheOptions( ...
    'robust','Robust','dij_robust',[],referenceSize);
artifact = struct('streamingSize',struct( ...
    'totalPrecomputingBytes',300));

sizeData = planWorkflow.performance.PrecomputeSize.fromOptions( ...
    artifact,options);

verifyEqual(testCase,sizeData.totalSizeBytes,300,'AbsTol',1e-12);
verifyEqual(testCase,sizeData.relativeSize,3,'AbsTol',1e-12);
verifyEqual(testCase,sizeData.reference.label,'Reference');
verifyTrue(testCase,isfield(options,'referenceTiming'));
verifyEqual(testCase,sizeData.components.artifact,'dij_robust');
verifyEqual(testCase,sizeData.components.role,'robust');
end

function testCacheMetadataSizeCanBeCopiedToPlanTiming(testCase)
referenceSize = planWorkflow.performance.PrecomputeSize.single( ...
    100,'reference','Reference','dij',[]);
prob2Size = planWorkflow.performance.PrecomputeSize.combine( ...
    planWorkflow.performance.PrecomputeSize.single( ...
    200,'input','PROB2','dij_robust',referenceSize), ...
    'derived','dij_prob2',100,'PROB2');
cacheMetadata = struct('dijPrecomputingSize',prob2Size);

fromCache = planWorkflow.performance.PrecomputeSize.fromCacheMetadata( ...
    cacheMetadata);
timing = planTiming('robust','PROB2', ...
    'prob2DoseInfluenceCacheRead',fromCache);
timings = planWorkflow.performance.PrecomputeSize.enrich(timing);

verifyEqual(testCase,timings.dijPrecomputingSizeBytes,300, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings.relativeDijPrecomputingSize,3, ...
    'AbsTol',1e-12);
verifyEqual(testCase,timings.dijPrecomputingSizeReferenceLabel,'Reference');
end

function testInvalidTasksDoNotReceiveDijPrecomputeSize(testCase)
missing = planTiming('robust','Missing','prepareRobustData',[]);
failed = planTiming('robust','Failed','robustDoseInfluence', ...
    planWorkflow.performance.PrecomputeSize.single( ...
    300,'robust','Failed','dij_robust', ...
    planWorkflow.performance.PrecomputeSize.single( ...
    100,'reference','Reference','dij',[])));
failed.status = 'failed';

timings = planWorkflow.performance.PrecomputeSize.enrich([missing failed]);

for timingIx = 1:numel(timings)
    verifyTrue(testCase,isnan( ...
        timings(timingIx).dijPrecomputingSizeBytes));
    verifyTrue(testCase,isnan( ...
        timings(timingIx).relativeDijPrecomputingSize));
end
end

function timing = planTiming(role,label,task,dijPrecomputingSize)
timing = baseTiming();
timing.stage = 'precompute';
timing.role = role;
timing.label = label;
timing.task = task;
timing.status = 'completed';
if ~isempty(dijPrecomputingSize)
    timing.detail = jsonencode(struct( ...
        'dijPrecomputingSize',dijPrecomputingSize));
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
timing.dijPrecomputingSizeBytes = NaN;
timing.relativeDijPrecomputingSize = NaN;
timing.dijPrecomputingSizeReferenceLabel = '';
timing.dijPrecomputingSizeReferenceBytes = NaN;
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
