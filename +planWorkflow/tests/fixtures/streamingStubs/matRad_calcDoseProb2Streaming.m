function [plnOut,dijProb2Context] = matRad_calcDoseProb2Streaming( ...
        ct,cst,stf,pln,cfg)
if nargin ~= 5
    error('planWorkflowTest:StreamingStub:UnexpectedNargin', ...
        'Streaming PROB2 stub expects exactly five inputs.');
end
if isstruct(cfg) && isfield(cfg,'PrecomputedDij')
    error('planWorkflowTest:StreamingStub:UnexpectedPrecomputedDij', ...
        'planWorkflow must not pass PrecomputedDij to streaming precompute.');
end

numOfBixels = totalNumOfBixels(stf);
dijProb2 = struct();
dijProb2.expected = sparse(2,numOfBixels);
dijProb2.Omega = {sparse(numOfBixels,numOfBixels)};
dijProb2.voiSubIx = {[1;2]};
dijProb2.quantity = 'physicalDose';
dijProb2.quantityField = 'physicalDose';
dijProb2.probabilisticMode = 'PROB2';
dijProb2.stubMode = 'PROB2';
dijProb2.stubNargin = nargin;
dijProb2.streamingSize = streamingSize(dijProb2,512);
plnOut = pln;
if ~isfield(plnOut,'propOpt') || ~isstruct(plnOut.propOpt)
    plnOut.propOpt = struct();
end
plnOut.propOpt.dij_prob2 = dijProb2;
dijProb2Context = struct();
dijProb2Context.totalNumOfBixels = numOfBixels;
dijProb2Context.physicalDose = {dijProb2.expected};
dijProb2Context.numOfScenarios = 1;
dijProb2Context.scenarioModel = matRad_NominalScenario();
dijProb2Context.stubNargin = nargin;
end

function data = streamingSize(dijProb2,auxiliaryPeakBytes)
compactBytes = variableBytes(dijProb2);
data = struct();
data.compactBytes = compactBytes;
data.auxiliaryPeakBytes = auxiliaryPeakBytes;
data.totalPrecomputingBytes = compactBytes + auxiliaryPeakBytes;
data.diskCachePeakBytes = auxiliaryPeakBytes;
data.memoryTemporaryPeakBytes = 0;
data.auxiliaryPeakKind = 'diskCache';
data.secondPassStrategy = 'disk';
dijProb2.streamingSize = data;
compactBytes = variableBytes(dijProb2);
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
