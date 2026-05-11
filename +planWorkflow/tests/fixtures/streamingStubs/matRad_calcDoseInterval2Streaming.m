function [plnOut,dijIntervalContext] = matRad_calcDoseInterval2Streaming( ...
        ct,cst,stf,pln,cfg)
if nargin ~= 5
    error('planWorkflowTest:StreamingStub:UnexpectedNargin', ...
        'Streaming interval stubs expect exactly five inputs.');
end
assertNoPrecomputedDij(cfg);
[plnOut,dijIntervalContext] = intervalStubOutput(stf,pln,'INTERVAL2', ...
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
dijInterval.quantity = 'physicalDose';
dijInterval.quantityField = 'physicalDose';
dijInterval.stubMode = mode;
dijInterval.stubNargin = inputCount;
dijInterval.streamingSize = streamingSize(dijInterval,128);
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

function data = streamingSize(dijInterval,auxiliaryPeakBytes)
compactBytes = variableBytes(dijInterval);
data = struct();
data.compactBytes = compactBytes;
data.auxiliaryPeakBytes = auxiliaryPeakBytes;
data.totalPrecomputingBytes = compactBytes + auxiliaryPeakBytes;
data.diskCachePeakBytes = auxiliaryPeakBytes;
data.memoryTemporaryPeakBytes = 0;
data.auxiliaryPeakKind = 'diskCache';
data.secondPassStrategy = 'disk';
dijInterval.streamingSize = data;
compactBytes = variableBytes(dijInterval);
data.compactBytes = compactBytes;
data.totalPrecomputingBytes = compactBytes + auxiliaryPeakBytes;
end

function bytes = variableBytes(value) %#ok<INUSD>
info = whos('value');
bytes = double(info.bytes);
end

function numOfBixels = totalNumOfBixels(stf)
if isstruct(stf) && isfield(stf,'totalNumOfBixels')
    numOfBixels = sum([stf.totalNumOfBixels]);
else
    numOfBixels = 1;
end
end
