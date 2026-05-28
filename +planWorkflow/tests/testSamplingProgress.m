function tests = testSamplingProgress
tests = functiontests(localfunctions);
end

function testLatestProgressParsesCanonicalSlashPattern(testCase)
messages = {'Using 50 samples in total ', ...
            'matRad: Sampling progress: 7/50 scenarios.'};

[finishedScenarios, totalScenarios] = ...
    planWorkflow.sampling.SamplingService.latestProgress(messages);

verifyEqual(testCase, finishedScenarios, 7);
verifyEqual(testCase, totalScenarios, 50);
end

function testLatestProgressIgnoresGenericDoseProgress(testCase)
messages = {'Using 50 samples in total ', ...
            'Progress: 0.05 % 1.60 % Beam 2 of 9:'};

[finishedScenarios, totalScenarios] = ...
    planWorkflow.sampling.SamplingService.latestProgress(messages);

verifyEmpty(testCase, finishedScenarios);
verifyEmpty(testCase, totalScenarios);
end

function testMatRadSamplingGuardDisablesInternalGuiAndRestores(testCase)
matRadCfg = MatRad_Config.instance();
restoreValue = matRadCfg.disableGUI;
cleanupObj = onCleanup(@() restoreDisableGui(matRadCfg,restoreValue)); %#ok<NASGU>
matRadCfg.disableGUI = false;

[seenDisableGui, textValue] = ...
    planWorkflow.sampling.SamplingService.withMatRadGuiDisabled( ...
    @() deal(matRadCfg.disableGUI,'sampled'));

verifyTrue(testCase, seenDisableGui);
verifyEqual(testCase, textValue, 'sampled');
verifyFalse(testCase, matRadCfg.disableGUI);
end

function testMatRadSamplingGuardRestoresInternalGuiAfterError(testCase)
matRadCfg = MatRad_Config.instance();
restoreValue = matRadCfg.disableGUI;
cleanupObj = onCleanup(@() restoreDisableGui(matRadCfg,restoreValue)); %#ok<NASGU>
matRadCfg.disableGUI = false;

verifyError(testCase, ...
    @() planWorkflow.sampling.SamplingService.withMatRadGuiDisabled( ...
    @throwExpectedError), ...
    'planWorkflow:test:ExpectedError');
verifyFalse(testCase, matRadCfg.disableGUI);
end

function throwExpectedError()
error('planWorkflow:test:ExpectedError','Expected test error.');
end

function restoreDisableGui(matRadCfg,value)
matRadCfg.disableGUI = value;
end
