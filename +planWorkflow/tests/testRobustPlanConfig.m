function tests = testRobustPlanConfig
tests = functiontests(localfunctions);
end

function testNormalizeRobustPlanFromDerivedContract(testCase)
plan = cleanPlan('interval3_a','INTERVAL3 theta sweep');
plan.robustnessMode = 'INTERVAL3';
plan.scenario = struct('mode','wcScen','ctActive',true, ...
    'setupActive',true,'rangeActive',false,'gantryActive',false, ...
    'couchActive',false,'shiftSD',[5 10 5],'wcSigma',1.0);
plan.robustnessOptions = struct('radiusMode','std','KMode','dynamic', ...
    'kmax',10,'retentionThreshold',1.0);
plan.variants = [ ...
    struct('id','theta_5','label','theta1=5','theta1',5, ...
    'theta2',0.5) ...
    struct('id','theta_10','label','theta1=10','theta1',10, ...
    'theta2',0.5)];

precompute = planWorkflow.config.RobustPlanConfig.normalizePrecompute( ...
    struct('robustPlans',plan),contract('INTERVAL3',true));

verifyEqual(testCase,numel(precompute.robustPlans),1);
verifyFalse(testCase,isfield(precompute.robustPlans(1),'strategy'));
verifyEqual(testCase,precompute.robustPlans(1).robustnessMode,'INTERVAL3');
verifyTrue(testCase,precompute.robustPlans(1).hasNominalObjectives);
verifyTrue(testCase,precompute.robustPlans(1).requiresNominalDij);
verifyTrue(testCase,precompute.robustPlans(1).requiresIntervalDij);
verifyFalse(testCase,precompute.robustPlans(1).requiresProb2Dij);
verifyEqual(testCase,precompute.robustPlans(1).robustnessOptions.radiusMode, ...
    'std');
verifyEqual(testCase,precompute.robustPlans(1).robustnessOptions.kmax,10);
verifyEqual(testCase,{precompute.robustPlans(1).variants.id}, ...
    {'theta_5','theta_10'});
verifyEqual(testCase,[precompute.robustPlans(1).variants.theta1], ...
    [5 10]);
end

function testDerivedContractRetargetsInterval3OptionsToInterval2(testCase)
plan = cleanPlan('interval2_from_panel','Retarget INTERVAL2');
plan.robustnessMode = 'INTERVAL3';
plan.robustnessOptions = struct('radiusMode','std','KMode','dynamic', ...
    'kmax',7,'retentionThreshold',0.5);
plan.variants = struct('id','theta3','label','theta3', ...
    'theta1',10,'theta2',1);

plans = planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    plan,contract('INTERVAL2',true));

verifyEqual(testCase,plans.robustnessMode,'INTERVAL2');
verifyEqual(testCase,fieldnames(plans.robustnessOptions),{'radiusMode'});
verifyEqual(testCase,plans.robustnessOptions.radiusMode,'std');
verifyEqual(testCase,{plans.variants.id},{'variant_1'});
verifyTrue(testCase,isfield(plans.variants,'theta1'));
verifyFalse(testCase,isfield(plans.variants,'theta2'));
end

function testDerivedContractRetargetsInterval3OptionsToNone(testCase)
plan = cleanPlan('nominal_from_panel','Retarget none');
plan.robustnessMode = 'INTERVAL3';
plan.robustnessOptions = struct('radiusMode','std','KMode','dynamic', ...
    'kmax',7,'retentionThreshold',0.5);
plan.variants = struct('id','theta3','label','theta3', ...
    'theta1',10,'theta2',1);

plans = planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    plan,contract('none',true));

verifyEqual(testCase,plans.robustnessMode,'none');
verifyEmpty(testCase,fieldnames(plans.robustnessOptions));
verifyEqual(testCase,{plans.variants.id},{'variant_1'});
verifyFalse(testCase,isfield(plans.variants,'theta1'));
verifyFalse(testCase,isfield(plans.variants,'theta2'));
end

function testDerivedContractPreservesMatchingInterval3Options(testCase)
plan = cleanPlan('interval3','Preserve INTERVAL3');
plan.robustnessMode = 'INTERVAL3';
plan.robustnessOptions = struct('radiusMode','std','KMode','dynamic', ...
    'kmax',7,'retentionThreshold',0.5);
plan.variants = struct('id','theta3','label','theta3', ...
    'theta1',10,'theta2',1);

plans = planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    plan,contract('INTERVAL3',true));

verifyEqual(testCase,plans.robustnessMode,'INTERVAL3');
verifyEqual(testCase,plans.robustnessOptions.radiusMode,'std');
verifyEqual(testCase,plans.robustnessOptions.KMode,'dynamic');
verifyEqual(testCase,plans.robustnessOptions.kmax,7);
verifyEqual(testCase,plans.robustnessOptions.retentionThreshold,0.5);
verifyEqual(testCase,plans.variants.theta1,10);
verifyEqual(testCase,plans.variants.theta2,1);
end

function testStrategyFieldIsUnsupported(testCase)
plan = cleanPlan('interval3','INTERVAL3');
plan.strategy = 'INTERVAL3';

verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    plan,contract('INTERVAL3',false)), ...
    'planWorkflow:config:RobustPlanConfig:UnsupportedField');
end

function testDuplicateRobustPlanIdsAreRejected(testCase)
planA = cleanPlan('same_id','Plan A');
planB = cleanPlan('same_id','Plan B');

verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    [planA planB],[contract('COWC',false) contract('COWC',false)]), ...
    'planWorkflow:config:RobustPlanConfig:DuplicateRobustPlanId');
end

function testNoneContractDefaultsToNominalDij(testCase)
plan = cleanPlan('nominal','Nominal objectives');

plans = planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    plan,contract('none',true));

verifyEqual(testCase,plans.robustnessMode,'none');
verifyTrue(testCase,plans.requiresNominalDij);
verifyFalse(testCase,plans.requiresScenarioDij);
verifyFalse(testCase,plans.requiresIntervalDij);
verifyFalse(testCase,plans.requiresProb2Dij);
verifyEmpty(testCase,fieldnames(plans.robustnessOptions));
verifyEqual(testCase,{plans.variants.id},{'variant_1'});
verifyFalse(testCase,isfield(plans.variants,'theta1'));
end

function testVariantParametersAreRobustnessScoped(testCase)
interval2 = cleanPlan('interval2','INTERVAL2');
interval2.variants = struct('id','theta_bad','label','bad', ...
    'theta1',5,'theta2',1);
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    interval2,contract('INTERVAL2',false)), ...
    'planWorkflow:config:RobustPlanConfig:UnsupportedField');

interval3 = cleanPlan('interval3','INTERVAL3');
interval3.variants = struct('id','theta_bad','label','bad', ...
    'theta1',5);
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    interval3,contract('INTERVAL3',false)), ...
    'planWorkflow:config:RobustPlanConfig:MissingVariantParameter');

cheapCowc = cleanPlan('cheap_cowc','c-COWC');
cheapCowc.variants = struct('id','p_bad','label','bad', ...
    'p1',1,'p2',2,'theta1',5);
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    cheapCowc,contract('c-COWC',false)), ...
    'planWorkflow:config:RobustPlanConfig:UnsupportedField');
end

function testVariantParametersMustBeFiniteNumericScalars(testCase)
interval2 = cleanPlan('interval2','INTERVAL2');
interval2.variants = struct('id','theta_bad','label','bad', ...
    'theta1',[1 2]);
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    interval2,contract('INTERVAL2',false)), ...
    'planWorkflow:config:RobustPlanConfig:InvalidNumericScalar');

cheapCowc = cleanPlan('cheap_cowc','c-COWC');
cheapCowc.variants = struct('id','p_bad','label','bad', ...
    'p1',NaN,'p2',2);
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    cheapCowc,contract('c-COWC',false)), ...
    'planWorkflow:config:RobustPlanConfig:InvalidNumericScalar');
end

function testRobustnessOptionsAreModeScopedAndValidated(testCase)
interval2 = cleanPlan('interval2','INTERVAL2');
interval2.robustnessOptions = ...
    planWorkflow.config.RobustPlanConfig.defaultRobustnessOptions( ...
    'INTERVAL3');
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    interval2,contract('INTERVAL2',false)), ...
    'planWorkflow:config:RobustPlanConfig:UnsupportedField');

interval3 = cleanPlan('interval3','INTERVAL3');
interval3.robustnessOptions.radiusMode = 'other';
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    interval3,contract('INTERVAL3',false)), ...
    'planWorkflow:config:RobustPlanConfig:InvalidStrategyOption');

interval3.robustnessOptions.radiusMode = 'std';
interval3.robustnessOptions.KMode = 'other';
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    interval3,contract('INTERVAL3',false)), ...
    'planWorkflow:config:RobustPlanConfig:InvalidStrategyOption');

interval3.robustnessOptions.KMode = 'dynamic';
interval3.robustnessOptions.kmax = 1.5;
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    interval3,contract('INTERVAL3',false)), ...
    'planWorkflow:config:RobustPlanConfig:InvalidPositiveInteger');

interval3.robustnessOptions.kmax = 10;
interval3.robustnessOptions.retentionThreshold = -1;
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    interval3,contract('INTERVAL3',false)), ...
    'planWorkflow:config:RobustPlanConfig:InvalidNumericScalar');
end

function testProb2ContractUsesProb2DijOnly(testCase)
plan = cleanPlan('prob2','PROB2');

plans = planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    plan,contract('PROB2',false));

verifyEqual(testCase,plans.robustnessMode,'PROB2');
verifyFalse(testCase,plans.requiresNominalDij);
verifyFalse(testCase,plans.requiresScenarioDij);
verifyFalse(testCase,plans.requiresIntervalDij);
verifyTrue(testCase,plans.requiresProb2Dij);
verifyEmpty(testCase,fieldnames(plans.robustnessOptions));
verifyEqual(testCase,{plans.variants.id},{'variant_1'});
end

function plan = cleanPlan(id,label)
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = id;
plan.label = label;
plan.objectiveSetName = id;
end

function value = contract(robustnessMode,hasNominal)
value = planWorkflow.config.RobustPlanConfig.defaultRobustnessContract();
value.robustnessMode = robustnessMode;
value.hasNominalObjectives = logical(hasNominal);
value.requiresNominalDij = logical(hasNominal) || strcmp(robustnessMode,'none');
value.requiresScenarioDij = any(strcmp(robustnessMode, ...
    {'STOCH','COWC','c-COWC'}));
value.requiresIntervalDij = any(strcmp(robustnessMode, ...
    {'INTERVAL2','INTERVAL3'}));
value.requiresProb2Dij = strcmp(robustnessMode,'PROB2');
end
