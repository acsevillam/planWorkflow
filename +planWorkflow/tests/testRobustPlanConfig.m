function tests = testRobustPlanConfig
tests = functiontests(localfunctions);
end

function testNormalizeCanonicalRobustPlans(testCase)
plan = struct();
plan.id = 'interval3_a';
plan.label = 'INTERVAL3 theta sweep';
plan.objectiveSetName = 'robust_1';
plan.strategy = 'INTERVAL3';
plan.scenario = struct('mode','wcScen','ctActive',true, ...
    'setupActive',true,'rangeActive',false,'gantryActive',false, ...
    'couchActive',false,'shiftSD',[5 10 5],'wcSigma',1.0);
plan.strategyOptions = struct('KMode','dynamic','kmax',10, ...
    'retentionThreshold',1.0);
plan.variants = [ ...
    struct('id','theta_5','label','theta1=5','theta1',5, ...
    'theta2',0.5) ...
    struct('id','theta_10','label','theta1=10','theta1',10, ...
    'theta2',0.5)];

precompute = planWorkflow.config.RobustPlanConfig.normalizePrecompute( ...
    struct('robustPlans',plan));

verifyEqual(testCase,numel(precompute.robustPlans),1);
verifyEqual(testCase,precompute.robustPlans(1).strategy,'INTERVAL3');
verifyEqual(testCase,precompute.robustPlans(1).scenario.mode,'wcScen');
verifyEqual(testCase,precompute.robustPlans(1).strategyOptions.kmax,10);
verifyEqual(testCase,{precompute.robustPlans(1).variants.id}, ...
    {'theta_5','theta_10'});
verifyEqual(testCase,[precompute.robustPlans(1).variants.theta1], ...
    [5 10]);
end

function testDuplicateRobustPlanIdsAreRejected(testCase)
planA = cleanPlan('same_id','Plan A','COWC');
planB = cleanPlan('same_id','Plan B','COWC');

verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans([planA planB]), ...
    'planWorkflow:config:RobustPlanConfig:DuplicateRobustPlanId');
end

function testStrategyOptionsArePlanLevel(testCase)
plan = cleanPlan('interval3','INTERVAL3','INTERVAL3');
plan.strategyOptions.KMode = 'static';
plan.strategyOptions.kmax = 3;
plan.variants = [ ...
    struct('id','v1','label','V1','theta1',1,'theta2',0.1) ...
    struct('id','v2','label','V2','theta1',2,'theta2',0.2)];

plans = planWorkflow.config.RobustPlanConfig.normalizePlans(plan);

verifyEqual(testCase,plans.strategyOptions.KMode,'static');
verifyEqual(testCase,plans.strategyOptions.kmax,3);
verifyFalse(testCase,isfield(plans.variants,'KMode'));
end

function testInterval2DoesNotDefaultStrategyOptions(testCase)
plan = cleanPlan('interval2','INTERVAL2','INTERVAL2');
plan.variants = struct('id','theta_5','label','theta1=5', ...
    'theta1',5);

plans = planWorkflow.config.RobustPlanConfig.normalizePlans(plan);

verifyEmpty(testCase,fieldnames(plans.strategyOptions));
verifyEqual(testCase,{plans.variants.id},{'theta_5'});
verifyEqual(testCase,[plans.variants.theta1],5);
end

function testOptimization4DIsDerivedFromCtActive(testCase)
plan = cleanPlan('interval2','INTERVAL2','INTERVAL2');

plans = planWorkflow.config.RobustPlanConfig.normalizePlans(plan);

verifyTrue(testCase,plans.optimization4D.enabled);
verifyEqual(testCase,plans.optimization4D.scen4D,'all');

plan.scenario.ctActive = false;
plan.optimization4D = struct('enabled',true,'scen4D',[1 3]);
plans = planWorkflow.config.RobustPlanConfig.normalizePlans(plan);

verifyFalse(testCase,plans.optimization4D.enabled);
verifyEqual(testCase,plans.optimization4D.scen4D,'all');

reference = planWorkflow.config.RobustPlanConfig.normalizeReference( ...
    struct());

verifyFalse(testCase,reference.optimization4D.enabled);
verifyEqual(testCase,reference.optimization4D.scen4D,'all');

