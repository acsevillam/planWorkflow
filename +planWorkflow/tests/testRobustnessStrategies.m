function tests = testRobustnessStrategies
tests = functiontests(localfunctions);
end

function testCowcStrategyMarksTargetAndSelectedOars(testCase)
[cst,objectiveInfo,pln,runConfig] = strategyFixture();
strategy = planWorkflow.robustness.COWCStrategy('COWC',true);

[cst,pln] = strategy.apply(cst,pln,objectiveInfo,runConfig);

verifyEqual(testCase,cst{1,6}{1}.robustness,'COWC');
verifyEqual(testCase,cst{2,6}{1}.robustness,'COWC');
verifyFalse(testCase,isfield(cst{3,6}{1},'robustness'));
verifyEqual(testCase,pln.propOpt.useMaxApprox,'logsumexp');
end

function testCheapCowcStrategyAddsCheapBounds(testCase)
[cst,objectiveInfo,pln,runConfig] = strategyFixture();
strategy = planWorkflow.robustness.CheapCOWCStrategy('c-COWC',false);

[cst,pln] = strategy.apply(cst,pln,objectiveInfo,runConfig);

verifyEqual(testCase,cst{1,6}{1}.robustness,'COWC');
verifyFalse(testCase,isfield(cst{2,6}{1},'robustness'));
verifyEqual(testCase,pln.propOpt.useMaxApprox,'cheapCOWC');
verifyEqual(testCase,pln.propOpt.p1,runConfig.variant.p1);
verifyEqual(testCase,pln.propOpt.p2,runConfig.variant.p2);
end

function testCheapCowcRequiresBounds(testCase)
[cst,objectiveInfo,pln] = strategyFixture();
strategy = planWorkflow.robustness.CheapCOWCStrategy('c-COWC',false);

verifyError(testCase,@() strategy.apply(cst,pln,objectiveInfo,struct()), ...
    'planWorkflow:robustness:CheapCOWCStrategy:MissingBounds');
end

function testStochasticStrategyMarksOnlyRequestedStructures(testCase)
[cst,objectiveInfo,pln,runConfig] = strategyFixture();
strategy = planWorkflow.robustness.StochasticStrategy('STOCH',false);

cst = strategy.apply(cst,pln,objectiveInfo,runConfig);

verifyEqual(testCase,cst{1,6}{1}.robustness,'STOCH');
verifyFalse(testCase,isfield(cst{2,6}{1},'robustness'));
end

function testNoneStrategyIsNoOp(testCase)
[cst,objectiveInfo,pln,runConfig] = strategyFixture();
strategy = planWorkflow.robustness.NoneStrategy();

[actualCst,actualPln] = strategy.apply(cst,pln,objectiveInfo,runConfig);

verifyEqual(testCase,actualCst,cst);
verifyEqual(testCase,actualPln,pln);
verifyFalse(testCase,strategy.requiresIntervalDij());
end

function testIntervalStrategyAppliesMatRadIntervalSettings(testCase)
[cst,objectiveInfo,pln,runConfig] = strategyFixture();
runConfig.variant = struct('theta1',30,'theta2',1.5);
strategy = planWorkflow.robustness.IntervalStrategy('INTERVAL3');

verifyTrue(testCase,strategy.requiresIntervalDij());
[cst,pln] = strategy.apply(cst,pln,objectiveInfo,runConfig);

verifyEqual(testCase,cst{1,6}{1}.robustness,'INTERVAL3');
verifyEqual(testCase,cst{2,6}{1}.robustness,'INTERVAL3');
verifyFalse(testCase,isfield(cst{3,6}{1},'robustness'));
verifyFalse(testCase,isfield(pln.propOpt,'scen4D'));
verifyEqual(testCase,pln.propOpt.theta1,30);
verifyEqual(testCase,pln.propOpt.theta2,1.5);
end

function testIntervalStrategyRejectsUnsupportedMode(testCase)
verifyError(testCase,@() planWorkflow.robustness.IntervalStrategy('INTERVAL1'), ...
    'planWorkflow:robustness:IntervalStrategy:UnsupportedMode');
end

function testIntervalStrategyRequiresBertoluzzaTarget(testCase)
[cst,objectiveInfo,pln,runConfig] = strategyFixture();
cst{1,6}{1}.className = 'DoseObjectives.matRad_SquaredDeviation';
strategy = planWorkflow.robustness.IntervalStrategy('INTERVAL2');

verifyError(testCase,@() strategy.apply(cst,pln,objectiveInfo,runConfig), ...
    'planWorkflow:robustness:IntervalStrategy:TargetObjectiveRequired');
end

function [cst,objectiveInfo,pln,runConfig] = strategyFixture()
cst = cell(3,6);
cst{1,2} = 'CTV';
cst{1,6} = {struct('className', ...
    'DoseObjectives.matRad_SquaredBertoluzzaDeviation')};
cst{2,2} = 'RECTUM';
cst{2,6} = {struct('className', ...
    'DoseObjectives.matRad_SquaredOverdosing')};
cst{3,2} = 'BODY';
cst{3,6} = {struct('className', ...
    'DoseObjectives.matRad_SquaredOverdosing')};
objectiveInfo = struct('ixTarget',1,'robustOarNames',{{'RECTUM'}});
pln = struct('propOpt',struct());
runConfig = struct('variant',struct('p1',0.25,'p2',0.75));
end
