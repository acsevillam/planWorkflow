function tests = testDosePullingService
tests = functiontests(localfunctions);
end

function testInterval2DosePullingUsesPlanVariants(testCase)
verifyDosePullingVariantCount(testCase,'INTERVAL2', ...
    [struct('id','theta_1','label','Theta 1','theta1',1) ...
    struct('id','theta_5','label','Theta 5','theta1',5)]);
end

function testInterval3DosePullingUsesPlanVariants(testCase)
verifyDosePullingVariantCount(testCase,'INTERVAL3', ...
    [struct('id','theta_low','label','Low','theta1',5,'theta2',0.5) ...
    struct('id','theta_high','label','High','theta1',10,'theta2',1.0) ...
    struct('id','theta_max','label','Max','theta1',15,'theta2',1.5)]);
end

function testCheapCowcDosePullingUsesPlanVariants(testCase)
verifyDosePullingVariantCount(testCase,'c-COWC', ...
    [struct('id','bounds_1','label','Bounds 1','p1',1,'p2',2) ...
    struct('id','bounds_2','label','Bounds 2','p1',2,'p2',3)]);
end

function testRobustDosePullingMetricsUsesVectorCtScenarioWeights(testCase)
[runConfig,cst,pln,resultGUI] = ...
    dosePullingMetricsFixture([2 0.4; 3 0.6]);

metrics = planWorkflow.precompute.DosePullingMetrics.robust( ...
    runConfig,cst,pln,resultGUI,[0.25 0.75],3,struct());

verifyEqual(testCase,metrics.meanQiTarget,0.75,'AbsTol',1e-12);
verifyEqual(testCase,metrics.minQiTarget,0,'AbsTol',1e-12);
verifyEqual(testCase,metrics.iteration,3);
end

function testRobustDosePullingMetricsUsesModelWeightsWhenOverrideEmpty(testCase)
[runConfig,cst,pln,resultGUI] = ...
    dosePullingMetricsFixture([2 0.4; 3 0.6]);

metrics = planWorkflow.precompute.DosePullingMetrics.robust( ...
    runConfig,cst,pln,resultGUI,[],0,struct());

verifyEqual(testCase,metrics.meanQiTarget,0.6,'AbsTol',1e-12);
verifyEqual(testCase,metrics.minQiTarget,0,'AbsTol',1e-12);
end

function testRobustDosePullingMetricsAcceptsLegacyScenarioDoseFields( ...
        testCase)
[runConfig,cst,pln,resultGUI] = ...
    dosePullingMetricsFixture([2 0.4; 3 0.6]);
resultGUI.physicalDose_1 = resultGUI.physicalDose_scen1;
resultGUI.physicalDose_2 = resultGUI.physicalDose_scen2;
resultGUI = rmfield(resultGUI,{'physicalDose_scen1','physicalDose_scen2'});

metrics = planWorkflow.precompute.DosePullingMetrics.robust( ...
    runConfig,cst,pln,resultGUI,[0.25 0.75],3,struct());

verifyEqual(testCase,metrics.meanQiTarget,0.75,'AbsTol',1e-12);
end

function testRobustDosePullingMetricsRejectsMismatchedCtScenarioVector( ...
        testCase)
[runConfig,cst,pln,resultGUI] = ...
    dosePullingMetricsFixture([1 0.2; 2 0.3; 3 0.5]);

verifyError(testCase,@() ...
    planWorkflow.precompute.DosePullingMetrics.robust( ...
    runConfig,cst,pln,resultGUI,[0.25 0.75],0,struct()), ...
    'planWorkflow:precompute:DosePulling:InvalidCtScenProb');
end

function testHeuristicStepSearchSelectsNormalizedKneeStep(testCase)
runConfig = heuristicRunConfig();
runConfig.dose_pulling_max_iter = 10;
runConfig.dose_pulling_local_window = 8;
runConfig.dose_pulling_selection_policy = 'normalizedKnee';
initialState = struct('step',0);

search = planWorkflow.precompute.DosePullingStepSearch.run( ...
    runConfig,initialState,@evaluateStep);

verifyEqual(testCase,search.best.step,5);
verifyEqual(testCase,search.localBracket,[0 10]);

    function [state,result] = evaluateStep(state,step)
        state.step = step;
        value = min(0.9,0.4 + 0.1 * step);
        result = ...
            planWorkflow.precompute.DosePullingScoring.resultFromValues( ...
            step,value,0.9,step);
    end
