function tests = testPlanOptimizationService
tests = functiontests(localfunctions);
end

function testWarmStartCompatibilityDependsOnDijShape(testCase)
stubCleanup = installFluenceOptimizationStub(testCase); %#ok<NASGU>
warningCleanup = suppressWarmStartWarning(); %#ok<NASGU>
runConfig = planOptimizationRunConfig();
weights = [1; 2; 3];
radiationModes = {'photons','protons','carbon','helium'};
quantities = {'physicalDose','effect','RBExD'};

for modeIx = 1:numel(radiationModes)
    for quantityIx = 1:numel(quantities)
        pln = planStruct(radiationModes{modeIx},quantities{quantityIx}, ...
            true);

        compatibleResult = ...
            planWorkflow.optimization.PlanOptimizationService.runFluenceOptimization( ...
            runConfig,numericDij(),{},pln,weights);
        verifyTrue(testCase,compatibleResult.usedWarmStart, ...
            sprintf('Expected warm start for %s/%s numeric dij.', ...
            radiationModes{modeIx},quantities{quantityIx}));
        verifyEqual(testCase,compatibleResult.warmStartValue,weights);

        incompatibleResult = ...
            planWorkflow.optimization.PlanOptimizationService.runFluenceOptimization( ...
            runConfig,cellBiologicalDij(),{},pln,weights);
        verifyFalse(testCase,incompatibleResult.usedWarmStart, ...
            sprintf('Expected no warm start for %s/%s cell dij.', ...
            radiationModes{modeIx},quantities{quantityIx}));
        verifyEmpty(testCase,incompatibleResult.warmStartValue);
    end
end
end

function testNonBiologicalWarmStartIsPassedForAllLabels(testCase)
stubCleanup = installFluenceOptimizationStub(testCase); %#ok<NASGU>
runConfig = planOptimizationRunConfig();
weights = [4; 5];
labels = {'photons','protons','carbon','helium'};
quantities = {'physicalDose','effect','RBExD'};

for modeIx = 1:numel(labels)
    for quantityIx = 1:numel(quantities)
        pln = planStruct(labels{modeIx},quantities{quantityIx},false);
        resultGUI = ...
            planWorkflow.optimization.PlanOptimizationService.runFluenceOptimization( ...
            runConfig,cellBiologicalDij(),{},pln,weights);

        verifyTrue(testCase,resultGUI.usedWarmStart);
        verifyEqual(testCase,resultGUI.warmStartValue,weights);
    end
end
end

function testIncompatibleBiologicalDijSkipsWarmStart(testCase)
stubCleanup = installFluenceOptimizationStub(testCase); %#ok<NASGU>
warningCleanup = suppressWarmStartWarning(); %#ok<NASGU>
runConfig = planOptimizationRunConfig();
pln = planStruct('carbon','RBExD',true);
weights = [7; 8];

missingBxResult = ...
    planWorkflow.optimization.PlanOptimizationService.runFluenceOptimization( ...
    runConfig,missingBxDij(),{},pln,weights);
mismatchedSizeResult = ...
    planWorkflow.optimization.PlanOptimizationService.runFluenceOptimization( ...
    runConfig,mismatchedBiologicalDij(),{},pln,weights);
nonnumericResult = ...
    planWorkflow.optimization.PlanOptimizationService.runFluenceOptimization( ...
    runConfig,nonnumericBxDij(),{},pln,weights);

verifyFalse(testCase,missingBxResult.usedWarmStart);
verifyFalse(testCase,mismatchedSizeResult.usedWarmStart);
verifyFalse(testCase,nonnumericResult.usedWarmStart);
end

function testWarmStartWarningIncludesReasonAndSizes(testCase)
stubCleanup = installFluenceOptimizationStub(testCase); %#ok<NASGU>
runConfig = planOptimizationRunConfig();
pln = planStruct('diagnosticRadiation','diagnosticQuantity',true);
lastwarn('');

resultGUI = ...
    planWorkflow.optimization.PlanOptimizationService.runFluenceOptimization( ...
    runConfig,nonnumericBxDij(),{},pln,[1; 2]);

[message,identifier] = lastwarn();
verifyFalse(testCase,resultGUI.usedWarmStart);
verifyEqual(testCase,identifier, ...
    'planWorkflow:optimization:WarmStartSkipped');
verifyTrue(testCase,contains(message,'reason=nonNumericAxBx'));
verifyTrue(testCase,contains(message,'dij.ax size=[2 3]'));
verifyTrue(testCase,contains(message,'dij.bx size=[1 11]'));
end

