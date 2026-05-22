function tests = testWorkflowBasePersistence
tests = functiontests(localfunctions);
end

function testSyntheticWorkflowPersistsSplitArtifacts(testCase)
workflow = planWorkflowTest.SyntheticWorkflow(baseSyntheticConfig(testCase));

workflow.prepare();
workflow.precompute();
workflow.pullDose();
workflow.optimize();
workflow.sample();
workflow.analyze();
workflow.save();

verifyTrue(testCase,isfile(workflow.stateFile));
verifyTrue(testCase,isfile(workflow.dataFile));
verifyTrue(testCase,isfile(workflow.resultsFile));
verifyTrue(testCase,isfile(workflow.performanceFile));

stateSnapshot = load(workflow.stateFile);
verifyTrue(testCase,isfield(stateSnapshot,'runConfig'));
verifyTrue(testCase,isfield(stateSnapshot,'artifactFiles'));
verifyFalse(testCase,isfield(stateSnapshot,'data'));
verifyFalse(testCase,isfield(stateSnapshot,'results'));

dataSnapshot = load(workflow.dataFile,'data');
verifyTrue(testCase,isfield(dataSnapshot.data,'preparedValue'));
verifyFalse(testCase,isfield(dataSnapshot.data,'results'));

resultsSnapshot = load(workflow.resultsFile,'results');
verifyEqual(testCase,resultsSnapshot.results.score,47);
verifyTrue(testCase,isfield(resultsSnapshot.results,'performance'));
verifyTrue(testCase,isfield(resultsSnapshot.results.performance,'stageTimings'));
verifyTrue(testCase,isfield(resultsSnapshot.results.performance,'planTimings'));

performanceSnapshot = load(workflow.performanceFile,'performance');
resources = performanceSnapshot.performance;
verifyEqual(testCase,resources.wallTimeUnit,'seconds');
verifyEqual(testCase,resources.memoryUnit,'bytes');
verifyEqual(testCase, ...
    resources.stageTimings.prepare.lastStatus,'completed');
verifyGreaterThanOrEqual(testCase, ...
    resources.stageTimings.prepare.attempts,1);
verifyEqual(testCase,resources.planTimings(1).role,'reference');
verifyEqual(testCase,resources.planTimings(1).task, ...
    'syntheticOptimization');
verifyTrue(testCase,isfield(resources.planTimings,'iterations'));
verifyTrue(testCase,isfield(resources.planTimings,'timePerIterationSeconds'));
verifyTrue(testCase,isfield(resources.planTimings,'rTPI'));
verifyTrue(testCase,isfield(resources.planTimings,'rTPIReferenceLabel'));
verifyTrue(testCase,isfield(resources.planTimings, ...
    'rTPIReferenceTimePerIterationSeconds'));
verifyTrue(testCase,isfield(resources.planTimings, ...
    'dijPrecomputingTimeSeconds'));
verifyTrue(testCase,isfield(resources.planTimings, ...
    'relativeDijPrecomputingTime'));
verifyTrue(testCase,isfield(resources.planTimings, ...
    'dijPrecomputingReferenceLabel'));
verifyTrue(testCase,isfield(resources.planTimings, ...
    'dijPrecomputingReferenceTimeSeconds'));
verifyTrue(testCase,isfield(resources.planTimings, ...
    'dijPrecomputingSizeBytes'));
verifyTrue(testCase,isfield(resources.planTimings, ...
    'relativeDijPrecomputingSize'));
verifyTrue(testCase,isfield(resources.planTimings, ...
    'dijPrecomputingSizeReferenceLabel'));
verifyTrue(testCase,isfield(resources.planTimings, ...
    'dijPrecomputingSizeReferenceBytes'));
verifyTrue(testCase,isfield(resources.stageTimings.prepare, ...
    'lastHighWaterMainProcessMemoryBytes'));
verifyTrue(testCase,isfield(resources.stageTimings.prepare, ...
    'lastHighWaterChildProcessMemoryBytes'));
verifyTrue(testCase,isfield(resources.stageTimings.prepare, ...
    'lastHighWaterTotalProcessMemoryBytes'));
verifyTrue(testCase,isfield(resources.planTimings, ...
    'highWaterMainProcessMemoryBytes'));
verifyTrue(testCase,isfield(resources.planTimings, ...
    'highWaterChildProcessMemoryBytes'));
verifyTrue(testCase,isfield(resources.planTimings, ...
    'highWaterTotalProcessMemoryBytes'));
verifyTrue(testCase,isfield(resultsSnapshot.results.performance.planTimings, ...
    'timePerIterationSeconds'));
verifyTrue(testCase,isfield(resultsSnapshot.results.performance.planTimings, ...
    'dijPrecomputingTimeSeconds'));
verifyTrue(testCase,isfield(resultsSnapshot.results.performance.planTimings, ...
    'dijPrecomputingSizeBytes'));
end

function testResumeLoadsDataAndResultsArtifacts(testCase)
config = baseSyntheticConfig(testCase);
workflow = planWorkflowTest.SyntheticWorkflow(config);
workflow.prepare();
workflow.precompute();
workflow.pullDose();
workflow.optimize();
workflow.sample();
workflow.analyze();
workflow.save();

resumed = planWorkflowTest.SyntheticWorkflow(config);
resumed.resume(workflow.stateFile);

verifyEqual(testCase,resumed.data.preparedValue,42);
verifyEqual(testCase,resumed.data.results.score,47);
verifyTrue(testCase,isfield(resumed.data,'performance'));
verifyTrue(testCase,isfield(resumed.data.performance,'planTimings'));
verifyEqual(testCase,resumed.data.performance.planTimings(1).task, ...
    'syntheticOptimization');
verifyEqual(testCase,resumed.state.currentStage,'analyzed');
verifyTrue(testCase,any(strcmp(resumed.state.completedStages,'analyzed')));
end

function testWorkflowDataArtifactPersistsOptimizationDijAsCacheRef(testCase)
[compactData,dataMetadata,runConfig,cachePath,~,dij] = ...
    referenceDijArtifact(testCase);

verifyFalse(testCase,isfield(compactData.optimizationInput,'dij'));
verifyTrue(testCase,isfield(compactData.optimizationInput,'dijRef'));
verifyFalse(testCase,isfield(compactData,'dij'));

rehydrated = ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath);

verifyFalse(testCase,isfield(rehydrated.optimizationInput,'dij'));
verifyTrue(testCase,isfield(rehydrated.optimizationInput,'dijRef'));
fullInput = requireFullInput(rehydrated,runConfig,cachePath);
verifyEqual(testCase, ...
    fullInput.dij.totalNumOfBixels, ...
    dij.totalNumOfBixels);
verifyEqual(testCase,rehydrated.optimizationInput.dijKind,'nominal');
end

function testWorkflowDataArtifactDropsScenarioDijAlias(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
runConfig = planWorkflowTest.SyntheticWorkflow( ...
    baseSyntheticConfigWithRobustPlan(testCase,'planA')).runConfig;
cachePath = fullfile(fixture.Folder,'cache');
mkdir(cachePath);

ct = struct('numOfCtScen',1);
cst = multiScenarioCst(1);
stf = struct('totalNumOfBixels',3);
pln = struct('propStf',struct('numOfBeams',1));
pln.multScen = workflowScenarioModel();
dij = referenceDij(pln.multScen);
planConfig = struct('id','planA');
cacheContext = planWorkflow.cache.DoseInfluenceCache.context(cst,stf);
cacheFile = planWorkflow.cache.DoseInfluenceCache.cacheFile( ...
    cachePath,runConfig,'robust_planA',pln,cacheContext);
mkdir(fileparts(cacheFile));
cacheMetadata = planWorkflow.cache.DoseInfluenceCache.metadata( ...
    runConfig,'robust_planA',pln,cacheContext);
builtin('save',cacheFile,'dij','cacheMetadata','-v7.3');
cacheRef = planWorkflow.cache.DoseInfluenceCacheRef.create( ...
    'standard','robust_planA',cacheFile,cachePath,cacheMetadata, ...
    {'dij'},dij.totalNumOfBixels);

robustData = struct();
robustData.ct = ct;
robustData.cst = cst;
robustData.stf = stf;
robustData.pln = pln;
robustData.planConfig = planConfig;
robustData.dijCacheRefs.dijRobust = cacheRef;
robustData.dijRobust = dij;
robustData.optimizationInput = ...
    planWorkflow.precompute.OptimizationInput.build( ...
    ct,cst,pln,stf,dij,'scenario','planA');

[compactData,workflowDataMetadata] = ...
    planWorkflow.persistence.WorkflowDataArtifact.compactForSave( ...
    robustData,runConfig,cachePath);

verifyFalse(testCase,isfield(compactData,'dijRobust'));
verifyTrue(testCase,isfield(compactData.optimizationInput,'dijRef'));
verifyFalse(testCase,isfield(compactData.optimizationInput,'dij'));

dataMetadata = struct('workflowData',workflowDataMetadata);
rehydrated = ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath);

