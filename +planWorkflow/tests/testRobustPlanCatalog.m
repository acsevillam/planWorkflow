function tests = testRobustPlanCatalog
tests = functiontests(localfunctions);
end

function testCatalogFollowsTemplateObjectiveSets(testCase)
catalog = planWorkflow.config.RobustPlanCatalog.select( ...
    'prostate','comparison_001','all');
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','comparison_001');

verifyEqual(testCase,{catalog.objectiveSetName}, ...
    {template.objectiveSets.robustPlans.id});
verifyEqual(testCase,{catalog.label}, ...
    {template.objectiveSets.robustPlans.label});
verifyEqual(testCase,{catalog.id}, ...
    {'PTV','COWC','STOCH','cCOWC','PROB2','INTERVAL2','INTERVAL3'});
verifyEqual(testCase,{catalog.robustnessMode}, ...
    {'none','COWC','STOCH','c-COWC','PROB2','INTERVAL2','INTERVAL3'});
end

function testCatalogSelectsSingleAndMultiplePlans(testCase)
singlePlan = planWorkflow.config.RobustPlanCatalog.select( ...
    'prostate','comparison_001','INTERVAL2');
verifyEqual(testCase,numel(singlePlan),1);
verifyEqual(testCase,singlePlan.id,'INTERVAL2');
verifyEqual(testCase,singlePlan.objectiveSetName,'Interval2');
verifyEqual(testCase,singlePlan.robustnessMode,'INTERVAL2');

plans = planWorkflow.config.RobustPlanCatalog.select( ...
    'prostate','comparison_001',{'PTV','INTERVAL2'});
verifyEqual(testCase,{plans.id},{'PTV','INTERVAL2'});
verifyEqual(testCase,{plans.objectiveSetName},{'PTV','Interval2'});
end

function testCatalogSupportsTemplateSpecificIds(testCase)
plan = planWorkflow.config.RobustPlanCatalog.select( ...
    'h&n','interval2_001','robust_1');

verifyEqual(testCase,plan.objectiveSetName,'robust_1');
verifyEqual(testCase,plan.id,'INTERVAL2');
verifyEqual(testCase,plan.robustnessMode,'INTERVAL2');
verifyEqual(testCase,[plan.variants.theta1], ...
    [1 2 5 10 20 0.01 0.02 0.05 0.1 0.2 0.5 50]);
end

function testCatalogUsesCanonicalPlanIdsAcrossAnatomies(testCase)
expectedIds = {'PTV','COWC','STOCH','cCOWC','PROB2','INTERVAL2','INTERVAL3'};

breast = planWorkflow.config.RobustPlanCatalog.select( ...
    'breast','comparison_001','all');
prostate = planWorkflow.config.RobustPlanCatalog.select( ...
    'prostate','comparison_001','all');
headAndNeck = planWorkflow.config.RobustPlanCatalog.select( ...
    'h&n','comparison_001','all');

verifyEqual(testCase,{breast.id},expectedIds);
verifyEqual(testCase,{prostate.id},expectedIds);
verifyEqual(testCase,{headAndNeck.id},{'PTV','INTERVAL2'});
verifyEqual(testCase,{headAndNeck.objectiveSetName}, ...
    {'robust_1','robust_2'});
end

function testCatalogAppliesAnatomyScenarioPolicy(testCase)
scenario = planWorkflow.config.ScenarioSpec.defaults('impScen5');
scenario.shiftSD = [4 8 6];

plan = planWorkflow.config.RobustPlanCatalog.select( ...
    'breast','comparison_001','COWC','robustScenario',scenario);

verifyEqual(testCase,plan.id,'COWC');
verifyEqual(testCase,plan.objectiveSetName,'Minimax');
verifyEqual(testCase,plan.scenario.shiftSD,[4 8 6]);
verifyEqual(testCase,plan.scenario.mode,'impScen5');
end

function testCatalogKeepsPhotonDefaultScenarioForCompatibility(testCase)
plan = planWorkflow.config.RobustPlanCatalog.select( ...
    'breast','comparison_001','COWC','radiationMode','photons');

verifyEqual(testCase,plan.id,'COWC');
verifyFalse(testCase,plan.scenario.rangeActive);
end

