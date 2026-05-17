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
verifyFalse(testCase,precompute.robustPlans(1).requiresProbDij);
verifyEqual(testCase,precompute.robustPlans(1).robustnessOptions.radiusMode, ...
    'std');
verifyEqual(testCase,precompute.robustPlans(1).robustnessOptions.kmax,10);
verifyEqual(testCase,{precompute.robustPlans(1).variants.id}, ...
    {'theta_5','theta_10'});
verifyEqual(testCase,[precompute.robustPlans(1).variants.theta1], ...
    [5 10]);
end

function testRobustPlanPanelSummarizesPenaltyVariants(testCase)
plan = cleanPlan('interval2','INTERVAL2 penalty sweep');
plan.robustnessMode = 'INTERVAL2';
plan.variants = [ ...
    struct('id','theta_5','label','theta1=5','theta1',5) ...
    struct('id','theta_10','label','theta1=10','theta1',10)];
plan = planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    plan,contract('INTERVAL2',true));
plan.variantsWithPenalties = [ ...
    penaltyVariant(plan.variants(1),1,1,10) ...
    penaltyVariant(plan.variants(1),1,2,30) ...
    penaltyVariant(plan.variants(2),2,1,10) ...
    penaltyVariant(plan.variants(2),2,2,30)];

panelConfig = planWorkflow.config.RobustPlanPanelAdapter.planPanelConfig( ...
    plan);
visibleFields = ...
    planWorkflow.config.WorkflowParameterSchema.precomputeRobustVisibleFields( ...
    'INTERVAL2','wcScen');

verifyEqual(testCase,panelConfig.variantSummary, ...
    'Robust variants: 2 | Penalty combinations: 2 | Total variants: 4');
verifyTrue(testCase,any(strcmp(visibleFields,'variantSummary')));
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
verifyFalse(testCase,plans.requiresProbDij);
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

function testProb2ContractUsesProbDijOnly(testCase)
plan = cleanPlan('prob','PROB2');

plans = planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    plan,contract('PROB2',false));

verifyEqual(testCase,plans.robustnessMode,'PROB2');
verifyFalse(testCase,plans.requiresNominalDij);
verifyFalse(testCase,plans.requiresScenarioDij);
verifyFalse(testCase,plans.requiresIntervalDij);
verifyTrue(testCase,plans.requiresProbDij);
verifyEmpty(testCase,fieldnames(plans.robustnessOptions));
verifyEqual(testCase,{plans.variants.id},{'variant_1'});
end

function testScenarioContractWithNominalObjectivesDoesNotRequireNominalDij(testCase)
plan = cleanPlan('cowc','COWC');

plans = planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    plan,contract('COWC',true));

verifyTrue(testCase,plans.hasNominalObjectives);
verifyFalse(testCase,plans.requiresNominalDij);
verifyTrue(testCase,plans.requiresScenarioDij);
verifyFalse(testCase,plans.requiresIntervalDij);
verifyFalse(testCase,plans.requiresProbDij);
end

function testDosePrecomputeDefaultsAndNormalization(testCase)
cacheRoot = fullfile(tempdir,'planWorkflow_interval_cache');
plan = cleanPlan('interval3','INTERVAL3');
plan.dosePrecompute = struct('useScenarioBatch','true', ...
    'SecondPassStrategy','RECOMPUTE','KeepCache','on', ...
    'CacheRoot',['  ' cacheRoot '  ']);

plans = planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    plan,contract('INTERVAL3',false));

verifyTrue(testCase,plans.dosePrecompute.useScenarioBatch);
verifyEqual(testCase,plans.dosePrecompute.SecondPassStrategy,'recompute');
verifyTrue(testCase,plans.dosePrecompute.KeepCache);
verifyEqual(testCase,plans.dosePrecompute.CacheRoot,cacheRoot);
end

function testDosePrecomputeRejectsInvalidStrategy(testCase)
plan = cleanPlan('interval3','INTERVAL3');
plan.dosePrecompute.SecondPassStrategy = 'memory';

verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    plan,contract('INTERVAL3',false)), ...
    ['planWorkflow:config:RobustPlanConfig:' ...
    'InvalidDosePrecomputeStrategy']);
end

function testMixedCompactPrecomputeModesAreRejected(testCase)
plan = cleanPlan('bad','Mixed');
badContract = contract('PROB2',false);
badContract.requiresIntervalDij = true;
badContract.requiresProbDij = true;

verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
    plan,badContract), ...
    ['planWorkflow:config:RobustPlanConfig:' ...
    'MixedCompactPrecomputeModes']);
end

function testApplyRobustnessContractIsPublicAndModeScoped(testCase)
modes = {'none','COWC','PROB2','INTERVAL2'};
hasNominalObjectives = [true true false true];

for modeIx = 1:numel(modes)
    mode = modes{modeIx};
    plan = cleanPlan(lower(mode),mode);
    value = contract(mode,hasNominalObjectives(modeIx));

    plan = planWorkflow.config.RobustPlanConfig.applyRobustnessContract( ...
        plan,value);

    verifyEqual(testCase,plan.robustnessMode,value.robustnessMode);
    verifyEqual(testCase,plan.hasNominalObjectives, ...
        value.hasNominalObjectives);
    verifyEqual(testCase,plan.requiresNominalDij, ...
        value.requiresNominalDij);
    verifyEqual(testCase,plan.requiresScenarioDij, ...
        value.requiresScenarioDij);
    verifyEqual(testCase,plan.requiresIntervalDij, ...
        value.requiresIntervalDij);
    verifyEqual(testCase,plan.requiresProbDij, ...
        value.requiresProbDij);
end
end

function testApplyRobustnessContractRejectsInvalidLogicalFlags(testCase)
plan = cleanPlan('bad','Bad logical');
value = contract('COWC',true);
value.requiresScenarioDij = [true false];

verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.applyRobustnessContract( ...
    plan,value), ...
    'planWorkflow:config:RobustPlanConfig:InvalidLogical');

value = contract('COWC',true);
value.requiresScenarioDij = 2;
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanConfig.applyRobustnessContract( ...
    plan,value), ...
    'planWorkflow:config:RobustPlanConfig:InvalidLogical');
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
value.requiresScenarioDij = any(strcmp(robustnessMode, ...
    {'STOCH','COWC','c-COWC'}));
value.requiresIntervalDij = any(strcmp(robustnessMode, ...
    {'INTERVAL2','INTERVAL3'}));
value.requiresProbDij = strcmp(robustnessMode,'PROB2');
value.requiresNominalDij = strcmp(robustnessMode,'none') || ...
    (logical(hasNominal) && (value.requiresIntervalDij || ...
    value.requiresProbDij));
end

function variant = penaltyVariant( ...
        baseVariant,baseVariantIx,combinationIx,penalty)
variant = baseVariant;
variant.id = sprintf('%s_v%d_p%d', ...
    char(baseVariant.id),baseVariantIx,combinationIx);
variant.label = sprintf('%s / penalty=%g', ...
    char(baseVariant.label),penalty);
variant.baseVariantId = char(baseVariant.id);
variant.baseVariantLabel = char(baseVariant.label);
variant.baseVariantIndex = baseVariantIx;
variant.penaltyCombinationIndex = combinationIx;
variant.penaltyCombinationCount = 2;
variant.penaltyAssignments = struct( ...
    'groupField','structureObjectives', ...
    'groupIx',1, ...
    'objectiveIx',1, ...
    'structureName','CTV', ...
    'value',penalty);
variant.penaltyLabel = sprintf('penalty=%g',penalty);
end