verifyFalse(testCase,isfield(rehydrated,'dijRobust'));
verifyFalse(testCase,isfield(rehydrated.optimizationInput,'dij'));
verifyTrue(testCase,isfield(rehydrated.optimizationInput,'dijRef'));
fullInput = requireFullInput(rehydrated,runConfig,cachePath);
verifyEqual(testCase, ...
    fullInput.dij.totalNumOfBixels, ...
    dij.totalNumOfBixels);
verifyEqual(testCase,rehydrated.optimizationInput.dijKind,'scenario');
end

function testWorkflowDataArtifactCompactsScenarioInputWithoutAlias(testCase)
[data,runConfig,cachePath,expectedRef] = ...
    robustnessPersistenceFixture(testCase,'COWC');
data = rmfield(data,'dijRobust');

[compactData,workflowDataMetadata] = ...
    planWorkflow.persistence.WorkflowDataArtifact.compactForSave( ...
    data,runConfig,cachePath);
dataMetadata = struct('workflowData',workflowDataMetadata);

verifyFalse(testCase,isfield(compactData,'dijRobust'));
verifyFalse(testCase,isfield(compactData.optimizationInput,'dij'));
verifyTrue(testCase,isfield(compactData.optimizationInput,'dijRef'));
verifyEqual(testCase, ...
    compactData.optimizationInput.dijRef.cacheRelativeFile, ...
    expectedRef.cacheRelativeFile);
verifyEqual(testCase, ...
    compactData.optimizationInput.dijRef.cacheIdentityHash, ...
    expectedRef.cacheIdentityHash);

rehydrated = ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath);
fullInput = requireFullInput(rehydrated,runConfig,cachePath);
verifyEqual(testCase,fullInput.dij.totalNumOfBixels,3);
verifyEqual(testCase,rehydrated.optimizationInput.dijKind,'scenario');
end

function testWorkflowDataArtifactResumeFailsWhenDijCacheMissing(testCase)
[compactData,dataMetadata,runConfig,cachePath,cacheFile] = ...
    referenceDijArtifact(testCase);
delete(cacheFile);

verifyError(testCase,@() ...
    requireFullInput( ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath),runConfig,cachePath), ...
    ['planWorkflow:cache:DoseInfluenceCacheService:' ...
    'MissingDijCache']);
end

function testWorkflowDataArtifactResumeFailsWhenDijCacheIdentityChanges( ...
        testCase)
[compactData,dataMetadata,runConfig,cachePath] = ...
    referenceDijArtifact(testCase);
compactData.optimizationInput.dijRef.cacheIdentityHash = 'changed';

verifyError(testCase,@() ...
    requireFullInput( ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath),runConfig,cachePath), ...
    ['planWorkflow:cache:DoseInfluenceCacheService:' ...
    'DijCacheRefIdentityMismatch']);
end

function testWorkflowDataArtifactResumeFailsWhenDijCachePhysicalTagChanges( ...
        testCase)
[compactData,dataMetadata,runConfig,cachePath] = ...
    referenceDijArtifact(testCase);
compactData.optimizationInput.dijRef.cachePhysicalTag = 'wrong_tag';

verifyError(testCase,@() ...
    requireFullInput( ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath),runConfig,cachePath), ...
    ['planWorkflow:cache:DoseInfluenceCacheService:' ...
    'DijCacheRefTagMismatch']);
end

function testWorkflowDataArtifactResumeFailsWithoutDijCachePhysicalTag( ...
        testCase)
[compactData,dataMetadata,runConfig,cachePath] = ...
    referenceDijArtifact(testCase);
compactData.optimizationInput.dijRef = ...
    rmfield(compactData.optimizationInput.dijRef,'cachePhysicalTag');

verifyError(testCase,@() ...
    requireFullInput( ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath),runConfig,cachePath), ...
    ['planWorkflow:cache:DoseInfluenceCacheService:' ...
    'DijCacheRefTagMismatch']);
end

function testWorkflowDataArtifactResumeIgnoresLogicalRefTagChange(testCase)
[compactData,dataMetadata,runConfig,cachePath] = ...
    referenceDijArtifact(testCase);
compactData.optimizationInput.dijRef.tag = 'wrong_tag';

rehydrated = ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath);
fullInput = requireFullInput(rehydrated,runConfig,cachePath);

verifyEqual(testCase,fullInput.dij.totalNumOfBixels,3);
verifyEqual(testCase,rehydrated.optimizationInput.dijKind,'nominal');
end

function testWorkflowDataArtifactResumeFailsWhenStandardContextChanges( ...
        testCase)
[compactData,dataMetadata,runConfig,cachePath] = ...
    referenceDijArtifact(testCase);
compactData.optimizationInput.cst = multiScenarioCst(4);

verifyError(testCase,@() ...
    requireFullInput( ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath),runConfig,cachePath), ...
    ['planWorkflow:cache:DoseInfluenceCacheService:' ...
    'IncompatibleDijCacheOnResume']);
end

function testWorkflowDataArtifactResumeFailsWhenDijBixelsMismatch(testCase)
[compactData,dataMetadata,runConfig,cachePath] = ...
    referenceDijArtifact(testCase);
compactData.optimizationInput.dijRef.totalNumOfBixels = 4;

verifyError(testCase,@() ...
    requireFullInput( ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath),runConfig,cachePath), ...
    ['planWorkflow:precompute:OptimizationInput:' ...
    'DijSteeringMismatch']);
end

function testWorkflowDataArtifactPersistsCacheRefsForAllRobustness(testCase)
modes = {'none','COWC','c-COWC','STOCH','INTERVAL2','INTERVAL3','PROB2'};
for modeIx = 1:numel(modes)
    mode = modes{modeIx};
    [data,runConfig,cachePath,expectedRef] = ...
        robustnessPersistenceFixture(testCase,mode);

    [compactData,workflowDataMetadata] = ...
        planWorkflow.persistence.WorkflowDataArtifact.compactForSave( ...
        data,runConfig,cachePath);
    dataMetadata = struct('workflowData',workflowDataMetadata);

    verifyFalse(testCase,isfield(compactData.optimizationInput,'dij'), ...
        mode);
    verifyEqual(testCase, ...
        compactData.optimizationInput.dijRef.cacheRelativeFile, ...
        expectedRef.cacheRelativeFile,mode);
    verifyEqual(testCase, ...
        compactData.optimizationInput.dijRef.cacheIdentityHash, ...
        expectedRef.cacheIdentityHash,mode);
    cachedRef = load(fullfile(cachePath,expectedRef.cacheRelativeFile), ...
        'cacheMetadata');
    verifyRealDijCacheMetadata(testCase,cachedRef.cacheMetadata,mode);

    rehydrated = ...
        planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
        compactData,dataMetadata,runConfig,cachePath);
    verifyFalse(testCase,isfield(rehydrated.optimizationInput,'dij'), ...
        mode);
    verifyTrue(testCase, ...
        isfield(rehydrated.optimizationInput,'dijRef'),mode);
    fullInput = requireFullInput(rehydrated,runConfig,cachePath);
    verifyEqual(testCase, ...
        fullInput.dij.totalNumOfBixels,3,mode);
    verifyEqual(testCase, ...
        rehydrated.optimizationInput.dijKind, ...
        data.optimizationInput.dijKind,mode);
end
end

function testCompactDijRefsUseEffectiveDefaultRefScen(testCase)
modes = {'INTERVAL2','INTERVAL3','PROB2'};
for modeIx = 1:numel(modes)
    mode = modes{modeIx};
    [compactData,dataMetadata,runConfig,cachePath,expectedRef] = ...
        compactRobustnessFixture(testCase,mode);
    verifyFalse(testCase,isfield(compactData.ct,'refScen'),mode);
    compactData.ct.refScen = 1;
    compactData.optimizationInput.ct.refScen = 1;

    verifyCompactCacheIdentityRefScen(testCase,cachePath,expectedRef, ...
        mode,1);

    fullInput = requireFullInput( ...
        planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
        compactData,dataMetadata,runConfig,cachePath),runConfig,cachePath);
    verifyEqual(testCase,fullInput.dij.totalNumOfBixels,3,mode);
