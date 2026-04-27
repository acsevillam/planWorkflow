function tests = testWorkflowBasePersistence
tests = functiontests(localfunctions);
end

function testSyntheticWorkflowPersistsSplitArtifacts(testCase)
workflow = robOptTest.SyntheticWorkflow(baseSyntheticConfig(testCase));

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

performanceSnapshot = load(workflow.performanceFile,'computationalResources');
resources = performanceSnapshot.computationalResources;
verifyEqual(testCase,resources.wallTimeUnit,'seconds');
verifyEqual(testCase,resources.memoryUnit,'bytes');
verifyEqual(testCase, ...
    resources.stageTimings.prepare.lastStatus,'completed');
verifyGreaterThanOrEqual(testCase, ...
    resources.stageTimings.prepare.attempts,1);
end

function testResumeLoadsDataAndResultsArtifacts(testCase)
config = baseSyntheticConfig(testCase);
workflow = robOptTest.SyntheticWorkflow(config);
workflow.prepare();
workflow.precompute();
workflow.pullDose();
workflow.optimize();
workflow.sample();
workflow.analyze();
workflow.save();

resumed = robOptTest.SyntheticWorkflow(config);
resumed.resume(workflow.stateFile);

verifyEqual(testCase,resumed.data.preparedValue,42);
verifyEqual(testCase,resumed.data.results.score,47);
verifyEqual(testCase,resumed.state.currentStage,'analyzed');
verifyTrue(testCase,any(strcmp(resumed.state.completedStages,'analyzed')));
end

function testReleaseMemoryClearsOnlyInMemoryData(testCase)
workflow = robOptTest.SyntheticWorkflow(baseSyntheticConfig(testCase));
workflow.prepare();
verifyTrue(testCase,isfield(workflow.data,'preparedValue'));

workflow.releaseMemory();

verifyEqual(testCase,fieldnames(workflow.data),cell(0,1));
verifyTrue(testCase,isfile(workflow.stateFile));
end

function config = baseSyntheticConfig(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
config = struct();
config.outputRootPath = fullfile(fixture.Folder,'output');
config.cacheRootPath = fullfile(fixture.Folder,'cache');
config.runId = 'synthetic-workflow-test';
end
