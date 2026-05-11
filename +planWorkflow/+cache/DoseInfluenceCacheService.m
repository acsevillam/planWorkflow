classdef DoseInfluenceCacheService
    % DoseInfluenceCacheService Bound dose-influence cache operations.

    properties (SetAccess = private)
        runConfig
        cachePath
        logFn
    end

    methods
        function obj = DoseInfluenceCacheService( ...
                runConfig,cachePath,logFn)
            if nargin < 3 || isempty(logFn)
                logFn = @(message) [];
            end
            obj.runConfig = runConfig;
            obj.cachePath = cachePath;
            obj.logFn = logFn;
        end

        function dij = getOrCreate(obj,tag,ct,cst,stf,pln)
            dij = planWorkflow.cache.DoseInfluenceCache.getOrCreate( ...
                obj.runConfig,obj.cachePath,tag,ct,cst,stf, ...
                pln,obj.logFn);
        end

        function [dij,dijPrecomputingTiming,dijPrecomputingSize] = getOrCreateTimed( ...
                obj,tag,ct,cst,stf,pln,timingOptions)
            if nargin < 7
                timingOptions = [];
            end
            [dij,dijPrecomputingTiming,dijPrecomputingSize] = ...
                planWorkflow.cache.DoseInfluenceCache.getOrCreateTimed( ...
                obj.runConfig,obj.cachePath,tag,ct,cst,stf,pln, ...
                obj.logFn,timingOptions);
        end

        function dij = getOrCalculateTransient( ...
                obj,tag,robustData,ct,cst,stf,pln)
            dij = ...
                planWorkflow.cache.DoseInfluenceCache.getOrCalculateTransient( ...
                obj.runConfig,obj.cachePath,tag,robustData.strategy.name, ...
                ct,cst,stf,pln,obj.logFn);
        end

        function [dij,dijPrecomputingTiming,dijPrecomputingSize] = getOrCalculateTransientTimed( ...
                obj,tag,robustData,ct,cst,stf,pln,timingOptions)
            if nargin < 8
                timingOptions = [];
            end
            [dij,dijPrecomputingTiming,dijPrecomputingSize] = ...
                planWorkflow.cache.DoseInfluenceCache.getOrCalculateTransientTimed( ...
                obj.runConfig,obj.cachePath,tag,robustData.strategy.name, ...
                ct,cst,stf,pln,obj.logFn,timingOptions);
        end

        function cacheKey = key(obj,tag,varargin)
            cacheKey = planWorkflow.cache.DoseInfluenceCache.buildKey( ...
                obj.runConfig,tag,varargin{:});
        end

        function cacheFile = file(obj,tag,varargin)
            cacheFile = planWorkflow.cache.DoseInfluenceCache.cacheFile( ...
                obj.cachePath,obj.runConfig,tag,varargin{:});
        end

        function descriptor = descriptor(obj,tag,pln,cacheContext)
            if nargin < 3 || isempty(pln)
                pln = struct();
            end
            if nargin < 4 || isempty(cacheContext)
                cacheContext = struct();
            end
            descriptor = planWorkflow.cache.DoseInfluenceCache.descriptor( ...
                obj.runConfig,tag,pln,cacheContext);
        end

        function metadata = metadata(obj,tag,pln,cacheContext)
            if nargin < 4 || isempty(cacheContext)
                cacheContext = struct();
            end
            metadata = planWorkflow.cache.DoseInfluenceCache.metadata( ...
                obj.runConfig,tag,pln,cacheContext);
        end

        function tf = isCompatible(obj,cached,pln,tag,cacheContext)
            if nargin < 4 || isempty(tag)
                tag = 'reference';
            end
            if nargin < 5 || isempty(cacheContext)
                cacheContext = struct();
            end
            tf = planWorkflow.cache.DoseInfluenceCache.isCompatible( ...
                obj.runConfig,cached,pln,tag,cacheContext);
        end

        function tf = isIdentityCompatible(obj,cached,tag,pln,cacheContext)
            if nargin < 5 || isempty(cacheContext)
                cacheContext = struct();
            end
            tf = ...
                planWorkflow.cache.DoseInfluenceCache.isIdentityCompatible( ...
                obj.runConfig,cached,tag,pln,cacheContext);
        end

        function cacheContext = context(obj,cst,stf) %#ok<INUSD>
            cacheContext = planWorkflow.cache.DoseInfluenceCache.context( ...
                cst,stf);
        end

        function signature = stfSignature(obj,stf) %#ok<INUSD>
            signature = planWorkflow.cache.DoseInfluenceCache.stfSignature(stf);
        end

        function ensureFileFolder(obj,cacheFile) %#ok<INUSD>
            planWorkflow.cache.DoseInfluenceCache.ensureFileFolder(cacheFile);
        end

        function tag = robustTag(obj,robustData) %#ok<INUSD>
            planWorkflow.cache.DoseInfluenceCacheService.requireRobustDataPlan( ...
                robustData);
            tag = ['robust_' char(robustData.planConfig.id)];
        end
    end

    methods (Static)
        function requireRobustDataPlan(robustData)
            if ~isstruct(robustData) || ...
                    ~isfield(robustData,'planConfig') || ...
                    isempty(robustData.planConfig)
                error(['planWorkflow:cache:DoseInfluenceCacheService:' ...
                    'MissingRobustPlanConfig'], ...
                    'Robust data must contain an explicit planConfig.');
            end
            if ~isfield(robustData,'strategy') || isempty(robustData.strategy)
                error(['planWorkflow:cache:DoseInfluenceCacheService:' ...
                    'MissingRobustStrategy'], ...
                    'Robust data must contain an explicit strategy.');
            end
        end
    end
end
