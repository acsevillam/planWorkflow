function [plnOut,dijIntervalContext] = matRad_calcDoseInterval( ...
        ct,cst,stf,pln,varargin)
if nargin ~= 5
    error('planWorkflowTest:ScenarioBatchStub:UnexpectedNargin', ...
        'Scenario-batch interval stub expects exactly five inputs.');
end
cfg = varargin{1};
if isstruct(cfg) && isfield(cfg,'PrecomputedDij')
    error('planWorkflowTest:ScenarioBatchStub:UnexpectedPrecomputedDij', ...
        ['planWorkflow must not pass PrecomputedDij to scenario-batch ' ...
         'precompute.']);
end
if ~isstruct(cfg) || ~isfield(cfg,'IntervalMode') || ...
        isempty(cfg.IntervalMode)
    error('planWorkflowTest:ScenarioBatchStub:MissingIntervalMode', ...
        'Scenario-batch interval stub requires cfg.IntervalMode.');
end
[plnOut,dijIntervalContext] = intervalStubOutput( ...
    stf,pln,char(cfg.IntervalMode),nargin);
end

function [plnOut,dijIntervalContext] = intervalStubOutput(stf,pln,mode, ...
        inputCount)
numOfBixels = totalNumOfBixels(stf);
dijInterval = struct();
dijInterval.center = sparse(2,numOfBixels);
dijInterval.radius = sparse(2,numOfBixels);
if strcmp(mode,'INTERVAL3')
    dijInterval.OARSubIx = [1;2];
    dijInterval.OARRadiusFactor = {sparse(numOfBixels,1)};
    dijInterval.OARRadiusRank = 1;
end
dijInterval.quantity = 'physicalDose';
dijInterval.quantityField = 'physicalDose';
dijInterval.intervalMode = mode;
dijInterval.stubMode = mode;
dijInterval.stubNargin = inputCount;
dijInterval.precomputeMode = 'scenario-batch';
dijInterval.precomputeSize = precomputeSize(dijInterval,auxiliaryBytes(mode));
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

function bytes = auxiliaryBytes(mode)
if strcmp(mode,'INTERVAL3')
    bytes = 256;
else
    bytes = 128;
end
end

function data = precomputeSize(dijInterval,auxiliaryPeakBytes)
compactBytes = variableBytes(dijInterval);
data = struct();
data.compactBytes = compactBytes;
data.auxiliaryPeakBytes = auxiliaryPeakBytes;
data.totalPrecomputingBytes = compactBytes + auxiliaryPeakBytes;
data.diskCachePeakBytes = auxiliaryPeakBytes;
data.memoryTemporaryPeakBytes = 0;
data.auxiliaryPeakKind = 'diskCache';
data.secondPassStrategy = 'disk';
dijInterval.precomputeSize = data;
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