end

function testWeightedSumRespectsConfiguredWeights(testCase)
results = repmat(planWorkflow.precompute.DosePullingScoring.emptyResult(), ...
    1,2);
results(1) = ...
    planWorkflow.precompute.DosePullingScoring.resultFromValues( ...
    1,0.0,1.0,0.0);
results(2) = ...
    planWorkflow.precompute.DosePullingScoring.resultFromValues( ...
    2,0.9,1.0,10.0);

runConfig = heuristicRunConfig();
runConfig.dose_pulling_selection_policy = 'weightedSum';
runConfig.dose_pulling_target_weight = 10;
runConfig.dose_pulling_oar_weight = 1;
resultsByTarget = ...
    planWorkflow.precompute.DosePullingScoring.annotateSelectionScores( ...
    results,1e-3,runConfig);
bestByTarget = planWorkflow.precompute.DosePullingScoring.chooseBest( ...
    resultsByTarget,1e-3,runConfig);
verifyEqual(testCase,bestByTarget.step,2);

runConfig.dose_pulling_target_weight = 1;
runConfig.dose_pulling_oar_weight = 10;
resultsByOar = ...
    planWorkflow.precompute.DosePullingScoring.annotateSelectionScores( ...
    results,1e-3,runConfig);
bestByOar = planWorkflow.precompute.DosePullingScoring.chooseBest( ...
    resultsByOar,1e-3,runConfig);
verifyEqual(testCase,bestByOar.step,1);
end

function testOarScoreUsesTotalDoseForDoseObjectives(testCase)
cst = scoringCst(1,0);
doseCube = [19 20 21];
pln = struct('numOfFractions',2);

score = planWorkflow.precompute.DosePullingScoring.oarObjectiveScoreFromDose( ...
    cst,doseCube,pln,1,{'CTV'});

verifyEqual(testCase,score,2 * 100 * 2 / 3,'AbsTol',1e-10);
end

function testChannel2WithoutOarDosePullingObjectivesHasZeroOarScore(testCase)
cst = scoringCst(1,0);
doseCube = [19 20 21];
pln = struct('numOfFractions',2);

score = planWorkflow.precompute.DosePullingScoring.oarObjectiveScoreFromDose( ...
    cst,doseCube,pln,2,{'CTV'});

verifyEqual(testCase,score,0);
end

function testInfeasibleVmaxCandidatesAreExcluded(testCase)
runConfig = heuristicRunConfig();
runConfig.dose_pulling_max_vmax_percent = 100;
verifyFalse(testCase, ...
    planWorkflow.precompute.DosePullingScoring.oarObjectiveFeasible( ...
    scoringCst(1,101),1,{'CTV'},runConfig));

results = repmat(planWorkflow.precompute.DosePullingScoring.emptyResult(), ...
    1,2);
results(1) = ...
    planWorkflow.precompute.DosePullingScoring.resultFromValues( ...
    1,1.0,1.0,0.0);
results(1).isFeasible = false;
results(2) = ...
    planWorkflow.precompute.DosePullingScoring.resultFromValues( ...
    2,1.0,1.0,1.0);
results = planWorkflow.precompute.DosePullingScoring.annotateSelectionScores( ...
    results,1e-3,runConfig);
best = planWorkflow.precompute.DosePullingScoring.chooseBest( ...
    results,1e-3,runConfig);

verifyEqual(testCase,best.step,2);
end

function testHeuristicRobustChannel2SelectsLocalStepAndLogsLabel(testCase)
runConfig = heuristicRunConfig();
runConfig.dose_pulling_max_iter = 40;
runConfig.dose_pulling2 = true;
runConfig.dose_pulling2_target = {'CTV'};
runConfig.dose_pulling2_limit = 0.4;
runConfig.dose_pulling2_criteria = 'meanQiTarget';
robustData = struct();
robustData.planConfig = cleanPlan('INTERVAL2', ...
    struct('id','theta_1','label','Variant 1','theta1',1));
robustData.cst = pullingCst(1);
robustData.ctScenProb = 1;
robustData.pln = struct('propOpt',struct());
robustData = attachOptimizationInput(robustData);
messages = {};
context = planWorkflow.precompute.DosePulling.context( ...
    runConfig,@runOptimization,@runAnalysis,@runMetrics,@runPolicy, ...
    @captureMessage);

[~,report] = planWorkflow.precompute.DosePulling.runRobust( ...
    context,robustData);

