function [plnOut,dijProbContext] = matRad_calculateProbabilisticQuantities( ...
        ct,cst,stf,pln,cfg)
if nargin ~= 5
    error('planWorkflowTest:ScenarioBatchStub:UnexpectedNargin', ...
        'Scenario-batch PROB stub expects exactly five inputs.');
end
if isstruct(cfg) && isfield(cfg,'PrecomputedDij')
    error('planWorkflowTest:ScenarioBatchStub:UnexpectedPrecomputedDij', ...
        ['planWorkflow must not pass PrecomputedDij to scenario-batch ' ...
         'precompute.']);
end

numOfBixels = totalNumOfBixels(stf);
dijProb = struct();
dijProb.expected = sparse(2,numOfBixels);
dijProb.Omega = {sparse(numOfBixels,numOfBixels)};
dijProb.voiSubIx = {[1;2]};
dijProb.quantity = 'physicalDose';
dijProb.quantityField = 'physicalDose';
dijProb.probabilisticMode = 'PROB';
dijProb.stubMode = 'PROB';
dijProb.stubNargin = nargin;
dijProb.precomputeMode = 'scenario-batch';
dijProb.precomputeSize = precomputeSize(dijProb,512);
plnOut = pln;
if ~isfield(plnOut,'propOpt') || ~isstruct(plnOut.propOpt)
    plnOut.propOpt = struct();
end
plnOut.propOpt.dij_prob = dijProb;
dijProbContext = struct();
dijProbContext.totalNumOfBixels = numOfBixels;
dijProbContext.physicalDose = {dijProb.expected};
dijProbContext.numOfScenarios = 1;
dijProbContext.scenarioModel = matRad_NominalScenario();
dijProbContext.stubNargin = nargin;
end

function data = precomputeSize(dijProb,auxiliaryPeakBytes)
compactBytes = variableBytes(dijProb);
data = struct();
data.compactBytes = compactBytes;
data.auxiliaryPeakBytes = auxiliaryPeakBytes;
data.totalPrecomputingBytes = compactBytes + auxiliaryPeakBytes;
data.diskCachePeakBytes = auxiliaryPeakBytes;
data.memoryTemporaryPeakBytes = 0;
data.auxiliaryPeakKind = 'diskCache';
data.secondPassStrategy = 'disk';
dijProb.precomputeSize = data;
compactBytes = variableBytes(dijProb);
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
