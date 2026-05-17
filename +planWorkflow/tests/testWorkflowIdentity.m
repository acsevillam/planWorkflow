function tests = testWorkflowIdentity
tests = functiontests(localfunctions);
end

function testIntervalVariantParametersAffectIdentity(testCase)
configA = workflowConfigWithPlan(interval3Plan(10,0.5,10));
configB = workflowConfigWithPlan(interval3Plan(20,0.5,10));

identityA = planWorkflow.results.WorkflowIdentity.fromRunConfig(configA);
identityB = planWorkflow.results.WorkflowIdentity.fromRunConfig(configB);

verifyNotEqual(testCase,identityA.hash,identityB.hash);
verifyEqual(testCase, ...
    identityA.robustPlans(1).variants(1).parameters.theta1,10);
verifyEqual(testCase, ...
    identityB.robustPlans(1).variants(1).parameters.theta1,20);
end

function testSinglePlanPathUsesFullRobustIdentity(testCase)
configA = workflowConfigWithPlan(interval3Plan(10,0.5,10));
configB = workflowConfigWithPlan(interval3Plan(20,0.5,10));

identityA = planWorkflow.results.WorkflowIdentity.fromRunConfig(configA);
identityB = planWorkflow.results.WorkflowIdentity.fromRunConfig(configB);

verifyNotEqual(testCase,identityA.robustPathLabel, ...
    identityB.robustPathLabel);
verifyNotEqual(testCase,identityA.robustScenarioPathLabel, ...
    identityB.robustScenarioPathLabel);
verifyNotEqual(testCase,identityA.robustShiftLabel, ...
    identityB.robustShiftLabel);
verifyTrue(testCase,contains(identityA.robustPathLabel,identityA.hash));
verifyTrue(testCase,contains(identityB.robustPathLabel,identityB.hash));
end

function testCowcVariantParametersAffectIdentity(testCase)
configA = workflowConfigWithPlan(cowcPlan(0.25,0.75));
configB = workflowConfigWithPlan(cowcPlan(0.5,0.9));

identityA = planWorkflow.results.WorkflowIdentity.fromRunConfig(configA);
identityB = planWorkflow.results.WorkflowIdentity.fromRunConfig(configB);

verifyNotEqual(testCase,identityA.hash,identityB.hash);
verifyEqual(testCase, ...
    identityA.robustPlans(1).variants(1).parameters.p1,0.25);
verifyEqual(testCase, ...
    identityB.robustPlans(1).variants(1).parameters.p2,0.9);
end

function testRobustnessOptionsAffectIdentity(testCase)
configA = workflowConfigWithPlan(interval3Plan(10,0.5,10));
configB = workflowConfigWithPlan(interval3Plan(10,0.5,20));

identityA = planWorkflow.results.WorkflowIdentity.fromRunConfig(configA);
identityB = planWorkflow.results.WorkflowIdentity.fromRunConfig(configB);

verifyNotEqual(testCase,identityA.hash,identityB.hash);
verifyEqual(testCase,identityA.robustPlans(1).robustnessOptions.kmax,10);
verifyEqual(testCase,identityB.robustPlans(1).robustnessOptions.kmax,20);
end

function testFieldOrderDoesNotAffectIdentity(testCase)
planA = interval3Plan(10,0.5,10);
planB = planA;
planB.robustnessOptions = struct( ...
    'retentionThreshold',1.0, ...
    'radiusMode','std', ...
    'KMode','dynamic', ...
    'kmax',10);

identityA = planWorkflow.results.WorkflowIdentity.fromRunConfig( ...
    workflowConfigWithPlan(planA));
identityB = planWorkflow.results.WorkflowIdentity.fromRunConfig( ...
    workflowConfigWithPlan(planB));

verifyEqual(testCase,identityA.hash,identityB.hash);
end

function config = workflowConfigWithPlan(plan)
precompute = planWorkflow.config.RobustPlanConfig.defaults();
precompute.robustPlans = plan;
precompute = planWorkflow.config.RobustPlanConfig.normalizePrecompute( ...
    precompute,contract(plan.robustnessMode));
config = struct('precompute',precompute);
end

function plan = interval3Plan(theta1,theta2,kmax)
plan = basePlan('intervalPlan','INTERVAL3');
plan.robustnessOptions = struct( ...
    'radiusMode','std', ...
    'KMode','dynamic', ...
    'kmax',kmax, ...
    'retentionThreshold',1.0);
plan.variants = struct( ...
    'id','theta_pair', ...
    'label','Theta pair', ...
    'theta1',theta1, ...
    'theta2',theta2);
end

function plan = cowcPlan(p1,p2)
plan = basePlan('cowcPlan','c-COWC');
plan.variants = struct( ...
    'id','bounds', ...
    'label','Bounds', ...
    'p1',p1, ...
    'p2',p2);
end

function plan = basePlan(id,robustnessMode)
plan = struct();
plan.id = id;
plan.label = id;
plan.objectiveSetName = 'robust_1';
plan.robustnessMode = robustnessMode;
plan.scenario = planWorkflow.config.RobustPlanConfig.defaultScenario( ...
    'wcScen');
end

function value = contract(robustnessMode)
value = planWorkflow.config.RobustPlanConfig.defaultRobustnessContract();
value.robustnessMode = robustnessMode;
value.hasNominalObjectives = false;
value.requiresNominalDij = strcmp(robustnessMode,'none');
value.requiresScenarioDij = any(strcmp(robustnessMode, ...
    {'STOCH','COWC','c-COWC'}));
value.requiresIntervalDij = any(strcmp(robustnessMode, ...
    {'INTERVAL2','INTERVAL3'}));
value.requiresProbDij = strcmp(robustnessMode,'PROB2');
end
