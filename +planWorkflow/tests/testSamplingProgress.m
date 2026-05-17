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
