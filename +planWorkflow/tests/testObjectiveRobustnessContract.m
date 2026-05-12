function tests = testObjectiveRobustnessContract
tests = functiontests(localfunctions);
end

function testDerivesNominalAndIntervalNeeds(testCase)
objectiveSet = objectiveSetWith({'none','INTERVAL3','INTERVAL3'});

contract = planWorkflow.templates.ObjectiveRobustnessContract.forObjectiveSet( ...
    objectiveSet);

verifyTrue(testCase,contract.hasNominalObjectives);
verifyEqual(testCase,contract.robustnessMode,'INTERVAL3');
verifyTrue(testCase,contract.requiresNominalDij);
verifyFalse(testCase,contract.requiresScenarioDij);
verifyTrue(testCase,contract.requiresIntervalDij);
verifyFalse(testCase,contract.requiresProb2Dij);
end

function testDerivesScenarioRobustnessNeeds(testCase)
objectiveSet = objectiveSetWith({'COWC','none'});

contract = planWorkflow.templates.ObjectiveRobustnessContract.forObjectiveSet( ...
    objectiveSet);

verifyEqual(testCase,contract.robustnessMode,'COWC');
verifyTrue(testCase,contract.hasNominalObjectives);
verifyFalse(testCase,contract.requiresNominalDij);
verifyTrue(testCase,contract.requiresScenarioDij);
verifyFalse(testCase,contract.requiresIntervalDij);
verifyFalse(testCase,contract.requiresProb2Dij);
end

function testDerivesProb2Needs(testCase)
objectiveSet = objectiveSetWith({'none','PROB2'});

contract = planWorkflow.templates.ObjectiveRobustnessContract.forObjectiveSet( ...
    objectiveSet);

verifyEqual(testCase,contract.robustnessMode,'PROB2');
verifyTrue(testCase,contract.requiresNominalDij);
verifyFalse(testCase,contract.requiresScenarioDij);
verifyFalse(testCase,contract.requiresIntervalDij);
verifyTrue(testCase,contract.requiresProb2Dij);
end

function testInterval2AndInterval3SelectInterval3(testCase)
objectiveSet = objectiveSetWith({'INTERVAL2','INTERVAL3'});

contract = planWorkflow.templates.ObjectiveRobustnessContract.forObjectiveSet( ...
    objectiveSet);

verifyEqual(testCase,contract.robustnessMode,'INTERVAL3');
verifyTrue(testCase,contract.requiresIntervalDij);
verifyFalse(testCase,contract.requiresProb2Dij);
end

function testRejectsMultipleNonNoneModes(testCase)
objectiveSet = objectiveSetWith({'COWC','INTERVAL3'});

verifyError(testCase,@() ...
    planWorkflow.templates.ObjectiveRobustnessContract.forObjectiveSet( ...
    objectiveSet), ...
    ['planWorkflow:templates:ObjectiveRobustnessContract:' ...
    'MultipleRobustnessModes']);
end

function testRejectsProb2AndIntervalInSameObjectiveSet(testCase)
objectiveSet = objectiveSetWith({'PROB2','INTERVAL3'});

verifyError(testCase,@() ...
    planWorkflow.templates.ObjectiveRobustnessContract.forObjectiveSet( ...
    objectiveSet), ...
    ['planWorkflow:templates:ObjectiveRobustnessContract:' ...
    'MultipleRobustnessModes']);
end

function objectiveSet = objectiveSetWith(robustnessValues)
objectives = repmat(struct('enabled',true,'properties',struct()), ...
    1,numel(robustnessValues));
for i = 1:numel(robustnessValues)
    objectives(i).properties.robustness = robustnessValues{i};
end
objectiveSet = struct('id','robust_1','label','Robust 1', ...
    'structureObjectives',struct('name','CTV','objectives',objectives), ...
    'ringObjectives',[]);
end