end
end

function testCompactDijRefsRejectDifferentEffectiveRefScen(testCase)
modes = {'INTERVAL2','INTERVAL3','PROB2'};
for modeIx = 1:numel(modes)
    mode = modes{modeIx};
    [compactData,dataMetadata,runConfig,cachePath] = ...
        compactRobustnessFixture(testCase,mode);
    compactData.ct.refScen = 2;
    compactData.optimizationInput.ct.refScen = 2;

    verifyError(testCase,@() requireFullInput( ...
        planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
        compactData,dataMetadata,runConfig,cachePath), ...
        runConfig,cachePath), ...
        ['planWorkflow:cache:DoseInfluenceCacheService:' ...
        'IncompatibleCompactCacheOnResume'],mode);
end
end

function testCompactDijRefsUsePersistedRefWhenPlanScenarioModelIsCompacted( ...
        testCase)
modes = {'INTERVAL2','INTERVAL3','PROB2'};
for modeIx = 1:numel(modes)
    mode = modes{modeIx};
    [compactData,dataMetadata,runConfig,cachePath] = ...
        compactRobustnessFixture(testCase,mode);
    if isfield(compactData.pln,'multScen')
        compactData.pln = rmfield(compactData.pln,'multScen');
    end
    if isfield(compactData.optimizationInput,'pln') && ...
            isfield(compactData.optimizationInput.pln,'multScen')
        compactData.optimizationInput.pln = ...
            rmfield(compactData.optimizationInput.pln,'multScen');
    end

    fullInput = requireFullInput( ...
        planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
        compactData,dataMetadata,runConfig,cachePath), ...
        runConfig,cachePath);
    verifyEqual(testCase,fullInput.dij.totalNumOfBixels,3,mode);
end
end

function testPullDoseMaterializesCompactArtifactsBeforeRefresh(testCase)
modes = {'INTERVAL2','INTERVAL3','PROB2'};
for modeIx = 1:numel(modes)
    mode = modes{modeIx};
    [compactData,~,runConfig,cachePath] = compactRobustnessFixture( ...
        testCase,mode);
    runConfig.cacheRootPath = cachePath;
    if isfield(compactData,'quantityOpt')
        compactData = rmfield(compactData,'quantityOpt');
    end
    rootData = struct('quantityOpt','physicalDose');

    [robustData,loadedFields] = ...
        planWorkflow.resources.StageDataLifecycle.materializeDoseInfluenceArtifactsForPullDose( ...
        compactData,runConfig,rootData,[]);

    switch char(mode)
        case {'INTERVAL2','INTERVAL3'}
            verifyTrue(testCase,all(ismember( ...
                {'dij_interval','dijIntervalContext'},loadedFields)),mode);
            verifyTrue(testCase, ...
                isfield(robustData.dijIntervalContext,'scenarioModel'), ...
                mode);
            robustData = ...
                planWorkflow.precompute.IntervalDoseInfluence.restoreOptimizationPlan( ...
                robustData);
        case 'PROB2'
            verifyTrue(testCase,all(ismember( ...
                {'dij_prob','dijProbContext'},loadedFields)),mode);
            verifyTrue(testCase, ...
                isfield(robustData.dijProbContext,'scenarioModel'), ...
                mode);
            robustData = ...
                planWorkflow.precompute.ProbDoseInfluence.restoreOptimizationPlan( ...
                robustData);
    end

    verifyTrue(testCase,isfield(robustData,'plnForOptimization'),mode);
    verifyTrue(testCase, ...
        isfield(robustData.plnForOptimization,'multScen'),mode);
end
end

function testPullDoseKeepsScenarioOptimizationInputLazy(testCase)
[compactData,~,runConfig,cachePath] = compactRobustnessFixture( ...
    testCase,'COWC');
runConfig.cacheRootPath = cachePath;
previousOptimizationInput = compactData.optimizationInput;

verifyFalse(testCase,isfield(compactData,'dijRobust'));

[robustData,loadedFields] = ...
    planWorkflow.resources.StageDataLifecycle.materializeDoseInfluenceArtifactsForPullDose( ...
    compactData,runConfig,compactData,[]);

verifyEmpty(testCase,loadedFields);
verifyFalse(testCase,isfield(robustData,'dijRobust'));
if isfield(robustData,'optimizationInput')
    robustData = rmfield(robustData,'optimizationInput');
end

robustData = ...
    planWorkflow.stages.PrecomputeStage.selectOptimizationDoseInfluence( ...
    robustData,previousOptimizationInput);

verifyFalse(testCase,isfield(robustData,'dijRobust'));
verifyFalse(testCase,isfield(robustData.optimizationInput,'dij'));
verifyTrue(testCase,isfield(robustData.optimizationInput,'dijRef'));
fullInput = requireFullInput(robustData,runConfig,cachePath);
verifyEqual(testCase,fullInput.dij.totalNumOfBixels,3);
end

function testPrecomputeResolvesScenarioCacheRefWithoutPayload(testCase)
[data,runConfig,cachePath,expectedRef] = robustnessPersistenceFixture( ...
    testCase,'COWC');
cache = planWorkflow.cache.DoseInfluenceCacheService( ...
    runConfig,cachePath,@(~) []);
tag = ['robust_' char(data.planConfig.id)];

[dij,~,~,cacheRef,lazyCacheHit] = cache.getOrCreateLazyTimed( ...
    tag,data.ct,data.cst,data.stf,data.pln,[]);

verifyTrue(testCase,lazyCacheHit);
verifyEmpty(testCase,dij);
verifyEqual(testCase,cacheRef.cacheRelativeFile, ...
    expectedRef.cacheRelativeFile);
verifyEqual(testCase,cacheRef.totalNumOfBixels,3);

data = rmfield(data,'dijRobust');
data.dijCacheRefs.dijRobust = cacheRef;
data.dijRobust = ...
    planWorkflow.persistence.WorkflowDataArtifact.cachedDijArtifact( ...
    data,'dijRobust',runConfig,cachePath,data);
data = planWorkflow.stages.PrecomputeStage.selectOptimizationDoseInfluence( ...
    data);

verifyFalse(testCase,isfield(data.optimizationInput,'dij'));
verifyTrue(testCase,isfield(data.optimizationInput,'dijRef'));
fullInput = requireFullInput(data,runConfig,cachePath);
verifyEqual(testCase,fullInput.dij.totalNumOfBixels,3);
end

function testPrecomputeResolvesPhysicallySharedScenarioCacheRef( ...
        testCase)
[producerData,consumerData,runConfig,cachePath,producerRef] = ...
    physicallySharedScenarioCacheFixture(testCase);
cache = planWorkflow.cache.DoseInfluenceCacheService( ...
    runConfig,cachePath,@(~) []);
producerTag = ['robust_' char(producerData.planConfig.id)];
consumerTag = ['robust_' char(consumerData.planConfig.id)];

[dij,~,~,cacheRef,lazyCacheHit] = cache.getOrCreateLazyTimed( ...
    consumerTag,consumerData.ct,consumerData.cst,consumerData.stf, ...
    consumerData.pln,[]);

verifyTrue(testCase,lazyCacheHit);
verifyEmpty(testCase,dij);
verifyEqual(testCase,cacheRef.cacheRelativeFile, ...
    producerRef.cacheRelativeFile);
verifyEqual(testCase,cacheRef.cacheIdentityHash, ...
    producerRef.cacheIdentityHash);
verifyEqual(testCase,cacheRef.tag,consumerTag);
verifyEqual(testCase,cacheRef.producerTag,producerTag);
verifyEqual(testCase,cacheRef.cachePhysicalTag,'dij');

consumerData.dijCacheRefs.dijRobust = cacheRef;
consumerData.dijRobust = ...
    planWorkflow.persistence.WorkflowDataArtifact.cachedDijArtifact( ...
    consumerData,'dijRobust',runConfig,cachePath,consumerData);
consumerData = ...
    planWorkflow.stages.PrecomputeStage.selectOptimizationDoseInfluence( ...
    consumerData);

[compactData,workflowDataMetadata] = ...
    planWorkflow.persistence.WorkflowDataArtifact.compactForSave( ...
    consumerData,runConfig,cachePath);
