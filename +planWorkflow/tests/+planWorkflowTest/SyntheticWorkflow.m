classdef SyntheticWorkflow < planWorkflow.WorkflowBase
    % SyntheticWorkflow Minimal workflow used by planWorkflow unit tests.

    methods
        function obj = SyntheticWorkflow(config)
            if nargin < 1
                config = struct();
            end
            obj@planWorkflow.WorkflowBase(config);
        end
    end

    methods (Access = protected)
        function runConfig = defaultRunConfig(~)
            runConfig = struct();
            runConfig.description = 'synthetic';
            runConfig.caseID = 'case';
            runConfig.runId = 'synthetic-run';
            runConfig.outputRootPath = tempdir;
            runConfig.cacheRootPath = fullfile(tempdir,'planWorkflow-cache');
            runConfig.analysis = planWorkflow.config.Analysis.defaults();
        end

        function runConfig = normalizeRunConfig(~,runConfig,varargin)
            runConfig.description = char(runConfig.description);
            runConfig.caseID = char(runConfig.caseID);
            runConfig.runId = char(runConfig.runId);
            runConfig.outputRootPath = char(runConfig.outputRootPath);
            runConfig.cacheRootPath = char(runConfig.cacheRootPath);
            runConfig.analysis = ...
                planWorkflow.config.Analysis.normalize(runConfig.analysis);
        end

        function fields = stageConfigFields(~,stageName)
            if strcmp(stageName,'analyze')
                defaults = planWorkflow.config.Analysis.defaults();
                fields = fieldnames(defaults)';
            else
                fields = {};
            end
        end

        function stageConfig = normalizeStageConfig(~,stageName,stageConfig)
            if strcmp(stageName,'analyze')
                stageConfig = planWorkflow.config.Analysis.normalize( ...
                    stageConfig);
            end
        end

        function runConfig = stageConfigToRunConfig(~,stageName,stageConfig)
            if strcmp(stageName,'analyze')
                runConfig = struct('analysis',stageConfig);
            else
                runConfig = stageConfig;
            end
        end

        function configurePaths(obj)
            obj.runId = char(obj.runConfig.runId);
            obj.rootPath = fullfile(obj.runConfig.outputRootPath,obj.runId);
            obj.folderPath = {obj.rootPath};
            obj.cachePath = obj.runConfig.cacheRootPath;
            obj.stateFile = fullfile(obj.rootPath,'workflow_state.mat');
            obj.dataFile = fullfile(obj.rootPath,'workflow_data.mat');
            obj.resultsFile = fullfile(obj.rootPath,'workflow_results.mat');
            obj.performanceFile = fullfile(obj.rootPath,'workflow_performance.mat');
        end

        function doPrepare(obj)
            obj.data.preparedValue = 42;
        end

        function doPrecompute(obj)
            obj.data.precomputedValue = obj.data.preparedValue + 1;
        end

        function doDosePulling(obj)
            obj.data.dosePulledValue = obj.data.precomputedValue + 1;
        end

        function doOptimize(obj)
            obj.data.optimizedValue = obj.runMeasuredPlanTask( ...
                'optimize','reference','Reference', ...
                'syntheticOptimization','','', ...
                @() obj.data.dosePulledValue + 1);
        end

        function doSampling(obj)
            obj.reportGuiStageProgress('sample',0.5, ...
                'Synthetic sampling progress.');
            obj.data.sampledValue = obj.data.optimizedValue + 1;
        end

        function doAnalyze(obj)
            if ~isfield(obj.data,'analysisCount')
                obj.data.analysisCount = 0;
            end
            obj.data.analysisCount = obj.data.analysisCount + 1;
            obj.data.results = struct( ...
                'score',obj.data.sampledValue + 1, ...
                'analysisCount',obj.data.analysisCount, ...
                'analysis',obj.runConfig.analysis);
        end
    end
end
