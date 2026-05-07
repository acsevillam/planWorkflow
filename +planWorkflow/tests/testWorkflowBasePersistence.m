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
verifyEqual(testCase,reporter.Events{end - 2}{1},'stageCompleted');
verifyEqual(testCase,reporter.Events{end - 2}{2},'analyze');
verifyEqual(testCase,reporter.Events{end - 1}{1},'showResults');
verifyEqual(testCase,reporter.Events{end}{1},'saveGuiSnapshot');
verifyEqual(testCase,reporter.SavedGuiFolder,workflow.rootPath);
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
