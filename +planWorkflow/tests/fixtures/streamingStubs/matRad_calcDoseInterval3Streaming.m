function [plnOut,dijIntervalContext] = matRad_calcDoseInterval3Streaming( ...
        ct,cst,stf,pln,cfg)
if nargin ~= 5
    error('planWorkflowTest:StreamingStub:UnexpectedNargin', ...
        'Streaming interval stubs expect exactly five inputs.');
end
assertNoPrecomputedDij(cfg);
[plnOut,dijIntervalContext] = intervalStubOutput(stf,pln,'INTERVAL3', ...
    nargin);
end

function assertNoPrecomputedDij(cfg)
if isstruct(cfg) && isfield(cfg,'PrecomputedDij')
    error('planWorkflowTest:StreamingStub:UnexpectedPrecomputedDij', ...
        'planWorkflow must not pass PrecomputedDij to streaming precompute.');
end
end

function [plnOut,dijIntervalContext] = intervalStubOutput(stf,pln,mode, ...
        inputCount)
numOfBixels = totalNumOfBixels(stf);
dijInterval = struct();
dijInterval.center = sparse(2,numOfBixels);
dijInterval.radius = sparse(2,numOfBixels);
dijInterval.OARSubIx = [1;2];
dijInterval.OARRadiusFactor = {sparse(numOfBixels,1)};
dijInterval.OARRadiusRank = 1;
dijInterval.quantity = 'physicalDose';
dijInterval.quantityField = 'physicalDose';
dijInterval.stubMode = mode;
dijInterval.stubNargin = inputCount;
plnOut = pln;
if ~isfield(plnOut,'propOpt') || ~isstruct(plnOut.propOpt)
    plnOut.propOpt = struct();
end
plnOut.propOpt.dij_interval = dijInterval;
dijIntervalContext = struct();
dijIntervalContext.totalNumOfBixels = numOfBixels;
dijIntervalContext.physicalDose = {dijInterval.center};
dijIntervalContext.numOfScenarios = 1;
dijIntervalContext.scenarioModel = matRad_NominalScenario();
dijIntervalContext.stubNargin = inputCount;
end

function numOfBixels = totalNumOfBixels(stf)
if isstruct(stf) && isfield(stf,'totalNumOfBixels')
    numOfBixels = sum([stf.totalNumOfBixels]);
else
    numOfBixels = 1;
end
end
