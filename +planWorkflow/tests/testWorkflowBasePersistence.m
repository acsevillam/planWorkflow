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

verifyEqual(testCase, ...
    rehydrated.optimizationInput.dij.totalNumOfBixels, ...
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
cst = {1};
stf = struct('totalNumOfBixels',3);
pln = struct('propStf',struct('numOfBeams',1));
dij = referenceDij();
planConfig = struct('id','planA');
cacheContext = planWorkflow.cache.DoseInfluenceCache.context(cst,stf);
cacheFile = planWorkflow.cache.DoseInfluenceCache.cacheFile( ...
    cachePath,runConfig,'robust_planA',pln,cacheContext);
mkdir(fileparts(cacheFile));
cacheMetadata = planWorkflow.cache.DoseInfluenceCache.metadata( ...
    runConfig,'robust_planA',pln,cacheContext);
builtin('save',cacheFile,'dij','cacheMetadata','-v7.3');

robustData = struct();
robustData.ct = ct;
robustData.cst = cst;
robustData.stf = stf;
robustData.pln = pln;
robustData.planConfig = planConfig;
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
verifyEqual(testCase, ...
    rehydrated.optimizationInput.dij.totalNumOfBixels, ...
    dij.totalNumOfBixels);
verifyEqual(testCase,rehydrated.optimizationInput.dijKind,'scenario');
end

function testWorkflowDataArtifactResumeFailsWhenDijCacheMissing(testCase)
[compactData,dataMetadata,runConfig,cachePath,cacheFile] = ...
    referenceDijArtifact(testCase);
delete(cacheFile);

verifyError(testCase,@() ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath), ...
    ['planWorkflow:persistence:WorkflowDataArtifact:' ...
    'MissingDijCache']);
end

function testWorkflowDataArtifactResumeFailsWhenDijCacheIdentityChanges( ...
        testCase)
[compactData,dataMetadata,runConfig,cachePath] = ...
    referenceDijArtifact(testCase);
compactData.optimizationInput.pln.propStf.numOfBeams = 2;

verifyError(testCase,@() ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath), ...
    ['planWorkflow:persistence:WorkflowDataArtifact:' ...
    'IncompatibleDijCacheOnResume']);
end

function testWorkflowDataArtifactResumeFailsWhenDijBixelsMismatch(testCase)
[compactData,dataMetadata,runConfig,cachePath] = ...
    referenceDijArtifact(testCase);
compactData.optimizationInput.dijRef.totalNumOfBixels = 4;

verifyError(testCase,@() ...
    planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
    compactData,dataMetadata,runConfig,cachePath), ...
    ['planWorkflow:persistence:WorkflowDataArtifact:' ...
    'DijRefBixelMismatch']);
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
plan.requiresProb2Dij = false;
plan.scenario = planWorkflow.config.RobustPlanConfig.defaultScenario( ...
    'wcScen');
plan.variants = planWorkflow.config.RobustPlanConfig.defaultVariants( ...
    'COWC');
config.precompute.robustPlans = plan;
end

function [compactData,dataMetadata,runConfig,cachePath,cacheFile,dij] = ...
        referenceDijArtifact(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
runConfig = planWorkflowTest.SyntheticWorkflow( ...
    baseSyntheticConfig(testCase)).runConfig;
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

data = struct();
data.ct = ct;
data.cst = cst;
data.stf = stf;
data.pln = pln;
data.optimizationInput = planWorkflow.precompute.OptimizationInput.build( ...
    ct,cst,pln,stf,dij,'nominal','reference');

[compactData,workflowDataMetadata] = ...
    planWorkflow.persistence.WorkflowDataArtifact.compactForSave( ...
    data,runConfig,cachePath);
dataMetadata = struct('workflowData',workflowDataMetadata);
end

function dij = referenceDij()
dij = struct();
dij.totalNumOfBixels = 3;
dij.physicalDose = {sparse(1,3)};
end
