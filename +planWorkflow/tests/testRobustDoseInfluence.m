function tests = testRobustDoseInfluence
tests = functiontests(localfunctions);
end

function testIntervalRobustDijIsTransient(testCase)
robustData = planData(true,false);
dij = struct('physicalDose',{{sparse(1,1),sparse(1,1)}});

robustData = planWorkflow.precompute.RobustDoseInfluence.attach( ...
    robustData,dij);

verifyTrue(testCase,isfield(robustData,'dij'));
verifyFalse(testCase,isfield(robustData,'dijRobust'));
verifyEqual(testCase,robustData.dij,dij);
end

function testScenarioRobustDijIsNamedForReuse(testCase)
robustData = planData(false,true);
dij = struct('physicalDose',{{sparse(1,1),sparse(1,1)}});

robustData = planWorkflow.precompute.RobustDoseInfluence.attach( ...
    robustData,dij);

verifyTrue(testCase,isfield(robustData,'dij'));
verifyTrue(testCase,isfield(robustData,'dijRobust'));
verifyEqual(testCase,robustData.dijRobust,dij);
end

function robustData = planData(requiresIntervalDij,requiresScenarioDij)
robustData = struct();
robustData.planConfig = struct();
robustData.planConfig.requiresIntervalDij = requiresIntervalDij;
robustData.planConfig.requiresScenarioDij = requiresScenarioDij;
end