dataMetadata = struct('workflowData',workflowDataMetadata);

verifyFalse(testCase,isfield(compactData.optimizationInput,'dij'));
verifyTrue(testCase,isfield(compactData.optimizationInput,'dijRef'));
verifyEqual(testCase,compactData.optimizationInput.dijRef.tag, ...
    consumerTag);
verifyEqual(testCase,compactData.optimizationInput.dijRef.producerTag, ...
    producerTag);
verifyEqual(testCase, ...
    compactData.optimizationInput.dijRef.cachePhysicalTag,'dij');

rehydrated = ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath);
fullInput = requireFullInput(rehydrated,runConfig,cachePath);
verifyEqual(testCase,fullInput.dij.totalNumOfBixels,3);
verifyEqual(testCase,rehydrated.optimizationInput.dijKind,'scenario');
end

function testOptimizeStageUsesWorkflowRootForCompactRobustRefs(testCase)
cleanup = installFluenceOptimizationDijProbe(testCase); %#ok<NASGU>
modes = {'INTERVAL2','INTERVAL3','PROB2'};
for modeIx = 1:numel(modes)
    mode = modes{modeIx};
    [compactData,~,runConfig,cachePath] = compactRobustnessFixture( ...
        testCase,mode);
    runConfig.cacheRootPath = cachePath;
    runConfig.optimizer = 'STUB';
    compactData = withoutQuantityOpt(compactData);
    data = optimizationStageRootData(compactData);
    context = planWorkflow.stages.OptimizeStage.context( ...
        runConfig,data,@runMeasuredTask,@(~) []);

    patch = planWorkflow.stages.OptimizeStage.run(context);

    robustData = patch.data.robustPlans{1};
    expectedCount = ...
        planWorkflow.config.RobustPlanConfig.variantWithPenaltyCount( ...
        compactData.planConfig);
    verifyNumElements(testCase,robustData.variantResults, ...
        expectedCount,mode);
    verifyFalse(testCase,isfield(robustData.optimizationInput,'dij'), ...
        mode);
    verifyTrue(testCase,isfield(robustData.optimizationInput,'dijRef'), ...
        mode);
    rootData = patch.data;
    rootData.quantityOpt = 'physicalDose';
    fullInput = planWorkflow.precompute.OptimizationInput.requireFullDij( ...
        robustData,'test full robust optimization input',runConfig, ...
        cachePath,rootData);
    verifyEqual(testCase, ...
        fullInput.dij.totalNumOfBixels,3,mode);
    verifyEqual(testCase,arrayfun(@(result) result.resultGUI.w, ...
        robustData.variantResults),3 * ones(1,expectedCount),mode);
end
end

function testDosePullingUsesWorkflowRootForCompactRobustRefs(testCase)
modes = {'INTERVAL2','INTERVAL3','PROB2'};
for modeIx = 1:numel(modes)
    mode = modes{modeIx};
    [compactData,~,runConfig,cachePath] = compactRobustnessFixture( ...
        testCase,mode);
    runConfig.cacheRootPath = cachePath;
    runConfig = robustDosePullingRunConfig(runConfig);
    compactData = withoutQuantityOpt(compactData);
    compactData.ctScenProb = 1;
    rootData = struct('quantityOpt','physicalDose');
    seenBixels = [];
    context = planWorkflow.precompute.DosePulling.context( ...
        runConfig,@runOptimization,@runAnalysis,@runMetrics, ...
        @runPolicy,@(~) []);
    context.workflowRootData = rootData;

    [robustData,report] = ...
        planWorkflow.precompute.DosePulling.runRobust( ...
        context,compactData);

    expectedCount = ...
        planWorkflow.config.RobustPlanConfig.variantWithPenaltyCount( ...
        compactData.planConfig);
    verifyEqual(testCase,seenBixels,3 * ones(1,expectedCount),mode);
    verifyNumElements(testCase,report.plans,expectedCount,mode);
    verifyTrue(testCase,isfield(robustData.optimizationInput,'dij'), ...
        mode);
    verifyFalse(testCase,isfield(robustData.optimizationInput,'dijRef'), ...
        mode);
    verifyEqual(testCase, ...
        robustData.optimizationInput.dij.totalNumOfBixels,3,mode);
end

    function resultGUI = runOptimization(dij,~,~,~)
        seenBixels(end + 1) = dij.totalNumOfBixels;
        resultGUI = struct('w',dij.totalNumOfBixels);
    end

    function [resultGUI,dvh,qi] = runAnalysis( ...
            ~,~,~,~,resultGUI,~) %#ok<INUSD>
        dvh = [];
        qi = [];
    end

    function metrics = runMetrics( ...
            ~,~,resultGUI,~,iteration,~) %#ok<INUSD>
        metrics = struct('step',2,'iteration',iteration, ...
            'targetNames',{{'CTV'}},'criteria',{{'meanQiTarget'}}, ...
            'meanQiTarget',resultGUI.w,'minQiTarget',resultGUI.w, ...
            'selectedCriterion','meanQiTarget', ...
            'selectedValues',resultGUI.w,'limits',0, ...
            'isSatisfied',true);
    end

    function tf = runPolicy(~)
        tf = false;
    end
end

function verifyRealDijCacheMetadata(testCase,cacheMetadata,mode)
verifyTrue(testCase,isfield(cacheMetadata,'cacheIdentity'),mode);
identity = cacheMetadata.cacheIdentity;
verifyTrue(testCase,isfield(identity,'cst'),mode);
verifyTrue(testCase,isfield(identity,'stf'),mode);
verifyTrue(testCase,isfield(identity,'scenario'),mode);
verifyTrue(testCase,isfield(identity.scenario,'fingerprint'),mode);
verifyNotEmpty(testCase,identity.scenario.fingerprint,mode);
verifyTrue(testCase,isfield(cacheMetadata,'scenarioFingerprint'),mode);
verifyNotEmpty(testCase,cacheMetadata.scenarioFingerprint,mode);
if any(strcmp(char(mode),{'INTERVAL2','INTERVAL3'}))
    verifyTrue(testCase,isfield(identity,'interval'),mode);
elseif strcmp(char(mode),'PROB2')
    verifyTrue(testCase,isfield(identity,'prob'),mode);
end
end

function verifyCompactCacheIdentityRefScen(testCase,cachePath,ref,mode, ...
        expectedRefScen)
cachedRef = load(fullfile(cachePath,ref.cacheRelativeFile), ...
    'cacheMetadata');
identity = cachedRef.cacheMetadata.cacheIdentity;
switch char(mode)
    case {'INTERVAL2','INTERVAL3'}
        verifyEqual(testCase,identity.interval.refScen, ...
            expectedRefScen,mode);
    case 'PROB2'
        verifyEqual(testCase,identity.prob.refScen, ...
            expectedRefScen,mode);
    otherwise
        error('Unsupported compact mode "%s".',char(mode));
end
end

function input = requireFullInput(owner,runConfig,cachePath)
input = planWorkflow.precompute.OptimizationInput.requireFullDij( ...
    owner,'test full optimization input',runConfig,cachePath,owner);
end

function testWorkflowDataArtifactDerivedRefsRejectPostPullContextChange( ...
        testCase)
modes = {'INTERVAL2','INTERVAL3','PROB2'};
for modeIx = 1:numel(modes)
    mode = modes{modeIx};
    [data,runConfig,cachePath,expectedRef] = ...
        robustnessPersistenceFixture(testCase,mode);
    data.cst = {2};
    data.pln.propStf.numOfBeams = 99;

    [compactData,workflowDataMetadata] = ...
        planWorkflow.persistence.WorkflowDataArtifact.compactForSave( ...
        data,runConfig,cachePath);
    dataMetadata = struct('workflowData',workflowDataMetadata);

    verifyEqual(testCase, ...
        compactData.optimizationInput.dijRef.cacheRelativeFile, ...
        expectedRef.cacheRelativeFile,mode);
    verifyEqual(testCase, ...
        compactData.optimizationInput.dijRef.cacheIdentityHash, ...
        expectedRef.cacheIdentityHash,mode);

    verifyError(testCase,@() requireFullInput( ...
        planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
        compactData,dataMetadata,runConfig,cachePath), ...
        runConfig,cachePath), ...
        ['planWorkflow:cache:DoseInfluenceCacheService:' ...
        'IncompatibleCompactCacheOnResume'],mode);
end
end