verifyEqual(testCase,report.selected.step,24);
verifyEqual(testCase,report.selected.oarScore,0);
verifyEqual(testCase,report.stopReason,'converged');
verifyTrue(testCase,isfield(report,'trace'));
verifyTrue(testCase,any([report.trace.isSelected]));
verifyTrue(testCase,any(contains(messages, ...
    'meanQiTarget(COV1)_CTV')));

    function resultGUI = runOptimization(~,~,~,~)
        resultGUI = struct('w',1,'physicalDose',0);
    end

    function metrics = runMetrics(~,~,~,~,iteration,~)
        value = min(0.4,iteration / 60);
        metrics = struct('step',2,'iteration',iteration, ...
            'targetNames',{{'CTV'}},'criteria',{{'COV1'}}, ...
            'meanQiTarget',value,'minQiTarget',value, ...
            'selectedCriterion','meanQiTarget', ...
            'selectedValues',value,'limits',0.4, ...
            'isSatisfied',value >= 0.4);
    end

    function tf = runPolicy(metrics)
        tf = ~metrics.isSatisfied;
    end

    function captureMessage(message)
        messages{end + 1} = message; %#ok<AGROW>
    end
end

function testHeuristicRobustCandidateFeasibilityUsesAllVariantCsts(testCase)
runConfig = heuristicRunConfig();
runConfig.dose_pulling_max_iter = 0;
runConfig.dose_pulling2 = true;
runConfig.dose_pulling2_target = {'CTV'};
runConfig.dose_pulling2_limit = 0;
runConfig.dose_pulling2_criteria = 'meanQiTarget';
runConfig.dose_pulling_max_vmax_percent = 100;
variants = [struct('id','theta_1','label','Theta 1','theta1',1) ...
    struct('id','theta_5','label','Theta 5','theta1',5)];
robustData = struct();
robustData.planConfig = cleanPlan('INTERVAL2',variants);
robustData.cst = robustHeuristicCst(3,50);
robustData.cstByVariant = {robustHeuristicCst(3,50), ...
    robustHeuristicCst(7,101)};
robustData.ctScenProb = 1;
robustData.pln = struct('propOpt',struct());
robustData = attachOptimizationInput(robustData);
context = planWorkflow.precompute.DosePulling.context( ...
    runConfig,@runOptimization,@runAnalysis,@runMetrics,@runPolicy, ...
    @logMessage);

[~,report] = planWorkflow.precompute.DosePulling.runRobust( ...
    context,robustData);

verifyFalse(testCase,report.selected.isFeasible);
verifyEqual(testCase,report.stopReason,'infeasible');
verifyEqual(testCase,report.trace(1).stopReason,'infeasible');
verifyEqual(testCase,report.selected.rectumPull,101);
verifyEqual(testCase,report.selected.channelObjective,7);

    function resultGUI = runOptimization(~,~,~,~)
        resultGUI = struct('w',1,'physicalDose',[0 0 0]);
    end
end

function testRobustDosePullingWeightsUseFinalPlanCst(testCase)
variants = [struct('id','theta_1','label','Theta 1','theta1',1) ...
    struct('id','theta_5','label','Theta 5','theta1',5)];
planConfig = cleanPlan('INTERVAL2',variants);
robustData = struct();
robustData.planConfig = planConfig;
robustData.cst = pullingCst(1);
robustData.ctScenProb = 1;
robustData.pln = struct('propOpt',struct());
robustData = attachOptimizationInput(robustData);
callCount = 0;
context = planWorkflow.precompute.DosePulling.context( ...
    dosePullingRunConfig(),@runOptimization,@runAnalysis, ...
    @runMetrics,@runPolicy,@logMessage);

[robustData,report] = planWorkflow.precompute.DosePulling.runRobust( ...
    context,robustData);

