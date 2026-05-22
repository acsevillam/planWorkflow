classdef StageDataLifecycle
    % StageDataLifecycle Applies explicit payload cleanup at stage boundaries.

    methods (Static)
        function [robustData,loadedFields] = ...
                materializeDoseInfluenceArtifactsForPullDose( ...
                robustData,runConfig,rootData,logFn)
            if nargin < 4
                logFn = [];
            end
            loadedFields = {};
            fieldNames = ...
                planWorkflow.resources.StageDataLifecycle.pullDoseDijFieldNames( ...
                robustData);
            if isempty(fieldNames)
                return;
            end
            contextLabel = ...
                planWorkflow.resources.StageDataLifecycle.pullDoseContextLabel( ...
                robustData);
            [robustData,loadedFields] = ...
                planWorkflow.persistence.WorkflowDataArtifact.materializeOwnerDijArtifacts( ...
                robustData,runConfig, ...
                planWorkflow.resources.StageDataLifecycle.cachePath( ...
                runConfig),rootData,fieldNames,contextLabel);
            if ~isempty(loadedFields)
                planWorkflow.resources.StageDataLifecycle.log( ...
                    logFn,sprintf('Materialized %s for %s.', ...
                    strjoin(loadedFields,', '),contextLabel));
            end
        end

        function cachePath = cachePath(runConfig)
            cachePath = [];
            if isstruct(runConfig) && isfield(runConfig,'cacheRootPath')
                cachePath = runConfig.cacheRootPath;
            end
        end

        function patch = afterStage(stageName,patch,runConfig,logFn)
            if nargin < 4
                logFn = [];
            end
            hasData = isstruct(patch) && isfield(patch,'data') && ...
                isstruct(patch.data) && ~isempty(patch.data);

            switch char(stageName)
                case 'optimize'
                    if ~hasData
                        return;
                    end
                    patch.data = ...
                        planWorkflow.results.ResultGUICompactor.compactOptimizationResults( ...
                        patch.data);
                    patch.data = ...
                        planWorkflow.resources.StageDataLifecycle.compactDoseInfluenceArtifacts( ...
                        patch.data,runConfig);
                    planWorkflow.resources.StageDataLifecycle.log( ...
                        logFn,['Compacted optimization result dose cubes ' ...
                        'and dose-influence artifacts after optimize.']);
                case {'precompute','pullDose'}
                    if hasData
                        patch.data = ...
                            planWorkflow.resources.StageDataLifecycle.compactDoseInfluenceArtifacts( ...
                            patch.data,runConfig);
                        planWorkflow.resources.StageDataLifecycle.log( ...
                            logFn,['Compacted dose-influence artifacts after ' ...
                            char(stageName) '.']);
                    end
                    planWorkflow.resources.StageDataLifecycle.releaseParallelPool( ...
                        logFn,char(stageName),runConfig);
                case 'sample'
                    if hasData
                        patch.data = ...
                            planWorkflow.resources.StageDataLifecycle.compactSamplingPayloads( ...
                            patch.data,runConfig);
                        planWorkflow.resources.StageDataLifecycle.log( ...
                            logFn,'Compacted sampling payloads after sample.');
                    end
                    planWorkflow.resources.StageDataLifecycle.releaseParallelPool( ...
                        logFn,'sample',runConfig);
                case 'analyze'
                    planWorkflow.analysis.Figures.closeWorkflowFigures();
                    if hasData
                        patch.data = ...
                            planWorkflow.resources.StageDataLifecycle.compactAnalysisPayloads( ...
                            patch.data,runConfig);
                        planWorkflow.resources.StageDataLifecycle.log( ...
                            logFn,['Closed workflow analysis figures and ' ...
                            'compacted analyzed sampling payloads.']);
                    end
            end
        end
    end

    methods (Static, Access = private)
        function fieldNames = pullDoseDijFieldNames(robustData)
            fieldNames = {};
            if ~isstruct(robustData) || ...
                    ~isfield(robustData,'planConfig') || ...
                    ~isstruct(robustData.planConfig)
                return;
            end
            planConfig = robustData.planConfig;
            if planWorkflow.resources.StageDataLifecycle.flag( ...
                    planConfig,'requiresIntervalDij')
                fieldNames = [fieldNames ...
                    {'dij_interval','dijIntervalContext'}];
            elseif planWorkflow.resources.StageDataLifecycle.flag( ...
                    planConfig,'requiresProbDij')
                fieldNames = [fieldNames {'dij_prob','dijProbContext'}];
            end
            if planWorkflow.resources.StageDataLifecycle.flag( ...
                    planConfig,'requiresNominalDij')
                fieldNames = [fieldNames {'dijNominal'}];
            end
            fieldNames = unique(fieldNames,'stable');
        end

        function tf = flag(input,fieldName)
            tf = false;
            if ~isstruct(input) || ~isfield(input,fieldName) || ...
                    isempty(input.(fieldName))
                return;
            end
            value = input.(fieldName);
            if ~(islogical(value) || isnumeric(value))
                return;
            end
            tf = isscalar(value) && logical(value);
        end

        function label = pullDoseContextLabel(robustData)
            label = 'pullDose robust plan';
            if ~isstruct(robustData) || ...
                    ~isfield(robustData,'planConfig') || ...
                    ~isstruct(robustData.planConfig)
                return;
            end
            if isfield(robustData.planConfig,'label') && ...
                    ~isempty(robustData.planConfig.label)
                label = ['pullDose robust plan ' ...
                    char(robustData.planConfig.label)];
                return;
            end
            if isfield(robustData.planConfig,'id') && ...
                    ~isempty(robustData.planConfig.id)
                label = ['pullDose robust plan ' ...
                    char(robustData.planConfig.id)];
            end
        end

        function data = compactDoseInfluenceArtifacts(data,runConfig)
            cachePath = ...
                planWorkflow.resources.StageDataLifecycle.cachePath( ...
                runConfig);
            if isempty(cachePath)
                return;
            end
            data = ...
                planWorkflow.persistence.WorkflowDataArtifact.compactForStageBoundary( ...
                data,runConfig,cachePath);
        end

        function data = compactAnalysisPayloads(data,runConfig)
            if isfield(data,'sampling')
                data.sampling = ...
                    planWorkflow.persistence.SamplingPayloadArtifact.compactSamplingData( ...
                    data.sampling,runConfig, ...
                    planWorkflow.resources.StageDataLifecycle.cachePath( ...
                    runConfig));
            end
            if isfield(data,'results') && isstruct(data.results) && ...
                    isfield(data.results,'sampling')
                data.results.sampling = ...
                    planWorkflow.resources.StageDataLifecycle.compactSamplingResults( ...
                    data.results.sampling);
            end
        end

        function data = compactSamplingPayloads(data,runConfig)
            if ~isfield(data,'sampling')
                return;
            end
            data.sampling = ...
                planWorkflow.persistence.SamplingPayloadArtifact.compactSamplingData( ...
                data.sampling,runConfig, ...
                planWorkflow.resources.StageDataLifecycle.cachePath( ...
                runConfig));
        end

        function samplingResults = compactSamplingResults(samplingResults)
            if ~isstruct(samplingResults) || isempty(samplingResults)
                return;
            end
            if isfield(samplingResults,'reference')
                samplingResults.reference = ...
                    planWorkflow.results.SamplingDataCompactor.compactPlanSamplingResults( ...
                    samplingResults.reference);
            end
            if isfield(samplingResults,'robust') && iscell(samplingResults.robust)
                for resultIx = 1:numel(samplingResults.robust)
                    samplingResults.robust{resultIx} = ...
                        planWorkflow.results.SamplingDataCompactor.compactPlanSamplingResults( ...
                        samplingResults.robust{resultIx});
                end
            end
        end

        function releaseParallelPool(logFn,stageName,runConfig)
            if ~planWorkflow.resources.StageDataLifecycle.shouldReleaseParallelPool( ...
                    runConfig)
                return;
            end
            if exist('gcp','file') ~= 2
                return;
            end
            pool = gcp('nocreate');
            if isempty(pool)
                return;
            end
            workerCount = pool.NumWorkers;
            delete(pool);
            planWorkflow.resources.StageDataLifecycle.log( ...
                logFn,sprintf(['Released parallel pool with %d worker(s) ' ...
                'after %s.'],workerCount,char(stageName)));
        end

        function tf = shouldReleaseParallelPool(runConfig)
            resources = planWorkflow.config.Resources.fromRunConfig( ...
                runConfig);
            tf = isfield(resources,'doseCalculation') && ...
                isfield(resources.doseCalculation,'releasePoolAfterStage') && ...
                logical(resources.doseCalculation.releasePoolAfterStage);
        end

        function log(logFn,message)
            if isempty(logFn)
                return;
            end
            try
                logFn(message);
            catch
            end
        end
    end
end
