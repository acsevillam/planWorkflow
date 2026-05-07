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
end

function testDerivesScenarioRobustnessNeeds(testCase)
objectiveSet = objectiveSetWith({'COWC','none'});

contract = planWorkflow.templates.ObjectiveRobustnessContract.forObjectiveSet( ...
    objectiveSet);

verifyEqual(testCase,contract.robustnessMode,'COWC');
verifyTrue(testCase,contract.requiresNominalDij);
verifyTrue(testCase,contract.requiresScenarioDij);
verifyFalse(testCase,contract.requiresIntervalDij);
end

function testRejectsMultipleNonNoneModes(testCase)
objectiveSet = objectiveSetWith({'COWC','INTERVAL3'});

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