verifyEqual(testCase,callCount,4);
verifyEqual(testCase,robustData.cst{1,6}{1}.parameters,{2});
verifyEqual(testCase,robustData.initialWeights{1},[1 2]);
verifyEqual(testCase,robustData.initialWeights{2},[5 2]);
verifyEqual(testCase,numel(report.plans{1}.history),2);
verifyEqual(testCase,numel(report.plans{2}.history),2);

    function resultGUI = runOptimization(~,cst,pln,~)
        callCount = callCount + 1;
        resultGUI = struct('w',[pln.propOpt.theta1 ...
            cst{1,6}{1}.parameters{1}]);
    end

    function metrics = runMetrics(cst,pln,resultGUI,ctScenProb, ...
            iteration,robustData) %#ok<INUSD>
        metrics = struct('step',2,'iteration',iteration, ...
            'targetNames',{{'CTV'}},'criteria',{{'meanQiTarget'}}, ...
            'meanQiTarget',cst{1,6}{1}.parameters{1}, ...
            'minQiTarget',1,'selectedCriterion','meanQiTarget', ...
            'selectedValues',resultGUI.w(2),'limits',2, ...
            'isSatisfied',cst{1,6}{1}.parameters{1} >= 2);
    end

    function tf = runPolicy(metrics)
        tf = ~metrics.isSatisfied;
    end
end

function verifyDosePullingVariantCount(testCase,strategy,variants)
planConfig = cleanPlan(strategy,variants);
robustData = struct();
robustData.planConfig = planConfig;
robustData.cst = {};
robustData.ctScenProb = 1;
robustData.pln = struct('propOpt',struct());
robustData = attachOptimizationInput(robustData);

callCount = 0;
    context = dosePullingContext(@runOptimization);

[robustData,report] = planWorkflow.precompute.DosePulling.runRobust( ...
    context,robustData);

verifyEqual(testCase,callCount,numel(variants));
verifyEqual(testCase,numel(report.plans),numel(variants));
verifyEqual(testCase,numel(robustData.initialWeights),numel(variants));
verifyEqual(testCase,cell2mat(robustData.initialWeights),1:numel(variants));
    function resultGUI = runOptimization(~,~,pln,~)
        callCount = callCount + 1;
        verifyTrue(testCase,isfield(pln,'propOpt'));
        resultGUI = struct('w',callCount);
    end
end

function plan = cleanPlan(robustnessMode,variants)
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = 'robust_1';
plan.label = robustnessMode;
plan.objectiveSetName = 'robust_1';
plan.robustnessMode = robustnessMode;
plan.variants = variants;
plan = planWorkflow.config.RobustPlanConfig.normalizePlan(plan,1);
end

function [runConfig,cst,pln,resultGUI] = ...
        dosePullingMetricsFixture(ctScenProb)
runConfig = dosePullingRunConfig();
runConfig.dose_pulling2_target = {'CTV'};
runConfig.dose_pulling1_criteria = {'COV1'};
runConfig.dose_pulling2_limit = 0;

ct = struct('numOfCtScen',max(ctScenProb(:,1)));
pln = struct();
pln.numOfFractions = 10;
pln.bioParam = struct('quantityVis','physicalDose');
pln.multScen = matRad_NominalScenario(ct);
pln.multScen.ctScenProb = ctScenProb;

cst = dosePullingMetricsCst();
resultGUI = struct();
resultGUI.physicalDose_scen1 = 0.5 * ones(3,1);
resultGUI.physicalDose_scen2 = 1.5 * ones(3,1);
end

function cst = dosePullingMetricsCst()
objective = DoseObjectives.matRad_SquaredDeviation(1,10);
cst = cell(1,6);
cst{1,1} = 1;
cst{1,2} = 'CTV';
cst{1,3} = 'TARGET';
cst{1,4} = {1:3};
cst{1,5} = struct('Visible',true,'Priority',1);
cst{1,6} = {objective};
end

function testDosePullingContextRequiresExplicitDependencies(testCase)
runConfig = dosePullingRunConfig();

verifyError(testCase,@() planWorkflow.precompute.DosePulling.context( ...
    runConfig,[],@localRunAnalysis,@localRunMetrics,@localRunPolicy, ...
    @localLogMessage), ...
    'planWorkflow:precompute:DosePulling:InvalidContext');

    function [resultGUI,dvh,qi] = localRunAnalysis(varargin) %#ok<STOUT,INUSD>
    end
    function metrics = localRunMetrics(varargin) %#ok<STOUT,INUSD>
    end
    function tf = localRunPolicy(varargin) %#ok<STOUT,INUSD>
    end
    function localLogMessage(varargin) %#ok<INUSD>
    end
end

function context = dosePullingContext(optimizer)
if nargin < 1 || isempty(optimizer)
    optimizer = @(dij,cst,pln,initialWeights) struct('w',1); %#ok<INUSD>
end
runConfig = dosePullingRunConfig();
context = planWorkflow.precompute.DosePulling.context( ...
    runConfig,optimizer,@runAnalysis,@runMetrics,@runPolicy,@logMessage);