function testWorkflowDataArtifactEmbedsDijWithoutCacheRef(testCase)
modes = {'none','COWC','STOCH','INTERVAL2','PROB2'};
for modeIx = 1:numel(modes)
    mode = modes{modeIx};
    [data,runConfig,cachePath] = robustnessPersistenceFixture( ...
        testCase,mode);
    data = rmfield(data,'dijCacheRefs');
    runConfig.writeCache = false;
    runConfig.useCache = false;

    [compactData,workflowDataMetadata] = ...
        planWorkflow.persistence.WorkflowDataArtifact.compactForSave( ...
        data,runConfig,cachePath);
    dataMetadata = struct('workflowData',workflowDataMetadata);

    verifyFalse(testCase,isfield(compactData.optimizationInput,'dij'), ...
        mode);
    verifyFalse(testCase,isfield(compactData.optimizationInput,'dijRef'), ...
        mode);
    verifyTrue(testCase,isfield(compactData.optimizationInput, ...
        'dijInline'),mode);
    verifyEqual(testCase, ...
        compactData.optimizationInput.dijInline.artifactKind, ...
        planWorkflow.persistence.WorkflowDataArtifact.InlineKind,mode);

    rehydrated = ...
        planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
        compactData,dataMetadata,runConfig,cachePath);
    verifyFalse(testCase,isfield(rehydrated.optimizationInput,'dij'), ...
        mode);
    verifyTrue(testCase, ...
        isfield(rehydrated.optimizationInput,'dijInline'),mode);
    fullInput = requireFullInput(rehydrated,runConfig,cachePath);
    verifyEqual(testCase, ...
        fullInput.dij.totalNumOfBixels,3,mode);
    verifyEqual(testCase,rehydrated.optimizationInput.dijKind, ...
        data.optimizationInput.dijKind,mode);
end
end

function testWorkflowDataArtifactInvalidRefDoesNotFallbackToInline(testCase)
[compactData,dataMetadata,runConfig,cachePath] = ...
    referenceDijArtifact(testCase);
compactData.optimizationInput.dijInline = ...
    inlineDijArtifact(referenceDij(),'nominal','optimizationInput');
compactData.optimizationInput.dijRef.cacheIdentityHash = 'changed';

verifyError(testCase,@() ...
    requireFullInput( ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath),runConfig,cachePath), ...
    ['planWorkflow:cache:DoseInfluenceCacheService:' ...
    'DijCacheRefIdentityMismatch']);
end

function testWorkflowDataArtifactCompactCacheRejectsScenarioFingerprint( ...
        testCase)
modes = {'INTERVAL2','PROB2'};
for modeIx = 1:numel(modes)
    mode = modes{modeIx};
    [compactData,dataMetadata,runConfig,cachePath,expectedRef] = ...
        compactRobustnessFixture(testCase,mode);
    cacheFile = fullfile(cachePath,expectedRef.cacheRelativeFile);
    cached = load(cacheFile);
    cacheMetadata = cached.cacheMetadata;
    cacheMetadata.scenarioFingerprint = 'different-scenario';
    switch char(mode)
        case 'INTERVAL2'
            dij_interval = cached.dij_interval; %#ok<NASGU>
            dijIntervalContext = cached.dijIntervalContext; %#ok<NASGU>
            builtin('save',cacheFile,'dij_interval', ...
                'dijIntervalContext','cacheMetadata','-v7.3');
        case 'PROB2'
            dij_prob = cached.dij_prob; %#ok<NASGU>
            dijProbContext = cached.dijProbContext; %#ok<NASGU>
            builtin('save',cacheFile,'dij_prob', ...
                'dijProbContext','cacheMetadata','-v7.3');
    end

    verifyError(testCase,@() ...
        requireFullInput( ...
        planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
        compactData,dataMetadata,runConfig,cachePath), ...
        runConfig,cachePath), ...
        ['planWorkflow:cache:DoseInfluenceCacheService:' ...
        'IncompatibleCompactCacheOnResume'],mode);
end
end

function testWorkflowDataArtifactPersistFailsForWrongCacheRefKind(testCase)
[data,runConfig,cachePath] = robustnessPersistenceFixture(testCase,'INTERVAL2');
data.dijCacheRefs.interval.cacheKind = 'standard';

verifyError(testCase,@() ...
    planWorkflow.persistence.WorkflowDataArtifact.compactForSave( ...
    data,runConfig,cachePath), ...
    ['planWorkflow:persistence:WorkflowDataArtifact:' ...
    'DijCacheRefKindMismatch']);
end

function testWorkflowDataArtifactPersistFailsWhenCacheVariableMissing(testCase)
[data,runConfig,cachePath,expectedRef] = ...
    robustnessPersistenceFixture(testCase,'COWC');
cacheFile = fullfile(cachePath,expectedRef.cacheRelativeFile);
cached = load(cacheFile,'cacheMetadata');
cacheMetadata = cached.cacheMetadata; %#ok<NASGU>
builtin('save',cacheFile,'cacheMetadata','-v7.3');

verifyError(testCase,@() ...
    planWorkflow.persistence.WorkflowDataArtifact.compactForSave( ...
    data,runConfig,cachePath), ...
    ['planWorkflow:persistence:WorkflowDataArtifact:' ...
    'IncompleteDijCache']);
end

function testWorkflowDataArtifactRejectsLegacyDataDij(testCase)
config = baseSyntheticConfig(testCase);
runConfig = planWorkflowTest.SyntheticWorkflow(config).runConfig;
data = struct('dij',referenceDij());

verifyError(testCase,@() ...
    planWorkflow.persistence.WorkflowDataArtifact.compactForSave( ...
    data,runConfig,config.cacheRootPath), ...
    'planWorkflow:persistence:WorkflowDataArtifact:LegacyDataDij');
end

function testWorkflowDataArtifactRejectsOldSchemaOnResume(testCase)
config = baseSyntheticConfig(testCase);
runConfig = planWorkflowTest.SyntheticWorkflow(config).runConfig;

verifyError(testCase,@() ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    struct(),struct(),runConfig,config.cacheRootPath), ...
    ['planWorkflow:persistence:WorkflowDataArtifact:' ...
    'UnsupportedWorkflowDataSchema']);
end

function testSaveStructArtifactSanitizesBioModelWithoutDeprecatedWarnings(testCase)
workflow = planWorkflowTest.SyntheticWorkflow(baseSyntheticConfig(testCase));
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
artifactFile = fullfile(fixture.Folder,'bio_model_artifact.mat');

artifact = struct();
artifact.pln = struct();
artifact.pln.bioModel = matRad_EmptyBiologicalModel();
artifact.pln.propOpt = struct('quantityOpt','physicalDose', ...
                              'quantityVis','physicalDose');

consoleText = evalc( ...
    'workflow.saveStructArtifactForTest(artifactFile,artifact,''test'');');

verifyFalse(testCase,contains(consoleText, ...
    'Property quantityOpt is deprecated from bioModel'));
verifyFalse(testCase,contains(consoleText, ...
    'Property quantityVis is deprecated from bioModel'));
verifyTrue(testCase,isa(artifact.pln.bioModel,'matRad_BiologicalModel'));

saved = load(artifactFile,'pln');
verifyEqual(testCase,saved.pln.propOpt.quantityOpt,'physicalDose');
verifyEqual(testCase,saved.pln.propOpt.quantityVis,'physicalDose');
verifyTrue(testCase,isstruct(saved.pln.bioModel));
verifyEqual(testCase,saved.pln.bioModel.bioModelClass, ...
    'matRad_EmptyBiologicalModel');
verifyEqual(testCase,saved.pln.bioModel.model,'none');
verifyEqual(testCase,saved.pln.bioModel.defaultReportQuantity, ...
    'physicalDose');
verifyEqual(testCase,saved.pln.bioModel.quantityOpt,'physicalDose');
verifyEqual(testCase,saved.pln.bioModel.quantityVis,'physicalDose');
end

function testReleaseMemoryClearsOnlyInMemoryData(testCase)
workflow = planWorkflowTest.SyntheticWorkflow(baseSyntheticConfig(testCase));
workflow.prepare();
verifyTrue(testCase,isfield(workflow.data,'preparedValue'));

workflow.releaseMemory();

verifyEqual(testCase,fieldnames(workflow.data),cell(0,1));
verifyTrue(testCase,isfile(workflow.stateFile));
end

function testGuiProgressReporterReceivesStageEvents(testCase)
workflow = planWorkflowTest.SyntheticWorkflow(baseSyntheticConfig(testCase));
reporter = planWorkflowTest.ProgressReporterProbe();
workflow.guiProgressReporter = reporter;

