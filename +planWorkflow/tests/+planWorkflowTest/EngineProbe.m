classdef EngineProbe < planWorkflow.Engine
    % EngineProbe Exposes protected Engine configuration hooks for tests.

    properties
        editorTemplate = []
        editorRunConfig = []
        editorAccepted = true
        editorProgressReporter = []
        editorResumeStateFile = ''
        editorOptions = struct()
        editorWasCalled = false
        guiSupport = true
    end

    methods
        function obj = EngineProbe(config)
            obj@planWorkflow.Engine(config);
        end

        function configureStagePublic(obj,stageName,stageConfig)
            obj.configureStage(stageName,stageConfig);
        end

        function cacheKey = cacheKeyPublic(obj,tag,varargin)
            cacheKey = obj.cacheService().key(tag,varargin{:});
        end

        function cacheMetadata = cacheMetadataPublic(obj,tag,pln,varargin)
            if isempty(varargin)
                cacheMetadata = obj.cacheService().metadata(tag,pln);
            else
                cacheMetadata = obj.cacheService().metadata( ...
                    tag,pln,varargin{:});
            end
        end

        function descriptor = cacheDescriptorPublic(obj,tag,pln,varargin)
            if isempty(varargin)
                descriptor = obj.cacheService().descriptor(tag,pln);
            else
                descriptor = obj.cacheService().descriptor( ...
                    tag,pln,varargin{:});
            end
        end

        function cacheFile = cacheFilePublic(obj,tag,varargin)
            cacheFile = obj.cacheService().file(tag,varargin{:});
        end

        function tf = isCacheCompatiblePublic(obj,cached,pln,varargin)
            tf = obj.cacheService().isCompatible(cached,pln,varargin{:});
        end

        function [cacheHit,robustData] = ...
                loadCachedIntervalDoseInfluencePublic(obj,robustData)
            robustData = obj.robustDataContext(robustData);
            [cacheHit,robustData] = ...
                planWorkflow.precompute.IntervalDoseInfluence.loadCached( ...
                obj.compactDoseInfluenceContext(),robustData);
        end

        function [cacheHit,robustData] = ...
                loadCachedProbDoseInfluencePublic(obj,robustData)
            robustData = obj.robustDataContext(robustData);
            [cacheHit,robustData] = ...
                planWorkflow.precompute.ProbDoseInfluence.loadCached( ...
                obj.compactDoseInfluenceContext(),robustData);
        end

        function robustData = useIntervalDijForOptimizationPublic( ...
                obj,robustData)
            robustData = planWorkflow.precompute.IntervalDoseInfluence.useForOptimization( ...
                robustData);
        end

        function robustData = useProbDijForOptimizationPublic( ...
                obj,robustData)
            robustData = planWorkflow.precompute.ProbDoseInfluence.useForOptimization( ...
                robustData);
        end

        function tag = intervalDoseCacheTagPublic(obj,robustData)
            tag = planWorkflow.precompute.IntervalDoseInfluence.cacheTag( ...
                obj.robustDataContext(robustData));
        end

        function tag = probDoseCacheTagPublic(obj,robustData)
            tag = planWorkflow.precompute.ProbDoseInfluence.cacheTag( ...
                obj.robustDataContext(robustData));
        end

        function tag = robustDoseCacheTagPublic(obj,robustData)
            tag = obj.cacheService().robustTag(robustData);
        end

        function context = intervalCacheContextPublic(obj,robustData)
            robustData = obj.robustDataContext(robustData);
            context = ...
                planWorkflow.precompute.IntervalDoseInfluence.cacheContext( ...
                obj.compactDoseInfluenceContext(),robustData);
        end

        function context = probCacheContextPublic(obj,robustData)
            robustData = obj.robustDataContext(robustData);
            context = ...
                planWorkflow.precompute.ProbDoseInfluence.cacheContext( ...
                obj.compactDoseInfluenceContext(),robustData);
        end

        function pln = planForRobustDataPlanIndexPublic(obj,robustData,planIx)
            robustData = obj.robustDataContext(robustData);
            pln = planWorkflow.optimization.VariantPlanFactory.build( ...
                robustData,planIx);
        end

        function detail = planTaskResourceDetailPublic(obj,stageName,role, ...
                label,taskName,robustPlanId,variantId,taskOutputs)
            detail = obj.planTaskResourceDetail(stageName,role,label, ...
                taskName,robustPlanId,variantId,taskOutputs);
        end

        function prepareEffectivePlanTemplatePublic(obj)
            obj.prepareEffectivePlanTemplate();
        end

        function setGuiSupport(obj,tf)
            obj.guiSupport = logical(tf);
        end

        function setEditorResponse(obj,template,runConfig,accepted, ...
                progressReporter,resumeStateFile)
            if nargin < 5
                progressReporter = [];
            end
            if nargin < 6
                resumeStateFile = '';
            end
            obj.editorTemplate = template;
            obj.editorRunConfig = runConfig;
            obj.editorAccepted = accepted;
            obj.editorProgressReporter = progressReporter;
            obj.editorResumeStateFile = resumeStateFile;
            obj.editorWasCalled = false;
        end

        function setEffectivePlanTemplatePublic(obj,template)
            obj.setEffectivePlanTemplate(template);
        end
    end

    methods (Access = protected)
        function [template,runConfig,accepted,progressReporter, ...
                resumeStateFile] = openInteractivePlanEditor( ...
                obj,template,runConfig,options)
            obj.editorWasCalled = true;
            obj.editorOptions = options;
            if ~isempty(obj.editorTemplate)
                template = obj.editorTemplate;
            end
            if ~isempty(obj.editorRunConfig)
                runConfig = obj.editorRunConfig;
            end
            accepted = obj.editorAccepted;
            progressReporter = obj.editorProgressReporter;
            resumeStateFile = obj.editorResumeStateFile;
        end

        function tf = hasInteractiveGuiSupport(obj)
            tf = obj.guiSupport;
        end

    end

    methods
        function template = activePlanTemplatePublic(obj)
            template = obj.activePlanTemplate();
        end

        function robustData = intervalRobustDataContext(obj,robustData)
            robustData = obj.robustDataContext(robustData);
        end

        function robustData = robustDataContext(obj,robustData)
            if nargin < 2 || isempty(robustData)
                robustData = struct();
            end
            if ~isfield(robustData,'planConfig') || ...
                    isempty(robustData.planConfig)
                error('planWorkflowTest:EngineProbe:MissingRobustPlanConfig', ...
                    'Robust data must contain an explicit planConfig.');
            end
            if ~isfield(robustData,'strategy') || isempty(robustData.strategy)
                error('planWorkflowTest:EngineProbe:MissingRobustStrategy', ...
                    'Robust data must contain an explicit strategy.');
            end
        end

        function cache = cacheService(obj)
            cache = planWorkflow.cache.DoseInfluenceCacheService( ...
                obj.runConfig,obj.cachePath,@(~) []);
        end

        function context = intervalDoseInfluenceContext(obj)
            context = obj.compactDoseInfluenceContext();
        end

        function context = compactDoseInfluenceContext(obj)
            data = obj.data;
            if ~isfield(data,'quantityOpt')
                data.quantityOpt = '';
            end
            context = struct();
            context.runConfig = obj.runConfig;
            context.data = data;
            context.cache = obj.cacheService();
            context.log = @(message) [];
        end
    end
end
