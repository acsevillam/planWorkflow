function tests = testRobustnessStrategies
tests = functiontests(localfunctions);
end

function testCowcStrategyMarksTargetAndSelectedOars(testCase)
[cst,objectiveInfo,pln,runConfig] = strategyFixture();
strategy = robOpt.robustness.COWCStrategy('COWC2',true);

[cst,pln] = strategy.apply(cst,pln,objectiveInfo,runConfig);

verifyEqual(testCase,cst{1,6}{1}.robustness,'COWC');
verifyEqual(testCase,cst{2,6}{1}.robustness,'COWC');
verifyFalse(testCase,isfield(cst{3,6}{1},'robustness'));
verifyEqual(testCase,pln.propOpt.useMaxApprox,'logsumexp');
end

function testCheapCowcStrategyAddsCheapBounds(testCase)
[cst,objectiveInfo,pln,runConfig] = strategyFixture();
strategy = robOpt.robustness.CheapCOWCStrategy('c-COWC',false);

[cst,pln] = strategy.apply(cst,pln,objectiveInfo,runConfig);

verifyEqual(testCase,cst{1,6}{1}.robustness,'COWC');
verifyFalse(testCase,isfield(cst{2,6}{1},'robustness'));
verifyEqual(testCase,pln.propOpt.useMaxApprox,'cheapCOWC');
verifyEqual(testCase,pln.propOpt.p1,runConfig.p1);
verifyEqual(testCase,pln.propOpt.p2,runConfig.p2);
end

function testCheapCowcRequiresBounds(testCase)
[cst,objectiveInfo,pln] = strategyFixture();
strategy = robOpt.robustness.CheapCOWCStrategy('c-COWC',false);

verifyError(testCase,@() strategy.apply(cst,pln,objectiveInfo,struct()), ...
    'robOpt:robustness:CheapCOWCStrategy:MissingBounds');
end

function testStochasticStrategyMarksOnlyRequestedStructures(testCase)
[cst,objectiveInfo,pln,runConfig] = strategyFixture();
strategy = robOpt.robustness.StochasticStrategy('STOCH',false);

cst = strategy.apply(cst,pln,objectiveInfo,runConfig);

verifyEqual(testCase,cst{1,6}{1}.robustness,'STOCH');
verifyFalse(testCase,isfield(cst{2,6}{1},'robustness'));
end

function testNoneStrategyIsNoOp(testCase)
[cst,objectiveInfo,pln,runConfig] = strategyFixture();
strategy = robOpt.robustness.NoneStrategy();

[actualCst,actualPln] = strategy.apply(cst,pln,objectiveInfo,runConfig);

verifyEqual(testCase,actualCst,cst);
verifyEqual(testCase,actualPln,pln);
verifyFalse(testCase,strategy.requiresIntervalDij());
end

function testIntervalStrategySignalsMissingImplementation(testCase)
[cst,objectiveInfo,pln,runConfig] = strategyFixture();
strategy = robOpt.robustness.IntervalStrategy('INTERVAL1');

verifyTrue(testCase,strategy.requiresIntervalDij());
verifyError(testCase,@() strategy.apply(cst,pln,objectiveInfo,runConfig), ...
    'robOpt:robustness:IntervalStrategy:NotImplemented');
end

function [cst,objectiveInfo,pln,runConfig] = strategyFixture()
cst = cell(3,6);
cst{1,2} = 'CTV';
cst{1,6} = {struct()};
cst{2,2} = 'RECTUM';
cst{2,6} = {struct()};
cst{3,2} = 'BODY';
cst{3,6} = {struct()};
objectiveInfo = struct('ixTarget',1,'oarStructSel',{{'RECTUM'}});
pln = struct('propOpt',struct());
runConfig = struct('p1',0.25,'p2',0.75);
end