function testObjectBioParamUsesSameCompatibilityPolicy(testCase)
stubCleanup = installFluenceOptimizationStub(testCase); %#ok<NASGU>
warningCleanup = suppressWarmStartWarning(); %#ok<NASGU>
runConfig = planOptimizationRunConfig();
pln = planStruct('carbon','RBExD',true);
pln.bioParam = PlanWorkflowTestBioParam(true,'RBExD');
weights = [9; 10];

cellResult = ...
    planWorkflow.optimization.PlanOptimizationService.runFluenceOptimization( ...
    runConfig,cellBiologicalDij(),{},pln,weights);
numericResult = ...
    planWorkflow.optimization.PlanOptimizationService.runFluenceOptimization( ...
    runConfig,numericDij(),{},pln,weights);

verifyFalse(testCase,cellResult.usedWarmStart);
verifyEmpty(testCase,cellResult.warmStartValue);
verifyTrue(testCase,numericResult.usedWarmStart);
verifyEqual(testCase,numericResult.warmStartValue,weights);
end

function testEmptyInitialWeightsAreNeverPassed(testCase)
stubCleanup = installFluenceOptimizationStub(testCase); %#ok<NASGU>
runConfig = planOptimizationRunConfig();
pln = planStruct('protons','physicalDose',false);

resultGUI = ...
    planWorkflow.optimization.PlanOptimizationService.runFluenceOptimization( ...
    runConfig,numericDij(),{},pln,[]);

verifyFalse(testCase,resultGUI.usedWarmStart);
verifyEmpty(testCase,resultGUI.warmStartValue);
end

function testOptimizerOptionsAreForwardedToMatRadPlan(testCase)
stubCleanup = installFluenceOptimizationStub(testCase); %#ok<NASGU>
runConfig = planOptimizationRunConfig();
runConfig.optimizerOptions = struct('max_iter',4);
pln = planStruct('photons','physicalDose',false);

resultGUI = ...
    planWorkflow.optimization.PlanOptimizationService.runFluenceOptimization( ...
    runConfig,numericDij(),{},pln,[]);

verifyEqual(testCase,resultGUI.optimizerOptions.max_iter,4);
end

function testDosePullingStillProvidesWarmStartToOptimizationBoundary(testCase)
stubCleanup = installFluenceOptimizationStub(testCase); %#ok<NASGU>
warningCleanup = suppressWarmStartWarning(); %#ok<NASGU>
runConfig = dosePullingRunConfig();
dij = cellBiologicalDij();
ct = struct();
cst = referenceDosePullingCst();
stf = struct();
pln = planStruct('carbon','RBExD',true);
seenInitialWeights = {};
matRadWarmStartFlags = false(1,0);
context = planWorkflow.precompute.DosePulling.context( ...
    runConfig,@runOptimization,@runAnalysis,@unusedMetrics, ...
    @unusedPolicy,@logMessage);

[~,report] = planWorkflow.precompute.DosePulling.runReference( ...
    context,ct,cst,dij,stf,pln);

verifyEqual(testCase,numel(seenInitialWeights),2);
verifyEmpty(testCase,seenInitialWeights{1});
verifyEqual(testCase,seenInitialWeights{2},[10; 20]);
verifyEqual(testCase,matRadWarmStartFlags,[false false]);
verifyTrue(testCase,report.converged);
verifyEqual(testCase,report.iterations,1);

    function resultGUI = runOptimization(dijIn,cstIn,plnIn,initialWeights)
        seenInitialWeights{end + 1} = initialWeights;
        resultGUI = ...
            planWorkflow.optimization.PlanOptimizationService.runFluenceOptimization( ...
            runConfig,dijIn,cstIn,plnIn,initialWeights);
        matRadWarmStartFlags(end + 1) = resultGUI.usedWarmStart;
    end

    function [resultGUI,dvh,qi] = runAnalysis( ...
            ~,~,~,~,resultGUI,~)
        dvh = [];
        if numel(seenInitialWeights) > 1
            cov1 = 1.0;
        else
            cov1 = 0.5;
        end
        qi = struct('name','CTV','COV1',cov1);
    end
end

function runConfig = planOptimizationRunConfig()
runConfig = struct('optimizer','IPOPT');
end

function runConfig = dosePullingRunConfig()
runConfig = planOptimizationRunConfig();
runConfig.dose_pulling_strategy = 'Threshold';
runConfig.dose_pulling1_target = {'CTV'};
runConfig.dose_pulling1_criteria = {'COV1'};
runConfig.dose_pulling1_limit = 0.9;
runConfig.dose_pulling1_start = 0;
runConfig.dose_pulling_max_iter = 1;
runConfig.dose_pulling_use_warm_start = true;
end

