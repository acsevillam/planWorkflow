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

function testRobustDosePullingWeightsUseFinalPlanCst(testCase)
variants = [struct('id','theta_1','label','Theta 1','theta1',1) ...
    struct('id','theta_5','label','Theta 5','theta1',5)];
planConfig = cleanPlan('INTERVAL2',variants);
robustData = struct();
robustData.planConfig = planConfig;
robustData.dij = struct();
robustData.cst = pullingCst(1);
robustData.ctScenProb = 1;
robustData.pln = struct('propOpt',struct());
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
robustData.dij = struct();
robustData.cst = {};
robustData.ctScenProb = 1;
robustData.pln = struct('propOpt',struct());

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

function plan = cleanPlan(strategy,variants)
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = 'robust_1';
plan.label = strategy;
plan.objectiveSetName = 'robust_1';
plan.strategy = strategy;
plan.variants = variants;
plan = planWorkflow.config.RobustPlanConfig.normalizePlan(plan,1);
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
runConfig.dose_pulling_max_iter = 10;
runConfig.dose_pulling2_start = 0;
runConfig.dose_pulling2_limit = 0;
runConfig.dose_pulling2_criteria = 'meanQiTarget';
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
cst{1,4} = {1};
cst{1,6} = {objective};
end
