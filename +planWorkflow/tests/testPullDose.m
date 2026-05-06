function tests = testPullDose
tests = functiontests(localfunctions);
end

function testStandardObjectivesWithoutDosePullingAreIgnored(testCase)
cst = makeCst(struct('parameters',{{10}},'penalty',1));

[updatedCst,flag] = planWorkflow.structures.pullDose(cst,1);

verifyFalse(testCase,flag);
verifyEqual(testCase,updatedCst,cst);
end

function testPartialDosePullingConfigIsIgnored(testCase)
objective = struct('parameters',{{10}},'penalty',1,'dosePulling',true);
cst = makeCst(objective);

[updatedCst,flag] = planWorkflow.structures.pullDose(cst,1);

verifyFalse(testCase,flag);
verifyEqual(testCase,updatedCst,cst);
end

function testDosePullingFlagRejectsInvalidText(testCase)
runConfig = struct('dose_pulling1','enabled');

verifyError(testCase,@() ...
    planWorkflow.config.DosePullingConfig.isChannelEnabled( ...
    runConfig,'dose_pulling_1'), ...
    'planWorkflow:config:DosePullingConfig:InvalidChannelFlag');
end

function testDosePullingFlagAcceptsExplicitFalseText(testCase)
runConfig = struct('dose_pulling1','off');

verifyFalse(testCase, ...
    planWorkflow.config.DosePullingConfig.isChannelEnabled( ...
    runConfig,'dose_pulling_1'));
end

function testNegativeIncrementsSaturateAtZero(testCase)
objective = struct( ...
    'parameters',{{0.5,5}}, ...
    'penalty',1, ...
    'dosePulling',true, ...
    'pullingStep',1, ...
    'objectivePullingRate',{{-1}}, ...
    'penaltyPullingRate',-2);
cst = makeCst(objective);

[updatedCst,flag] = planWorkflow.structures.pullDose(cst,1);
updatedObjective = updatedCst{1,6}{1};

verifyTrue(testCase,flag);
verifyEqual(testCase,updatedObjective.parameters,{0,5});
verifyEqual(testCase,updatedObjective.penalty,0);
end

function testUnchangedSaturatedObjectiveDoesNotSetFlag(testCase)
objective = struct( ...
    'parameters',{{0}}, ...
    'penalty',0, ...
    'dosePulling',true, ...
    'pullingStep',1, ...
    'objectivePullingRate',{{-1}}, ...
    'penaltyPullingRate',-2);
cst = makeCst(objective);

[updatedCst,flag] = planWorkflow.structures.pullDose(cst,1);

verifyFalse(testCase,flag);
verifyEqual(testCase,updatedCst,cst);
end

function testRepeatedCallsAccumulate(testCase)
objective = struct( ...
    'parameters',{{10}}, ...
    'penalty',1, ...
    'dosePulling',true, ...
    'pullingStep',2, ...
    'objectivePullingRate',{{2}}, ...
    'penaltyPullingRate',3);
cst = makeCst(objective);

[updatedCst,flag1] = planWorkflow.structures.pullDose(cst,2);
[updatedCst,flag2] = planWorkflow.structures.pullDose(updatedCst,2);
updatedObjective = updatedCst{1,6}{1};

verifyTrue(testCase,flag1);
verifyTrue(testCase,flag2);
verifyEqual(testCase,updatedObjective.parameters,{14});
verifyEqual(testCase,updatedObjective.penalty,7);
end

function cst = makeCst(objective)
cst = cell(1,6);
cst{1,4} = {1};
cst{1,6} = {objective};
end