workflow.prepare();
workflow.precompute();
workflow.pullDose();
workflow.optimize();
workflow.sample();
workflow.analyze();

verifyGreaterThanOrEqual(testCase,numel(reporter.Events),12);
verifyEqual(testCase,reporter.Events{1}{1},'stageStarted');
verifyEqual(testCase,reporter.Events{1}{2},'prepare');
verifyEqual(testCase,reporter.Events{end - 1}{1},'stageCompleted');
verifyEqual(testCase,reporter.Events{end - 1}{2},'analyze');
verifyEqual(testCase,reporter.Events{end}{1},'showResults');
verifyFalse(testCase,any(cellfun(@(event) ...
    strcmp(event{1},'saveGuiSnapshot'),reporter.Events)));
verifyEqual(testCase,reporter.Results.score,47);
verifyTrue(testCase,isfield(reporter.Results,'performance'));
verifyEqual(testCase, ...
    reporter.Results.performance.stageTimings.analyze.lastStatus, ...
    'completed');
verifyTrue(testCase,isfield(reporter.Results.performance,'planTimings'));
verifyEqual(testCase,reporter.Results.performance.planTimings(1).task, ...
    'syntheticOptimization');
verifyEqual(testCase,reporter.LastFraction,1);
verifyTrue(testCase,any(cellfun(@(event) ...
    strcmp(event{1},'stageProgress') && strcmp(event{2},'sample'), ...
    reporter.Events)));
verifyTrue(testCase,any(contains(reporter.Messages, ...
    'Workflow state saved')));
end

function testRecalculateAnalysisRunsCompletedAnalysisAgain(testCase)
workflow = planWorkflowTest.SyntheticWorkflow(baseSyntheticConfig(testCase));
reporter = planWorkflowTest.ProgressReporterProbe();
workflow.guiProgressReporter = reporter;

workflow.prepare();
workflow.precompute();
workflow.pullDose();
workflow.optimize();
workflow.sample();
workflow.analyze();
workflow.releaseMemory();
workflow.recalculateAnalysis();

verifyEqual(testCase,workflow.data.results.analysisCount,2);
verifyTrue(testCase,any(strcmp(workflow.state.completedStages,'analyzed')));
verifyGreaterThanOrEqual(testCase, ...
    workflow.state.stageTimings.analyze.attempts,2);
showResultCount = sum(cellfun(@(event) ...
    strcmp(event{1},'showResults'),reporter.Events));
verifyEqual(testCase,showResultCount,2);
verifyEqual(testCase,reporter.Results.analysisCount,2);
verifyTrue(testCase,isfield(reporter.Results,'performance'));
verifyTrue(testCase,isfield(reporter.Results.performance,'planTimings'));
verifyEqual(testCase,reporter.Results.performance.planTimings(1).task, ...
    'syntheticOptimization');
end

function testRecalculateAnalysisAppliesAnalysisStageConfig(testCase)
workflow = planWorkflowTest.SyntheticWorkflow(baseSyntheticConfig(testCase));

workflow.prepare();
workflow.precompute();
workflow.pullDose();
workflow.optimize();
workflow.sample();
workflow.analyze();
sampleAttempts = workflow.state.stageTimings.sample.attempts;
analysis = workflow.runConfig.analysis;
analysis.evaluationMode = 'total';
analysis.gammaCriteria = [2 2];

workflow.recalculateAnalysis(analysis);

verifyEqual(testCase,workflow.runConfig.analysis.evaluationMode,'total');
verifyEqual(testCase,workflow.runConfig.analysis.gammaCriteria,[2 2]);
verifyEqual(testCase,workflow.data.results.analysis.evaluationMode,'total');
verifyEqual(testCase,workflow.data.results.analysis.gammaCriteria,[2 2]);
verifyEqual(testCase,workflow.data.results.analysisCount,2);
verifyEqual(testCase,workflow.state.stageTimings.sample.attempts, ...
    sampleAttempts);
verifyEqual(testCase,workflow.state.stageTimings.analyze.attempts,2);
end

function testGuiProgressReporterCanStopWorkflow(testCase)
workflow = planWorkflowTest.SyntheticWorkflow(baseSyntheticConfig(testCase));
reporter = planWorkflowTest.ProgressReporterProbe();
workflow.guiProgressReporter = reporter;
reporter.requestStop();

verifyError(testCase,@() workflow.prepare(), ...
    'planWorkflow:gui:PlanProgressReporter:Stopped');
verifyTrue(testCase,any(cellfun(@(event) ...
    strcmp(event{1},'stageFailed') && strcmp(event{2},'prepare'), ...
    reporter.Events)));
end

