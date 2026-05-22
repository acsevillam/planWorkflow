function tests = testResourceTelemetry
tests = functiontests(localfunctions);
end

function testResourceSamplerSummarizesHighWaterProcessTree(testCase)
samples = repmat(emptySample(),1,3);
samples(1).available = true;
samples(1).mainProcessMemoryBytes = 100;
samples(1).childProcessMemoryBytes = 10;
samples(1).totalProcessMemoryBytes = 110;
samples(2).available = true;
samples(2).mainProcessMemoryBytes = 150;
samples(2).childProcessMemoryBytes = 80;
samples(2).totalProcessMemoryBytes = 230;
samples(2).childProcessBuckets.windowRendererMemoryBytes = 60;
samples(2).childProcessBuckets.windowRendererCount = 3;
samples(3).available = true;
samples(3).mainProcessMemoryBytes = 120;
samples(3).childProcessMemoryBytes = 20;
samples(3).totalProcessMemoryBytes = 140;
samples(3).childProcessBuckets.parallelWorkerMemoryBytes = 20;
samples(3).childProcessBuckets.parallelWorkerCount = 1;

summary = planWorkflow.resources.ResourceSampler.summaryFromSamples( ...
    samples,false);

verifyEqual(testCase,summary.source,'process_tree_rss_ps');
verifyEqual(testCase,summary.highWaterMainProcessMemoryBytes,150);
verifyEqual(testCase,summary.highWaterChildProcessMemoryBytes,80);
verifyEqual(testCase,summary.highWaterTotalProcessMemoryBytes,230);
verifyEqual(testCase,summary.sampleCount,3);
verifyEqual(testCase, ...
    summary.childProcessBuckets.windowRenderer.highWaterMemoryBytes,60);
verifyEqual(testCase, ...
    summary.childProcessBuckets.windowRenderer.highWaterCount,3);
verifyEqual(testCase, ...
    summary.childProcessBuckets.parallelWorker.highWaterMemoryBytes,20);
end

function testSamplingResourceOptionsForwardWorkerUpperBound(testCase)
runConfig = struct();
runConfig.resources = planWorkflow.config.Resources.defaults();
runConfig.resources.sampling.workerUpperBound = 3;
runConfig.resources.sampling.calibrateWorkerMemory = false;
runConfig.resources.sampling.minForwardDoseWorkerMemoryBytes = 8 * 1024^3;

options = planWorkflow.config.Resources.samplingNameValuePairs(runConfig);

workerUpperBoundIx = find(strcmp(options,'workerUpperBound'),1);
verifyNotEmpty(testCase,workerUpperBoundIx);
verifyEqual(testCase,options{workerUpperBoundIx + 1},3);

calibrateIx = find(strcmp(options,'calibrateWorkerMemory'),1);
verifyNotEmpty(testCase,calibrateIx);
verifyFalse(testCase,options{calibrateIx + 1});

minForwardDoseIx = find(strcmp(options, ...
    'minForwardDoseWorkerMemoryBytes'),1);
verifyNotEmpty(testCase,minForwardDoseIx);
verifyEqual(testCase,options{minForwardDoseIx + 1},8 * 1024^3);
end

function testSamplingDefaultsUseConservativeWorkerMemoryFloor(testCase)
resources = planWorkflow.config.Resources.defaults();

verifyEqual(testCase,resources.sampling.minWorkerMemoryBytes,4 * 1024^3);
verifyTrue(testCase,resources.sampling.calibrateWorkerMemory);
verifyEqual(testCase,resources.sampling.minForwardDoseWorkerMemoryBytes, ...
    16 * 1024^3);
end

function testWorkerUpperBoundAcceptsEmptyOrPositiveIntegers(testCase)
validValues = {[],1,3};
for valueIx = 1:numel(validValues)
    value = validValues{valueIx};
    config = planWorkflow.config.Resources.defaults();
    config.sampling.workerUpperBound = value;
    config.doseCalculation.workerUpperBound = value;

    resources = planWorkflow.config.Resources.normalize(config);

    verifyEqual(testCase,resources.sampling.workerUpperBound,value);
    verifyEqual(testCase,resources.doseCalculation.workerUpperBound,value);
end
end