function testCatalogRequiresExplicitScenarioForParticleRobustPlans(testCase)
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanCatalog.select( ...
    'breast','comparison_001','COWC','radiationMode','protons'), ...
    ['planWorkflow:config:RobustPlanCatalog:' ...
    'MissingParticleRobustScenario']);

nominalPlan = planWorkflow.config.RobustPlanCatalog.select( ...
    'breast','comparison_001','PTV','radiationMode','protons');
verifyEqual(testCase,nominalPlan.id,'PTV');
verifyEqual(testCase,nominalPlan.robustnessMode,'none');
end

function testCatalogNormalizesParticleRadiationMode(testCase)
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanCatalog.select( ...
    'breast','comparison_001','COWC','radiationMode',' Protons '), ...
    ['planWorkflow:config:RobustPlanCatalog:' ...
    'MissingParticleRobustScenario']);
end

function testCatalogRejectsUnknownRadiationModes(testCase)
invalidModes = {'proton','carbons','electrons'};
for modeIx = 1:numel(invalidModes)
    verifyError(testCase,@() ...
        planWorkflow.config.RobustPlanCatalog.select( ...
        'breast','comparison_001','COWC', ...
        'radiationMode',invalidModes{modeIx}), ...
        ['planWorkflow:config:RobustPlanCatalog:' ...
        'InvalidRadiationMode'],invalidModes{modeIx});
end
end

function testCatalogAcceptsExplicitParticleScenarioPolicy(testCase)
scenario = particleRobustScenario();

plan = planWorkflow.config.RobustPlanCatalog.select( ...
    'breast','comparison_001','COWC', ...
    'radiationMode','protons','robustScenario',scenario);

verifyEqual(testCase,plan.id,'COWC');
verifyTrue(testCase,plan.scenario.rangeActive);
verifyEqual(testCase,plan.scenario.rangeRelSD,0.035);
end

function testCatalogValidationLocksPlanSet(testCase)
runConfig = struct();
runConfig.precompute.robustPlans = ...
    planWorkflow.config.RobustPlanCatalog.select( ...
    'prostate','comparison_001',{'PTV','INTERVAL2'});

planWorkflow.config.RobustPlanCatalog.validateSelectedPlans( ...
    runConfig,'prostate','comparison_001',{'PTV','INTERVAL2'});
verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanCatalog.validateSelectedPlans( ...
    runConfig,'prostate','comparison_001',{'PTV'}), ...
    'planWorkflow:config:RobustPlanCatalog:UnexpectedPlanCount');
end

function testCatalogValidationRespectsParticleScenarioPolicy(testCase)
scenario = particleRobustScenario();
runConfig = struct();
runConfig.precompute.robustPlans = ...
    planWorkflow.config.RobustPlanCatalog.select( ...
    'breast','comparison_001','COWC', ...
    'radiationMode','protons','robustScenario',scenario);

verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanCatalog.validateSelectedPlans( ...
    runConfig,'breast','comparison_001',{'COWC'}, ...
    'radiationMode','protons'), ...
    ['planWorkflow:config:RobustPlanCatalog:' ...
    'MissingParticleRobustScenario']);

planWorkflow.config.RobustPlanCatalog.validateSelectedPlans( ...
    runConfig,'breast','comparison_001',{'COWC'}, ...
    'radiationMode','protons','robustScenario',scenario,'strict',true);
end

function testCatalogValidationRejectsUnknownRadiationMode(testCase)
runConfig = struct();
runConfig.precompute.robustPlans = ...
    planWorkflow.config.RobustPlanCatalog.select( ...
    'breast','comparison_001','PTV');

verifyError(testCase,@() ...
    planWorkflow.config.RobustPlanCatalog.validateSelectedPlans( ...
    runConfig,'breast','comparison_001',{'PTV'}, ...
    'radiationMode','proton'), ...
    ['planWorkflow:config:RobustPlanCatalog:' ...
    'InvalidRadiationMode']);
end

function scenario = particleRobustScenario()
scenario = planWorkflow.config.ScenarioSpec.defaults('impScen5');
scenario.ctActive = true;
scenario.setupActive = true;
scenario.rangeActive = true;
scenario.rangeRelSD = 0.035;
scenario.numOfRangeGridPoints = 3;
end