function config = baseSyntheticConfig(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
config = struct();
config.outputRootPath = fullfile(fixture.Folder,'output');
config.cacheRootPath = fullfile(fixture.Folder,'cache');
config.runId = 'synthetic-workflow-test';
config.precompute.useCache = true;
config.precompute.writeCache = true;
end

function config = baseSyntheticConfigWithRobustPlan(testCase,planId)
config = baseSyntheticConfig(testCase);
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = char(planId);
plan.label = 'Plan A';
plan.objectiveSetName = char(planId);
plan.robustnessMode = 'COWC';
plan.hasNominalObjectives = false;
plan.requiresNominalDij = false;
plan.requiresScenarioDij = true;
plan.requiresIntervalDij = false;
plan.requiresProbDij = false;
plan.scenario = planWorkflow.config.RobustPlanConfig.defaultScenario( ...
    'wcScen');
plan.variants = planWorkflow.config.RobustPlanConfig.defaultVariants( ...
    'COWC');
config.precompute.robustPlans = plan;
end

function runConfig = persistenceRunConfig(testCase,mode,planId)
config = baseSyntheticConfig(testCase);
if ~strcmp(char(mode),'none')
    config.precompute.robustPlans = robustPlanConfigForMode(mode,planId);
end
runConfig = planWorkflowTest.SyntheticWorkflow(config).runConfig;
runConfig.useCache = true;
runConfig.writeCache = true;
end

function plan = robustPlanConfigForMode(mode,planId)
mode = char(mode);
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = char(planId);
plan.label = mode;
plan.objectiveSetName = char(planId);
plan.robustnessMode = mode;
plan.hasNominalObjectives = false;
plan.requiresNominalDij = false;
plan.requiresScenarioDij = any(strcmp(mode,{'COWC','c-COWC','STOCH'}));
plan.requiresIntervalDij = any(strcmp(mode,{'INTERVAL2','INTERVAL3'}));
plan.requiresProbDij = strcmp(mode,'PROB2');
plan.scenario = planWorkflow.config.RobustPlanConfig.defaultScenario( ...
    'wcScen');
plan.robustnessOptions = robustnessOptionsForMode(mode);
plan.variants = planWorkflow.config.RobustPlanConfig.defaultVariants(mode);
end

function options = robustnessOptionsForMode(mode)
options = struct();
if any(strcmp(char(mode),{'INTERVAL2','INTERVAL3'}))
    options.radiusMode = 'extreme';
end
end

function [compactData,dataMetadata,runConfig,cachePath,cacheFile,dij] = ...
        referenceDijArtifact(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
runConfig = planWorkflowTest.SyntheticWorkflow( ...
    baseSyntheticConfig(testCase)).runConfig;
runConfig.useCache = true;
runConfig.writeCache = true;
cachePath = fullfile(fixture.Folder,'cache');
mkdir(cachePath);

ct = struct('numOfCtScen',1);
cst = {1};
stf = struct('totalNumOfBixels',3);
pln = struct('propStf',struct('numOfBeams',1));
dij = referenceDij();
cacheContext = planWorkflow.cache.DoseInfluenceCache.context(cst,stf);
cacheFile = planWorkflow.cache.DoseInfluenceCache.cacheFile( ...
    cachePath,runConfig,'reference',pln,cacheContext);
mkdir(fileparts(cacheFile));
cacheMetadata = planWorkflow.cache.DoseInfluenceCache.metadata( ...
    runConfig,'reference',pln,cacheContext);
builtin('save',cacheFile,'dij','cacheMetadata','-v7.3');
cacheRef = planWorkflow.cache.DoseInfluenceCacheRef.create( ...
    'standard','reference',cacheFile,cachePath,cacheMetadata, ...
    {'dij'},dij.totalNumOfBixels);

data = struct();
data.ct = ct;
data.cst = cst;
data.stf = stf;
data.pln = pln;
data.dijCacheRefs.dij = cacheRef;
data.optimizationInput = planWorkflow.precompute.OptimizationInput.build( ...
    ct,cst,pln,stf,dij,'nominal','reference');

[compactData,workflowDataMetadata] = ...
    planWorkflow.persistence.WorkflowDataArtifact.compactForSave( ...
    data,runConfig,cachePath);
dataMetadata = struct('workflowData',workflowDataMetadata);
end

function dij = referenceDij(scenarioModel)
dij = struct();
dij.totalNumOfBixels = 3;
if nargin < 1 || isempty(scenarioModel)
    dij.physicalDose = {sparse(1,3)};
    return;
end
dij.numOfScenarios = scenarioModel.numScenarios();
dij.physicalDose = cell(size(scenarioModel.scenMask));
scenarioIds = scenarioModel.scenarioIds();
for scenarioIx = 1:numel(scenarioIds)
    fullScenIx = scenarioModel.getDijScenarioIndex(scenarioIds(scenarioIx));
    dij.physicalDose{fullScenIx} = sparse(1,1,1,1,3);
end
end

function inline = inlineDijArtifact(dij,dijKind,role)
inline = struct();
inline.artifactKind = ...
    planWorkflow.persistence.WorkflowDataArtifact.InlineKind;
inline.schemaVersion = 1;
inline.role = char(role);
inline.dijKind = char(dijKind);
inline.totalNumOfBixels = ...
    planWorkflow.precompute.OptimizationInput.totalNumOfBixels(dij);
inline.dij = dij;
end

function scenarioModel = workflowScenarioModel()
scenarioModel = matRad_WorstCaseScenarios();
scenarioModel.scenarioDimensionActive = {'ct','setup'};
scenarioModel.shiftSD = [1 2 3];
scenarioModel.wcSigma = 1;
end

function cst = multiScenarioCst(numScenarios)
cst = cell(1,6);
cst{1,1} = 0;
cst{1,2} = 'CTV';
cst{1,3} = 'TARGET';
cst{1,4} = cell(1,numScenarios);
for scenarioIx = 1:numScenarios
    cst{1,4}{scenarioIx} = sprintf('ct%d-voi1',scenarioIx);
end
cst{1,5} = struct();
cst{1,6} = [];
end

function [data,runConfig,cachePath,expectedRef] = ...
        robustnessPersistenceFixture(testCase,mode)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
runConfig = planWorkflowTest.SyntheticWorkflow( ...
    baseSyntheticConfig(testCase)).runConfig;
runConfig.useCache = true;
runConfig.writeCache = true;
cachePath = fullfile(fixture.Folder,'cache');
mkdir(cachePath);

ct = struct('numOfCtScen',1);
cst = multiScenarioCst(1);
stf = struct('totalNumOfBixels',3);
pln = struct('propStf',struct('numOfBeams',1));
pln.multScen = workflowScenarioModel();

switch char(mode)
    case 'none'
        dij = referenceDij(pln.multScen);
        [cacheFile,cacheMetadata] = writeStandardDijCache( ...
            cachePath,runConfig,'reference',cst,stf,pln,dij);
        expectedRef = planWorkflow.cache.DoseInfluenceCacheRef.create( ...
            'standard','reference',cacheFile,cachePath,cacheMetadata, ...
            {'dij'},dij.totalNumOfBixels);
        data = struct();
        data.ct = ct;
        data.cst = cst;
        data.stf = stf;
        data.pln = pln;
        data.dijCacheRefs.dij = expectedRef;
        data.optimizationInput = ...
            planWorkflow.precompute.OptimizationInput.build( ...
            ct,cst,pln,stf,dij,'nominal','reference');
    case {'COWC','c-COWC','STOCH'}
        dij = referenceDij(pln.multScen);
        planId = planIdForMode(mode);
        runConfig = persistenceRunConfig(testCase,mode,planId);
        tag = ['robust_' planId];
        data = robustPlanData(ct,cst,stf,pln,mode,planId);
        [cacheFile,cacheMetadata] = writeStandardDijCache( ...
            cachePath,runConfig,tag,cst,stf,pln,dij);
        expectedRef = planWorkflow.cache.DoseInfluenceCacheRef.create( ...
            'standard',tag,cacheFile,cachePath,cacheMetadata, ...
            {'dij'},dij.totalNumOfBixels);
        data.dijRobust = dij;
        data.dijCacheRefs.dijRobust = expectedRef;
        data.optimizationInput = ...
            planWorkflow.precompute.OptimizationInput.build( ...
            ct,cst,pln,stf,dij,'scenario','scenario');
    case {'INTERVAL2','INTERVAL3'}
        dij_interval = intervalDij(mode);
        dijIntervalContext = derivedDijContext(pln.multScen);
        planId = planIdForMode(mode);
        runConfig = persistenceRunConfig(testCase,mode,planId);
        tag = ['interval_' planId];
        data = robustPlanData(ct,cst,stf,pln,mode,planId);
        [cacheFile,cacheMetadata] = writeIntervalDijCache( ...
            cachePath,runConfig,data,dij_interval,dijIntervalContext);
        expectedRef = planWorkflow.cache.DoseInfluenceCacheRef.create( ...
            'interval',tag,cacheFile,cachePath,cacheMetadata, ...
            {'dij_interval','dijIntervalContext'}, ...
            dijIntervalContext.totalNumOfBixels);
        data.dij_interval = dij_interval;
        data.dijIntervalContext = dijIntervalContext;
        data.dijCacheRefs.interval = expectedRef;
        data.optimizationInput = ...
            planWorkflow.precompute.OptimizationInput.build( ...
            ct,cst,pln,stf,dijIntervalContext,'interval','interval');
    case 'PROB2'
        dij_prob = probDij();
        dijProbContext = derivedDijContext(pln.multScen);
        planId = planIdForMode(mode);
        runConfig = persistenceRunConfig(testCase,mode,planId);
        tag = ['prob_' planId];
        data = robustPlanData(ct,cst,stf,pln,mode,planId);
        [cacheFile,cacheMetadata] = writeProbDijCache( ...
            cachePath,runConfig,data,dij_prob,dijProbContext);
        expectedRef = planWorkflow.cache.DoseInfluenceCacheRef.create( ...
            'prob',tag,cacheFile,cachePath,cacheMetadata, ...
            {'dij_prob','dijProbContext'}, ...
            dijProbContext.totalNumOfBixels);
        data.dij_prob = dij_prob;
        data.dijProbContext = dijProbContext;
        data.dijCacheRefs.prob = expectedRef;
        data.optimizationInput = ...
            planWorkflow.precompute.OptimizationInput.build( ...
            ct,cst,pln,stf,dijProbContext,'prob','prob');
    otherwise
        error('Unsupported test robustness mode "%s".',char(mode));
end
end

function [producerData,consumerData,runConfig,cachePath,producerRef] = ...
        physicallySharedScenarioCacheFixture(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
cachePath = fullfile(fixture.Folder,'cache');
mkdir(cachePath);

producerPlan = robustPlanConfigForMode('COWC','Minimax');
consumerPlan = robustPlanConfigForMode('STOCH','Stochastic');
config = baseSyntheticConfig(testCase);
config.precompute.robustPlans = [producerPlan consumerPlan];
runConfig = planWorkflowTest.SyntheticWorkflow(config).runConfig;
runConfig.useCache = true;
runConfig.writeCache = true;

ct = struct('numOfCtScen',1);
cst = multiScenarioCst(1);
stf = struct('totalNumOfBixels',3);
pln = struct('propStf',struct('numOfBeams',1));
pln.multScen = workflowScenarioModel();
dij = referenceDij(pln.multScen);

producerData = robustPlanData(ct,cst,stf,pln,'COWC','Minimax');
consumerData = robustPlanData(ct,cst,stf,pln,'STOCH','Stochastic');
producerTag = ['robust_' char(producerData.planConfig.id)];
[cacheFile,cacheMetadata] = writeStandardDijCache( ...
    cachePath,runConfig,producerTag,cst,stf,pln,dij);
producerRef = planWorkflow.cache.DoseInfluenceCacheRef.create( ...
    'standard',producerTag,cacheFile,cachePath,cacheMetadata, ...
    {'dij'},dij.totalNumOfBixels);
producerData.dijRobust = dij;
producerData.dijCacheRefs.dijRobust = producerRef;
end

function [compactData,dataMetadata,runConfig,cachePath,expectedRef] = ...
        compactRobustnessFixture(testCase,mode)
[data,runConfig,cachePath,expectedRef] = robustnessPersistenceFixture( ...
    testCase,mode);
[compactData,workflowDataMetadata] = ...
    planWorkflow.persistence.WorkflowDataArtifact.compactForSave( ...
    data,runConfig,cachePath);
dataMetadata = struct('workflowData',workflowDataMetadata);
end

function data = robustPlanData(ct,cst,stf,pln,mode,planId)
data = struct();
data.ct = ct;
data.cst = cst;
data.stf = stf;
data.pln = pln;
data.quantityOpt = 'physicalDose';
data.strategy = struct('name',char(mode));
data.planConfig = robustPlanConfigForMode(mode,planId);
end

function [cacheFile,cacheMetadata] = writeStandardDijCache(cachePath, ...
        runConfig,tag,cst,stf,pln,dij)
cacheContext = planWorkflow.cache.DoseInfluenceCache.context(cst,stf);
cacheFile = planWorkflow.cache.DoseInfluenceCache.cacheFile( ...
    cachePath,runConfig,tag,pln,cacheContext);
ensureFolder(fileparts(cacheFile));
cacheMetadata = planWorkflow.cache.DoseInfluenceCache.metadata( ...
    runConfig,tag,pln,cacheContext);
cacheMetadata = attachPrecomputeMetadata( ...
    cacheMetadata,dij,'test',tag,'dij');
payload = struct('dij',dij,'cacheMetadata',cacheMetadata); %#ok<NASGU>
builtin('save',cacheFile,'-struct','payload','-v7.3');
end

function [cacheFile,cacheMetadata] = writeIntervalDijCache(cachePath, ...
        runConfig,robustData,dij_interval,dijIntervalContext)
context = persistenceCacheContext(runConfig,cachePath);
tag = planWorkflow.precompute.IntervalDoseInfluence.cacheTag(robustData);
cacheContext = planWorkflow.precompute.IntervalDoseInfluence.cacheContext( ...
    context,robustData);
cacheFile = context.cache.file(tag,robustData.pln,cacheContext);
ensureFolder(fileparts(cacheFile));
cacheMetadata = context.cache.metadata(tag,robustData.pln,cacheContext);
cacheMetadata.intervalMode = robustData.strategy.name;
cacheMetadata.intervalQuantity = dij_interval.quantity;
cacheMetadata.intervalQuantityField = dij_interval.quantityField;
cacheMetadata = attachPrecomputeMetadata( ...
    cacheMetadata,dijIntervalContext,'test',tag,'dij_interval');
payload = struct('dij_interval',dij_interval, ...
    'dijIntervalContext',dijIntervalContext, ...
    'cacheMetadata',cacheMetadata); %#ok<NASGU>
builtin('save',cacheFile,'-struct','payload','-v7.3');
end

function [cacheFile,cacheMetadata] = writeProbDijCache(cachePath, ...
        runConfig,robustData,dij_prob,dijProbContext)
context = persistenceCacheContext(runConfig,cachePath);
tag = planWorkflow.precompute.ProbDoseInfluence.cacheTag(robustData);
cacheContext = planWorkflow.precompute.ProbDoseInfluence.cacheContext( ...
    context,robustData);
cacheFile = context.cache.file(tag,robustData.pln,cacheContext);
ensureFolder(fileparts(cacheFile));
cacheMetadata = context.cache.metadata(tag,robustData.pln,cacheContext);
cacheMetadata.probabilisticMode = 'PROB';
cacheMetadata.probabilisticQuantity = dij_prob.quantity;
cacheMetadata.probabilisticQuantityField = dij_prob.quantityField;
cacheMetadata = attachPrecomputeMetadata( ...
    cacheMetadata,dijProbContext,'test',tag,'dij_prob');
payload = struct('dij_prob',dij_prob, ...
    'dijProbContext',dijProbContext, ...
    'cacheMetadata',cacheMetadata); %#ok<NASGU>
builtin('save',cacheFile,'-struct','payload','-v7.3');
end

function cacheMetadata = attachPrecomputeMetadata( ...
        cacheMetadata,value,role,label,artifact)
timingOptions = planWorkflow.performance.PrecomputeTiming.cacheOptions( ...
    role,label,artifact,[],[]);
sizeOptions = planWorkflow.performance.PrecomputeSize.cacheOptions( ...
    role,label,artifact,[],[]);
cacheMetadata.dijPrecomputingTiming = ...
    planWorkflow.performance.PrecomputeTiming.fromOptions( ...
    1,timingOptions);
cacheMetadata.dijPrecomputingSize = ...
    planWorkflow.performance.PrecomputeSize.fromOptions( ...
    value,sizeOptions);
end

function context = persistenceCacheContext(runConfig,cachePath)
context = struct();
context.runConfig = runConfig;
context.data = struct('quantityOpt','physicalDose');
context.cache = planWorkflow.cache.DoseInfluenceCacheService( ...
    runConfig,cachePath,@(~) []);
context.log = @(~) [];
end

function data = withoutQuantityOpt(data)
if isfield(data,'quantityOpt')
    data = rmfield(data,'quantityOpt');
end
end

function data = optimizationStageRootData(robustData)
data = struct();
data.ct = robustData.ct;
data.cst = robustData.cst;
data.stf = robustData.stf;
data.pln = robustData.pln;
data.quantityOpt = 'physicalDose';
data.optimizationInput = planWorkflow.precompute.OptimizationInput.build( ...
    data.ct,data.cst,data.pln,data.stf,referenceDij(), ...
    'nominal','reference');
data.robustPlans = {robustData};
end

function runConfig = robustDosePullingRunConfig(runConfig)
runConfig.dose_pulling_strategy = 'Threshold';
runConfig.dose_pulling_max_iter = 1;
runConfig.dose_pulling2_start = 0;
runConfig.dose_pulling2_limit = 0;
runConfig.dose_pulling2_criteria = 'meanQiTarget';
end

function value = runMeasuredTask(varargin)
task = varargin{end};
value = task();
end

function cleanup = installFluenceOptimizationDijProbe(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
stubFile = fullfile(fixture.Folder,'matRad_fluenceOptimization.m');
fid = fopen(stubFile,'w');
fprintf(fid,[ ...
    'function resultGUI = matRad_fluenceOptimization(dij,~,~,varargin)\n' ...
    'if isstruct(dij) && isfield(dij,''totalNumOfBixels'')\n' ...
    '    bixels = dij.totalNumOfBixels;\n' ...
    'else\n' ...
    '    bixels = -1;\n' ...
    'end\n' ...
    'resultGUI = struct(''w'',bixels);\n' ...
    'end\n']);
fclose(fid);
addpath(fixture.Folder,'-begin');
clear matRad_fluenceOptimization;
cleanup = onCleanup(@() cleanupFluenceOptimizationDijProbe( ...
    fixture.Folder));
end

function cleanupFluenceOptimizationDijProbe(folder)
pathEntries = strsplit(path,pathsep);
if any(strcmp(pathEntries,folder))
    rmpath(folder);
end
clear matRad_fluenceOptimization;
end

function ensureFolder(folderPath)
if ~isfolder(folderPath)
    mkdir(folderPath);
end
end

function planId = planIdForMode(mode)
planId = lower(regexprep(char(mode),'[^A-Za-z0-9]+',''));
end

function dij_interval = intervalDij(mode)
dij_interval = struct();
dij_interval.center = sparse(1,3);
dij_interval.radius = sparse(1,3);
dij_interval.quantity = 'physicalDose';
dij_interval.quantityField = 'physicalDose';
if strcmp(char(mode),'INTERVAL3')
    dij_interval.OARSubIx = [];
    dij_interval.OARRadiusFactor = [];
    dij_interval.OARRadiusRank = [];
end
end

function dij_prob = probDij()
dij_prob = struct();
dij_prob.expected = sparse(1,3);
dij_prob.Omega = sparse(3,3);
dij_prob.voiSubIx = [];
dij_prob.quantity = 'physicalDose';
dij_prob.quantityField = 'physicalDose';
dij_prob.probabilisticMode = 'PROB';
end

function dijContext = derivedDijContext(scenarioModel)
dijContext = struct();
dijContext.totalNumOfBixels = 3;
dijContext.physicalDose = {sparse(1,3)};
if nargin >= 1 && ~isempty(scenarioModel)
    dijContext.scenarioModel = scenarioModel;
end
end