function pln = planStruct(radiationMode,quantityOpt,bioOpt)
pln = struct();
pln.radiationMode = char(radiationMode);
pln.bioParam = struct('bioOpt',logical(bioOpt), ...
    'quantityOpt',char(quantityOpt));
pln.propOpt = struct();
end

function dij = numericDij()
dij = struct();
dij.ax = zeros(2,3);
dij.bx = ones(2,3);
end

function dij = cellBiologicalDij()
dij = struct();
dij.ax = {zeros(2,3)};
dij.bx = {ones(2,3)};
end

function dij = missingBxDij()
dij = struct();
dij.ax = zeros(2,3);
end

function dij = mismatchedBiologicalDij()
dij = struct();
dij.ax = zeros(2,3);
dij.bx = ones(3,2);
end

function dij = nonnumericBxDij()
dij = struct();
dij.ax = zeros(2,3);
dij.bx = 'not numeric';
end

function cst = referenceDosePullingCst()
objective = struct( ...
    'parameters',{{1}}, ...
    'penalty',1, ...
    'dosePulling',true, ...
    'pullingStep',1, ...
    'objectivePullingRate',{{1}}, ...
    'penaltyPullingRate',0);
cst = cell(1,6);
cst{1,2} = 'CTV';
cst{1,4} = {1};
cst{1,6} = {objective};
end

function metrics = unusedMetrics(varargin)
metrics = struct();
end

function tf = unusedPolicy(varargin)
tf = false;
end

function logMessage(varargin)
end

function cleanup = suppressWarmStartWarning()
previousState = warning('off', ...
    'planWorkflow:optimization:WarmStartSkipped');
cleanup = onCleanup(@() warning(previousState));
end

function cleanup = installFluenceOptimizationStub(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
stubFile = fullfile(fixture.Folder,'matRad_fluenceOptimization.m');
bioParamClassFile = fullfile(fixture.Folder,'PlanWorkflowTestBioParam.m');
stubText = sprintf([ ...
    'function resultGUI = matRad_fluenceOptimization(~,~,pln,varargin)\n' ...
    'resultGUI = struct();\n' ...
    'resultGUI.usedWarmStart = ~isempty(varargin);\n' ...
    'resultGUI.inputCount = nargin;\n' ...
    'resultGUI.w = [10; 20];\n' ...
    'resultGUI.warmStartValue = [];\n' ...
    'if ~isempty(varargin)\n' ...
    '    resultGUI.warmStartValue = varargin{1};\n' ...
    'end\n' ...
    'resultGUI.radiationMode = localField(pln,''radiationMode'');\n' ...
    'resultGUI.quantityOpt = localBioParamField(pln,''quantityOpt'');\n' ...
    'resultGUI.optimizerOptions = pln.propOpt.optimizerOptions;\n' ...
    'end\n' ...
    'function value = localBioParamField(pln,fieldName)\n' ...
    'value = ''<unknown>'';\n' ...
    'if localHasMember(pln,''bioParam'')\n' ...
    '    bioParam = pln.bioParam;\n' ...
    '    value = localField(bioParam,fieldName);\n' ...
    'end\n' ...
    'end\n' ...
    'function value = localField(s,fieldName)\n' ...
    'value = ''<unknown>'';\n' ...
    'if localHasMember(s,fieldName)\n' ...
    '    value = s.(fieldName);\n' ...
    'end\n' ...
    'end\n' ...
    'function tf = localHasMember(s,fieldName)\n' ...
    'tf = (isstruct(s) && isfield(s,fieldName)) || ' ...
    '(isobject(s) && isprop(s,fieldName));\n' ...
    'end\n']);
bioParamClassText = sprintf([ ...
    'classdef PlanWorkflowTestBioParam\n' ...
    '    properties\n' ...
    '        bioOpt\n' ...
    '        quantityOpt\n' ...
    '    end\n' ...
    '    methods\n' ...
    '        function obj = PlanWorkflowTestBioParam(bioOpt,quantityOpt)\n' ...
    '            obj.bioOpt = bioOpt;\n' ...
    '            obj.quantityOpt = quantityOpt;\n' ...
    '        end\n' ...
    '    end\n' ...
    'end\n']);
writeTextFile(stubFile,stubText);
writeTextFile(bioParamClassFile,bioParamClassText);
addpath(fixture.Folder,'-begin');
clear matRad_fluenceOptimization PlanWorkflowTestBioParam;
cleanup = onCleanup(@() cleanupFluenceOptimizationStub(fixture.Folder));
end

function writeTextFile(fileName,text)
fid = fopen(fileName,'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s',char(text));
end

function cleanupFluenceOptimizationStub(folder)
try
    rmpath(folder);
catch
end
clear matRad_fluenceOptimization PlanWorkflowTestBioParam;
end