end

function runConfig = dosePullingRunConfig()
runConfig = struct();
runConfig.dose_pulling_strategy = 'Threshold';
runConfig.dose_pulling_max_iter = 10;
runConfig.dose_pulling2_start = 0;
runConfig.dose_pulling2_limit = 0;
runConfig.dose_pulling2_criteria = 'meanQiTarget';
end

function runConfig = heuristicRunConfig()
runConfig = dosePullingRunConfig();
runConfig.dose_pulling_strategy = 'heuristicMultiObjective';
runConfig.dose_pulling_search_schedule = 'exponential';
runConfig.dose_pulling_local_window = 8;
runConfig.dose_pulling_patience = 3;
runConfig.dose_pulling_target_tol = 1e-3;
runConfig.dose_pulling_selection_policy = 'normalizedKnee';
runConfig.dose_pulling_target_weight = 1.0;
runConfig.dose_pulling_oar_weight = 1.0;
runConfig.dose_pulling_step_weight = 1e-6;
runConfig.dose_pulling_max_vmax_percent = 100;
runConfig.dose_pulling_use_warm_start = true;
runConfig.dose_pulling1_target = {'CTV'};
runConfig.dose_pulling1_criteria = {'COV1'};
runConfig.dose_pulling1_limit = 0.9;
runConfig.dose_pulling2_target = {'CTV'};
end

function [resultGUI,dvh,qi] = runAnalysis( ...
        ct,cst,stf,pln,resultGUI,showFigures) %#ok<INUSD>
dvh = [];
qi = [];
end

function metrics = runMetrics( ...
        cst,pln,resultGUI,ctScenProb,iteration,robustData) %#ok<INUSD>
metrics = struct('step',2,'iteration',iteration,'targetNames',{{'CTV'}}, ...
    'criteria',{{'meanQiTarget'}},'meanQiTarget',1, ...
    'minQiTarget',1,'selectedCriterion','meanQiTarget', ...
    'selectedValues',1,'limits',0,'isSatisfied',true);
end

function tf = runPolicy(metrics) %#ok<INUSD>
tf = false;
end

function logMessage(message) %#ok<INUSD>
end

function cst = pullingCst(parameter)
objective = struct( ...
    'parameters',{{parameter}}, ...
    'penalty',1, ...
    'dosePulling',true, ...
    'pullingStep',2, ...
    'objectivePullingRate',{{1}}, ...
    'penaltyPullingRate',0);
cst = cell(1,6);
cst{1,2} = 'CTV';
cst{1,4} = {1};
cst{1,6} = {objective};
end

function cst = robustHeuristicCst(targetPenalty,vMaxPercent)
targetObjective = struct('className','matRad_MinDose', ...
    'parameters',{{78}},'penalty',targetPenalty, ...
    'dosePulling',true,'pullingStep',2);
oarObjective = struct('className','matRad_MaxDVH', ...
    'parameters',{{40,vMaxPercent}},'penalty',2, ...
    'dosePulling',true,'pullingStep',2);
cst = cell(2,6);
cst{1,2} = 'CTV';
cst{1,4} = {1};
cst{1,6} = {targetObjective};
cst{2,2} = 'RECTUM';
cst{2,4} = {1:3};
cst{2,6} = {oarObjective};
end

function robustData = attachOptimizationInput(robustData)
robustData.ct = struct();
robustData.stf = struct();
cst = robustData.cst;
if isempty(cst)
    cst = {1};
end
robustData.optimizationInput = ...
    planWorkflow.precompute.OptimizationInput.build( ...
    robustData.ct,cst,robustData.pln,robustData.stf, ...
    referenceDij(),'nominal','test');
end

function dij = referenceDij()
dij = struct();
end

function cst = scoringCst(pullingStep,vMaxPercent)
targetObjective = struct('className','matRad_MinDose', ...
    'parameters',{{78}},'penalty',1,'dosePulling',false);
oarObjective = struct('className','matRad_MaxDVH', ...
    'parameters',{{40,vMaxPercent}},'penalty',2, ...
    'dosePulling',true,'pullingStep',pullingStep);
cst = cell(2,6);
cst{1,2} = 'CTV';
cst{1,4} = {1};
cst{1,6} = {targetObjective};
cst{2,2} = 'RECTUM';
cst{2,4} = {1:3};
cst{2,6} = {oarObjective};
end
