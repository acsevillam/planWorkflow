function tests = testEngineConfig
tests = functiontests(localfunctions);
end

function testUnsupportedRootAnalysisFieldIsRejected(testCase)
config = baseEngineConfig(testCase);
config.gammaCriteria = [3 3];

verifyError(testCase,@() planWorkflow.PhotonWorkflow(config), ...
    'planWorkflow:Engine:UnsupportedConfigField');
end

function testStrategyResolverUsesConcreteRobustnessNamespace(testCase)
config = baseEngineConfig(testCase);
config.robustness = 'COWC';
workflow = planWorkflow.PhotonWorkflow(config);

verifyClass(testCase,workflow.strategy,'planWorkflow.robustness.COWCStrategy');
verifyEqual(testCase,workflow.strategy.name,'COWC');
end

function testSamplingAliasesUpdateSamplingBasisOnly(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));
workflow.configureStagePublic('sample',struct( ...
    'scen_mode','impScen_permuted5_truncated', ...
    'wcSigma',2.5, ...
    'size',17));

verifyEqual(testCase,workflow.runConfig.scen_mode,'nomScen');
verifyEqual(testCase,workflow.runConfig.wcSigma,1);
verifyEqual(testCase,workflow.runConfig.sampling_scen_mode, ...
    'impScen_permuted5_truncated');
verifyEqual(testCase,workflow.runConfig.sampling_wcSigma,2.5);
verifyEqual(testCase,workflow.runConfig.sampling_size,17);
end

function testConflictingSamplingAliasesAreRejected(testCase)
workflow = planWorkflowTest.EngineProbe(baseEngineConfig(testCase));

verifyError(testCase, ...
    @() workflow.configureStagePublic('sample',struct( ...
    'wcSigma',1.0,'sampling_wcSigma',2.0)), ...
    'planWorkflow:Engine:ConflictingSamplingConfig');
end

function config = baseEngineConfig(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
config = struct();
config.radiationMode = 'photons';
config.workflowType = 'test';
config.description = 'synthetic';
config.caseID = 'case';
config.robustness = 'none';
config.scen_mode = 'nomScen';
config.wcSigma = 1;
config.runId = 'engine-config-test';
config.outputRootPath = fullfile(fixture.Folder,'output');
config.patientDataPath = fullfile(fixture.Folder,'patients');
config.cacheRootPath = fullfile(fixture.Folder,'cache');
end
