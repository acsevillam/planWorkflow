function tests = testEngineConfig
tests = functiontests(localfunctions);
end

function testUnsupportedRootAnalysisFieldIsRejected(testCase)
config = baseEngineConfig(testCase);
config.gammaCriteria = [3 3];

verifyError(testCase,@() robOpt.PhotonWorkflow(config), ...
    'robOpt:Engine:UnsupportedConfigField');
end

function testStrategyResolverUsesConcreteRobustnessNamespace(testCase)
config = baseEngineConfig(testCase);
config.robustness = 'COWC';
workflow = robOpt.PhotonWorkflow(config);

verifyClass(testCase,workflow.strategy,'robOpt.robustness.COWCStrategy');
verifyEqual(testCase,workflow.strategy.name,'COWC');
end

function testSamplingAliasesUpdateSamplingBasisOnly(testCase)
workflow = robOptTest.EngineProbe(baseEngineConfig(testCase));
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
workflow = robOptTest.EngineProbe(baseEngineConfig(testCase));

verifyError(testCase, ...
    @() workflow.configureStagePublic('sample',struct( ...
    'wcSigma',1.0,'sampling_wcSigma',2.0)), ...
    'robOpt:Engine:ConflictingSamplingConfig');
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
