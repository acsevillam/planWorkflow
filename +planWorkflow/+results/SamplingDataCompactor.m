classdef SamplingDataCompactor
    % SamplingDataCompactor Removes analyzed sampling payloads from snapshots.

    methods (Static)
        function samplingData = compactSamplingData(samplingData)
            if ~isstruct(samplingData) || isempty(samplingData)
                return;
            end

            samplingData = ...
                planWorkflow.results.SamplingDataCompactor.attachRootSummary( ...
                samplingData);

            removeFields = {'ct','cst','multScen'};
            for fieldIx = 1:numel(removeFields)
                fieldName = removeFields{fieldIx};
                if isfield(samplingData,fieldName)
                    samplingData = rmfield(samplingData,fieldName);
                end
            end

            if isfield(samplingData,'reference')
                samplingData.reference = ...
                    planWorkflow.results.SamplingDataCompactor.compactSample( ...
                    samplingData.reference);
            end
            if isfield(samplingData,'robust') && iscell(samplingData.robust)
                for sampleIx = 1:numel(samplingData.robust)
                    samplingData.robust{sampleIx} = ...
                        planWorkflow.results.SamplingDataCompactor.compactSample( ...
                        samplingData.robust{sampleIx});
                end
            end
        end

        function sample = compactSample(sample)
            if ~isstruct(sample) || isempty(sample)
                return;
            end
            sample.samplingPayloadSummary = ...
                planWorkflow.results.SamplingDataCompactor.sampleSummary( ...
                sample);
            heavyFields = {'mSampDose','caSamp','resultGUINomScen'};
            for fieldIx = 1:numel(heavyFields)
                fieldName = heavyFields{fieldIx};
                if isfield(sample,fieldName)
                    sample = rmfield(sample,fieldName);
                end
            end
        end

        function planResults = compactPlanSamplingResults(planResults)
            if ~isstruct(planResults) || isempty(planResults)
                return;
            end
            if isfield(planResults,'doseStat')
                planResults.doseStat = ...
                    planWorkflow.results.SamplingDataCompactor.compactDoseStat( ...
                    planResults.doseStat);
            end
        end

        function doseStat = compactDoseStat(doseStat)
            if ~isstruct(doseStat) || isempty(doseStat)
                return;
            end

            doseStat.summary = ...
                planWorkflow.results.SamplingDataCompactor.doseStatSummary( ...
                doseStat);
            doseStat = ...
                planWorkflow.results.SamplingDataCompactor.removeFields( ...
                doseStat,{'meanCube','stdCube','meanCubeW','stdCubeW', ...
                'sampleMask'});

            if isfield(doseStat,'gammaAnalysis') && ...
                    isstruct(doseStat.gammaAnalysis)
                doseStat.gammaAnalysis = ...
                    planWorkflow.results.SamplingDataCompactor.removeFields( ...
                    doseStat.gammaAnalysis, ...
                    {'cube1','cube2','gammaCube','sourceCube'});
            end
            if isfield(doseStat,'robustnessAnalysis') && ...
                    isstruct(doseStat.robustnessAnalysis)
                doseStat.robustnessAnalysis = ...
                    planWorkflow.results.SamplingDataCompactor.compactRobustnessAnalysis( ...
                    doseStat.robustnessAnalysis);
            end
        end
    end

    methods (Static, Access = private)
        function samplingData = attachRootSummary(samplingData)
            summary = struct();
            if isfield(samplingData,'ct') && isstruct(samplingData.ct)
                summary.ct = ...
                    planWorkflow.results.SamplingDataCompactor.ctSummary( ...
                    samplingData.ct);
            end
            if isfield(samplingData,'cst') && iscell(samplingData.cst)
                summary.structureCount = size(samplingData.cst,1);
            end
            if isfield(samplingData,'multScen') && ...
                    isstruct(samplingData.multScen)
                summary.multScenClass = class(samplingData.multScen);
                if isfield(samplingData.multScen,'totNumScen')
                    summary.totNumScen = samplingData.multScen.totNumScen;
                end
            end
            if ~isempty(fieldnames(summary))
                samplingData.samplingPayloadSummary = summary;
            end
        end

        function summary = ctSummary(ct)
            summary = struct();
            if isfield(ct,'cubeDim')
                summary.cubeDim = ct.cubeDim;
            end
            if isfield(ct,'numOfCtScen')
                summary.numOfCtScen = ct.numOfCtScen;
            end
            if isfield(ct,'refScen')
                summary.refScen = ct.refScen;
            end
        end

        function summary = sampleSummary(sample)
            summary = struct();
            if isfield(sample,'mSampDose') && isnumeric(sample.mSampDose)
                summary.sampleDoseSize = size(sample.mSampDose);
                info = whos('sample');
                summary.sampleStructBytesBeforeCompaction = info.bytes;
            end
            if isfield(sample,'caSamp')
                summary.numSamples = numel(sample.caSamp);
            elseif isfield(sample,'pln') && isstruct(sample.pln) && ...
                    isfield(sample.pln,'multScen') && ...
                    isfield(sample.pln.multScen,'totNumScen')
                summary.numSamples = sample.pln.multScen.totNumScen;
            end
            if isfield(sample,'pln') && isstruct(sample.pln) && ...
                    isfield(sample.pln,'subIx')
                summary.numSampleVoxels = numel(sample.pln.subIx);
            end
        end

        function summary = doseStatSummary(doseStat)
            summary = struct();
            summary.meanCubeWMax = ...
                planWorkflow.results.SamplingDataCompactor.finiteMaxField( ...
                doseStat,'meanCubeW');
            summary.stdCubeWMax = ...
                planWorkflow.results.SamplingDataCompactor.finiteMaxField( ...
                doseStat,'stdCubeW');
            if isfield(doseStat,'sampleCoverageFraction')
                summary.sampleCoverageFraction = ...
                    doseStat.sampleCoverageFraction;
            end
            if isfield(doseStat,'gammaAnalysis') && ...
                    isstruct(doseStat.gammaAnalysis) && ...
                    isfield(doseStat.gammaAnalysis,'gammaPassRate')
                summary.gammaPassRate = ...
                    doseStat.gammaAnalysis.gammaPassRate;
            end
        end

        function value = finiteMaxField(input,fieldName)
            value = NaN;
            if ~isstruct(input) || ~isfield(input,fieldName)
                return;
            end
            fieldValue = input.(fieldName);
            if ~isnumeric(fieldValue)
                return;
            end
            finiteValues = fieldValue(isfinite(fieldValue));
            if ~isempty(finiteValues)
                value = max(finiteValues(:));
            end
        end

        function input = compactRobustnessAnalysis(input)
            input = ...
                planWorkflow.results.SamplingDataCompactor.removeFields( ...
                input,{'sourceCube','meanCube','stdCube','sampleMask'});
            fields = fieldnames(input);
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                value = input.(fieldName);
                if isstruct(value)
                    input.(fieldName) = ...
                        planWorkflow.results.SamplingDataCompactor.compactRobustnessAnalysis( ...
                        value);
                end
            end
        end

        function input = removeFields(input,fields)
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                if isstruct(input) && isfield(input,fieldName)
                    input = rmfield(input,fieldName);
                end
            end
        end
    end
end