function testWorkerUpperBoundRejectsInvalidValues(testCase)
invalidValues = {1.5,0,Inf,NaN,'3',[1 2]};
for valueIx = 1:numel(invalidValues)
    value = invalidValues{valueIx};

    samplingConfig = planWorkflow.config.Resources.defaults();
    samplingConfig.sampling.workerUpperBound = value;
    verifyError(testCase,@() ...
        planWorkflow.config.Resources.normalize(samplingConfig), ...
        'planWorkflow:config:Resources:InvalidWorkerUpperBound');

    doseConfig = planWorkflow.config.Resources.defaults();
    doseConfig.doseCalculation.workerUpperBound = value;
    verifyError(testCase,@() ...
        planWorkflow.config.Resources.normalize(doseConfig), ...
        'planWorkflow:config:Resources:InvalidWorkerUpperBound');
end
end

function testReleasePoolAfterStageDefaultsConservative(testCase)
resources = planWorkflow.config.Resources.normalize( ...
    planWorkflow.config.Resources.defaults());

verifyFalse(testCase,resources.doseCalculation.releasePoolAfterStage);

config = planWorkflow.config.Resources.defaults();
config.doseCalculation.releasePoolAfterStage = true;
resources = planWorkflow.config.Resources.normalize(config);

verifyTrue(testCase,resources.doseCalculation.releasePoolAfterStage);
end

function testResourceDetailsSerializesCacheTelemetry(testCase)
cacheRef = struct();
cacheRef.cacheTelemetry = struct( ...
    'schemaVersion',1, ...
    'source','planWorkflow.cache.DoseInfluenceCache', ...
    'cacheTag','reference', ...
    'cacheHit',true, ...
    'cacheFile','/tmp/cache.mat', ...
    'computeSeconds',0, ...
    'metadataValidationSeconds',0.01, ...
    'loadSeconds',0.2, ...
    'saveSeconds',0, ...
    'fileBytes',100, ...
    'logicalBytes',80, ...
    'artifactKind','reference');

detail = planWorkflow.performance.ResourceDetails.planTask( ...
    'precompute','doseInfluence',{struct(),[],[],cacheRef});
detailData = jsondecode(detail);

verifyTrue(testCase,isfield(detailData,'cacheTelemetry'));
verifyEqual(testCase,detailData.cacheTelemetry.cacheHit,true);
verifyEqual(testCase,detailData.cacheTelemetry.fileBytes,100);
verifyEqual(testCase,detailData.cacheTelemetry.logicalBytes,80);
end

function testResourceDetailsSerializesDosePullingTrace(testCase)
trace = struct( ...
    'step',9, ...
    'metrics',struct('primaryScore',0,'limitDiffSq',1.2e-6), ...
    'isFeasible',true, ...
    'candidate',struct('rectumPull',9.5,'bladderPull',7.125), ...
    'isSelected',true, ...
    'stopReason','converged');
report = struct( ...
    'converged',true, ...
    'iterations',9, ...
    'stopReason','converged', ...
    'trace',trace);

detail = planWorkflow.performance.ResourceDetails.planTask( ...
    'pullDose','dosePulling',{struct(),report});
detailData = jsondecode(detail);

verifyTrue(testCase,isfield(detailData,'dosePulling'));
verifyEqual(testCase,detailData.dosePulling.converged,true);
verifyEqual(testCase,detailData.dosePulling.iterations,9);
verifyEqual(testCase,detailData.dosePulling.stopReason,'converged');
verifyEqual(testCase,detailData.dosePulling.trace.step,9);
verifyEqual(testCase,detailData.dosePulling.trace.isFeasible,true);
verifyEqual(testCase,detailData.dosePulling.trace.isSelected,true);
verifyEqual(testCase,detailData.dosePulling.trace.candidate.rectumPull,9.5);
end

function sample = emptySample()
sample = struct();
sample.timestamp = '';
sample.source = 'process_tree_rss_ps';
sample.available = false;
sample.unavailableCause = '';
sample.mainPid = NaN;
sample.childPids = [];
sample.mainProcessMemoryBytes = NaN;
sample.childProcessMemoryBytes = NaN;
sample.totalProcessMemoryBytes = NaN;
sample.childProcessBuckets = emptyChildBuckets();
end

function buckets = emptyChildBuckets()
buckets = struct( ...
    'parallelWorkerMemoryBytes',0, ...
    'parallelWorkerCount',0, ...
    'windowRendererMemoryBytes',0, ...
    'windowRendererCount',0, ...
    'matlabHelperMemoryBytes',0, ...
    'matlabHelperCount',0, ...
    'otherMemoryBytes',0, ...
    'otherCount',0);
end
