classdef SamplingAnalysisWorkflow < planWorkflow.WorkflowBase
    % SamplingAnalysisWorkflow Exercises sampling analysis rehydration.

    methods
        function obj = SamplingAnalysisWorkflow(config)
            if nargin < 1
                config = struct();
            end
            obj@planWorkflow.WorkflowBase(config);
        end
    end

    methods (Access = protected)
        function runConfig = defaultRunConfig(~)
            runConfig = struct();
            runConfig.description = 'sampling-analysis';
            runConfig.caseID = 'case';
            runConfig.runId = 'sampling-analysis-run';
            runConfig.outputRootPath = tempdir;
            runConfig.cacheRootPath = fullfile(tempdir,'planWorkflow-cache');
            runConfig.analysis = planWorkflow.config.Analysis.defaults();
            runConfig.analysis.figures.save = false;
            runConfig.analysis.figures.visible = 'off';
            runConfig.quantityOpt = 'physicalDose';
        end

        function runConfig = normalizeRunConfig(~,runConfig,varargin)
            runConfig.description = char(runConfig.description);
            runConfig.caseID = char(runConfig.caseID);
            runConfig.runId = char(runConfig.runId);
            runConfig.outputRootPath = char(runConfig.outputRootPath);
            runConfig.cacheRootPath = char(runConfig.cacheRootPath);
            runConfig.analysis = ...
                planWorkflow.config.Analysis.normalize(runConfig.analysis);
            runConfig.quantityOpt = char(runConfig.quantityOpt);
        end

        function configurePaths(obj)
            obj.runId = char(obj.runConfig.runId);
            obj.rootPath = fullfile(obj.runConfig.outputRootPath,obj.runId);
            obj.folderPath = {obj.rootPath};
            obj.cachePath = obj.runConfig.cacheRootPath;
            obj.stateFile = fullfile(obj.rootPath,'workflow_state.mat');
            obj.dataFile = fullfile(obj.rootPath,'workflow_data.mat');
            obj.resultsFile = fullfile(obj.rootPath,'workflow_results.mat');
            obj.performanceFile = fullfile(obj.rootPath, ...
                'workflow_performance.mat');
        end

        function doPrepare(obj)
            obj.data.quantityOpt = obj.runConfig.quantityOpt;
        end

        function doPrecompute(obj)
            obj.data.precomputedValue = 1;
        end

        function doDosePulling(obj)
            obj.data.dosePulledValue = obj.data.precomputedValue + 1;
        end

        function doOptimize(obj)
            obj.data.optimizedValue = obj.data.dosePulledValue + 1;
        end

        function doSampling(obj)
            obj.data.sampling = ...
                planWorkflowTest.SamplingAnalysisWorkflow.samplingDataFixture();
        end

        function doAnalyze(obj)
            context = struct();
            context.runConfig = obj.runConfig;
            context.data = obj.data;
            context.rootPath = obj.rootPath;
            context.log = @(message) obj.log(message);

            [samplingResults,samplingData] = ...
                planWorkflow.analysis.AnalysisService.analyzeSamplingData( ...
                context,obj.data.sampling);
            obj.data.sampling = samplingData;

            analysisCount = 0;
            if isfield(obj.data,'results') && ...
                    isfield(obj.data.results,'analysisCount')
                analysisCount = obj.data.results.analysisCount;
            end
            obj.data.results = struct();
            obj.data.results.analysisCount = analysisCount + 1;
            obj.data.results.sampling = samplingResults;
        end
    end

    methods (Static, Access = private)
        function samplingData = samplingDataFixture()
            pln = struct();
            pln.numOfFractions = 1;
            pln.propStf = struct('isoCenter',[0 0 1]);
            pln.subIx = (1:4)';
            pln.multScen = struct('totNumScen',2);

            ct = struct();
            ct.cubeDim = [2 2 1];
            ct.numOfCtScen = 1;
            ct.refScen = 1;
            ct.z = 1;
            ct.resolution = struct('z',1);

            cst = cell(1,6);
            cst{1,1} = 1;
            cst{1,2} = 'CTV';
            cst{1,3} = 'TARGET';
            cst{1,4} = {1:4};
            cst{1,5} = struct();
            cst{1,6} = [];

            reference = ...
                planWorkflowTest.SamplingAnalysisWorkflow.sampleFixture( ...
                'reference',pln,1);
            robust = ...
                planWorkflowTest.SamplingAnalysisWorkflow.sampleFixture( ...
                'robust',pln,2);

            samplingData = struct();
            samplingData.scenarioMode = 'impScen_permuted5';
            samplingData.samplingConfig = struct('sampling_size',2);
            samplingData.scenarioBasis = struct('scenarioMode', ...
                'impScen_permuted5');
            samplingData.structureNormalizationReport = struct();
            samplingData.ctScenProb = [];
            samplingData.ct = ct;
            samplingData.cst = cst;
            samplingData.multScen = struct('totNumScen',2);
            samplingData.reference = reference;
            samplingData.robust = {robust};
        end

        function sample = sampleFixture(label,pln,scale)
            sample = struct();
            sample.label = char(label);
            sample.pln = pln;
            sample.caSamp = repmat(struct('qi',scale,'dvh',scale),1,2);
            sample.mSampDose = single(scale * reshape(1:8,4,2));
            sample.resultGUINomScen = struct( ...
                'physicalDose',scale * ones(2,2,1));
        end
    end
end
