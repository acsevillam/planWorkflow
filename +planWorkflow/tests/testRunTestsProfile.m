function tests = testRunTestsProfile
tests = functiontests(localfunctions);
end

function testFastProfileExcludesRealTests(testCase)
suite = localPlanWorkflowSuite();
fastSuite = planWorkflow.testing.selectTestSuiteByProfile(suite,'fast');

verifyNotEmpty(testCase,fastSuite);
verifyFalse(testCase,any(isRealTestSuiteEntry(fastSuite)));
end

function testRealProfileIncludesOnlyRealTests(testCase)
suite = localPlanWorkflowSuite();
realSuite = planWorkflow.testing.selectTestSuiteByProfile(suite,'real');

verifyNotEmpty(testCase,realSuite);
verifyTrue(testCase,all(isRealTestSuiteEntry(realSuite)));
end

function testFullProfileKeepsAllTests(testCase)
suite = localPlanWorkflowSuite();
fullSuite = planWorkflow.testing.selectTestSuiteByProfile(suite,'full');

verifyEqual(testCase,numel(fullSuite),numel(suite));
end

function suite = localPlanWorkflowSuite()
testFolder = fileparts(mfilename('fullpath'));
suite = matlab.unittest.TestSuite.fromFolder(testFolder);
end

function mask = isRealTestSuiteEntry(suite)
testNames = string({suite.Name});
testFiles = regexprep(testNames,'/.*$','');
mask = endsWith(testFiles,'Real');
end