reference = planWorkflow.config.RobustPlanConfig.defaultReference();
reference.scenario.ctActive = true;
reference.optimization4D = struct('enabled',false,'scen4D',[2 4]);
reference = planWorkflow.config.RobustPlanConfig.normalizeReference( ...
    reference);

verifyTrue(testCase,reference.optimization4D.enabled);
verifyEqual(testCase,reference.optimization4D.scen4D,'all');
end

function testVariantParametersAreStrategyScoped(testCase)
interval2 = cleanPlan('interval2','INTERVAL2','INTERVAL2');
interval2.variants = struct('id','theta_bad','label','bad', ...
    'theta1',5,'theta2',1);
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(interval2), ...
    'planWorkflow:config:RobustPlanConfig:UnsupportedField');

interval3 = cleanPlan('interval3','INTERVAL3','INTERVAL3');
interval3.variants = struct('id','theta_bad','label','bad', ...
    'theta1',5);
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(interval3), ...
    'planWorkflow:config:RobustPlanConfig:MissingVariantParameter');

cheapCowc = cleanPlan('cheap_cowc','c-COWC','c-COWC');
cheapCowc.variants = struct('id','p_bad','label','bad', ...
    'p1',1,'p2',2,'theta1',5);
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(cheapCowc), ...
    'planWorkflow:config:RobustPlanConfig:UnsupportedField');

interval3.variants = struct('id','theta_bad','label','bad', ...
    'theta1',5,'theta2',1,'p1',1);
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(interval3), ...
    'planWorkflow:config:RobustPlanConfig:UnsupportedField');

cheapCowc.variants = struct('id','p_bad','label','bad','p1',1);
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(cheapCowc), ...
    'planWorkflow:config:RobustPlanConfig:MissingVariantParameter');

cheapCowc.variants = struct('id','p_bad','label','bad', ...
    'p1',1,'p2',2,'notAParameter',5);
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(cheapCowc), ...
    'planWorkflow:config:RobustPlanConfig:UnsupportedField');
end

function testVariantParametersMustBeFiniteNumericScalars(testCase)
interval2 = cleanPlan('interval2','INTERVAL2','INTERVAL2');
interval2.variants = struct('id','theta_bad','label','bad', ...
    'theta1',[1 2]);
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(interval2), ...
    'planWorkflow:config:RobustPlanConfig:InvalidNumericScalar');

cheapCowc = cleanPlan('cheap_cowc','c-COWC','c-COWC');
cheapCowc.variants = struct('id','p_bad','label','bad', ...
    'p1',NaN,'p2',2);
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(cheapCowc), ...
    'planWorkflow:config:RobustPlanConfig:InvalidNumericScalar');
end

function testStrategyOptionsAreStrategyScopedAndValidated(testCase)
interval2 = cleanPlan('interval2','INTERVAL2','INTERVAL2');
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.defaultStrategyOptions(), ...
    'planWorkflow:config:RobustPlanConfig:MissingStrategy');
verifyError(testCase,@() ...
    planWorkflow.config.RobustStrategySpec.defaultStrategyOptions(), ...
    'planWorkflow:config:RobustStrategySpec:MissingStrategy');
interval2.strategyOptions = ...
    planWorkflow.config.RobustPlanConfig.defaultStrategyOptions( ...
    'INTERVAL3');
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(interval2), ...
    'planWorkflow:config:RobustPlanConfig:UnsupportedField');

interval2.strategyOptions = struct('notAnOption',1);
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(interval2), ...
    'planWorkflow:config:RobustPlanConfig:UnsupportedField');

interval3 = cleanPlan('interval3','INTERVAL3','INTERVAL3');
interval3.strategyOptions.KMode = 'other';
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(interval3), ...
    'planWorkflow:config:RobustPlanConfig:InvalidStrategyOption');

interval3.strategyOptions.KMode = 'dynamic';
interval3.strategyOptions.kmax = 1.5;
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(interval3), ...
    'planWorkflow:config:RobustPlanConfig:InvalidPositiveInteger');

interval3.strategyOptions.kmax = 10;
interval3.strategyOptions.retentionThreshold = -1;
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans(interval3), ...
    'planWorkflow:config:RobustPlanConfig:InvalidNumericScalar');
end

function plan = cleanPlan(id,label,strategy)
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = id;
plan.label = label;
plan.objectiveSetName = id;
plan.strategy = strategy;
plan.variants = planWorkflow.config.RobustPlanConfig.defaultVariants( ...
    strategy);
end
