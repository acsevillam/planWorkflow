function tests = testIntervalModelSolutions
tests = functiontests(localfunctions);
end

function testInterval2AndInterval3CanSelectDifferentControlledSolutions(testCase)
assumeTrue(testCase,exist('matRad_OptimizationProblem','class') == 8);
assumeTrue(testCase,exist('matRad_DoseProjection','class') == 8);
assumeTrue(testCase,exist('DoseObjectives.matRad_SquaredDeviation','class') == 8);

plnInterval2 = planWorkflow.optimization.VariantPlanFactory.build( ...
    controlledIntervalRobustData('INTERVAL2'),1);
plnInterval3 = planWorkflow.optimization.VariantPlanFactory.build( ...
    controlledIntervalRobustData('INTERVAL3'),1);

verifyTrue(testCase,isfield(plnInterval2.propOpt,'dij_interval'));
verifyTrue(testCase,isfield(plnInterval3.propOpt,'dij_interval'));
verifyTrue(testCase,isfield(plnInterval3.propOpt,'theta2'));
verifyEqual(testCase,plnInterval3.propOpt.theta2,1);

[optiProb2,dij2,cst2] = matRadProblemFromPlan(plnInterval2,'INTERVAL2');
[optiProb3,dij3,cst3] = matRadProblemFromPlan(plnInterval3,'INTERVAL3');
wGrid = (0:0.001:1.5)';

[wInterval2,fInterval2] = minimizeObjectiveOnGrid( ...
    optiProb2,dij2,cst2,wGrid);
[wInterval3,fInterval3] = minimizeObjectiveOnGrid( ...
    optiProb3,dij3,cst3,wGrid);

verifyEqual(testCase,wInterval2,1,'AbsTol',1e-12);
verifyEqual(testCase,wInterval3,0.5,'AbsTol',1e-12);
verifyGreaterThan(testCase,abs(wInterval2 - wInterval3),0.25);

verifyEqual(testCase,fInterval2,0,'AbsTol',1e-12);
verifyEqual(testCase,fInterval3,0,'AbsTol',1e-12);
verifyGreaterThan(testCase, ...
    optiProb2.matRad_objectiveFunction(wInterval3,dij2,cst2), ...
    fInterval2);
verifyGreaterThan(testCase, ...
    optiProb3.matRad_objectiveFunction(wInterval2,dij3,cst3), ...
    fInterval3);
end

function robustData = controlledIntervalRobustData(robustness)
robustData = struct();
robustData.pln = struct('propOpt',struct());
robustData.dij_interval = controlledDijInterval();
robustData.planConfig = controlledPlanConfig(robustness);
robustData.strategy = planWorkflow.robustness.IntervalStrategy(robustness);
end

function planConfig = controlledPlanConfig(robustness)
planConfig = planWorkflow.config.RobustPlanConfig.defaultPlan();
planConfig.id = lower(robustness);
planConfig.robustnessMode = robustness;
planConfig.requiresIntervalDij = true;
planConfig.requiresNominalDij = false;
planConfig.requiresScenarioDij = false;
planConfig.requiresProb2Dij = false;
planConfig.optimization4D = ...
    planWorkflow.config.RobustPlanConfig.defaultOptimization4D();
planConfig.variants = ...
    planWorkflow.config.RobustStrategySpec.defaultVariant(robustness,1);
planConfig.variants.theta1 = 1;
if strcmp(robustness,'INTERVAL3')
    planConfig.variants.theta2 = 1;
end
end

function dijInterval = controlledDijInterval()
dijInterval.center = sparse(1,1,1,1,1);
dijInterval.OARSubIx = 1;
dijInterval.OARRadiusFactor = {sparse(1,1,1,1,1)};
dijInterval.OARRadiusRank = 1;
dijInterval.radiusMode = 'std';
end

function [optiProb,dij,cst] = matRadProblemFromPlan(pln,robustness)
backProjection = matRad_DoseProjection();
backProjection.scenarios = 1;
backProjection.scenarioProb = 1;
backProjection.nominalCtScenarios = 1;

optiProb = matRad_OptimizationProblem(backProjection);
optiProb.dij_interval = pln.propOpt.dij_interval;
if isfield(pln.propOpt,'theta2')
    optiProb.theta2 = pln.propOpt.theta2;
end

dij.physicalDose = {sparse(1,1)};
dij.doseGrid.numOfVoxels = 1;
dij.totalNumOfBixels = 1;

objective = DoseObjectives.matRad_SquaredDeviation(1,1);
objective.robustness = robustness;

cst = cell(1,6);
cst{1,3} = 'OAR';
cst{1,4} = {1};
cst{1,5}.alphaX = [];
cst{1,5}.betaX = [];
cst{1,6} = {objective};
end

function [wBest,fBest] = minimizeObjectiveOnGrid(optiProb,dij,cst,wGrid)
fGrid = zeros(numel(wGrid),1);
for i = 1:numel(wGrid)
    fGrid(i) = optiProb.matRad_objectiveFunction(wGrid(i),dij,cst);
end
[fBest,ixBest] = min(fGrid);
wBest = wGrid(ixBest);
end
