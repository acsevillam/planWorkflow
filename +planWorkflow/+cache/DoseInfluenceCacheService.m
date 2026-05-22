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

        function [dij,cacheRef] = getOrCreate(obj,tag,ct,cst,stf,pln)
            [dij,cacheRef] = ...
                planWorkflow.cache.DoseInfluenceCache.getOrCreate( ...
                obj.runConfig,obj.cachePath,tag,ct,cst,stf, ...
                pln,obj.logFn);
        end

        function [dij,dijPrecomputingTiming,dijPrecomputingSize,cacheRef] = getOrCreateTimed( ...
                obj,tag,ct,cst,stf,pln,timingOptions)
            if nargin < 7
                timingOptions = [];
            end
            [dij,dijPrecomputingTiming,dijPrecomputingSize,cacheRef] = ...
                planWorkflow.cache.DoseInfluenceCache.getOrCreateTimed( ...
                obj.runConfig,obj.cachePath,tag,ct,cst,stf,pln, ...
                obj.logFn,timingOptions);
        end

        function [dij,dijPrecomputingTiming,dijPrecomputingSize, ...
                cacheRef,lazyCacheHit] = getOrCreateLazyTimed( ...
                obj,tag,ct,cst,stf,pln,timingOptions)
            if nargin < 7
                timingOptions = [];
            end
            [dij,dijPrecomputingTiming,dijPrecomputingSize, ...
                cacheRef,lazyCacheHit] = ...
                planWorkflow.cache.DoseInfluenceCache.getOrCreateLazyTimed( ...
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

        function [dij,dijPrecomputingTiming,dijPrecomputingSize,cacheRef] = getOrCalculateTransientTimed( ...
                obj,tag,robustData,ct,cst,stf,pln,timingOptions)
            if nargin < 8
                timingOptions = [];
            end
            [dij,dijPrecomputingTiming,dijPrecomputingSize,cacheRef] = ...
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

        function dij = loadCompatibleRef(obj,ref,owner,rootData)
            planWorkflow.cache.DoseInfluenceCacheService.assertKnownRefKind( ...
                ref);
            switch char(ref.cacheKind)
                case 'standard'
                    dij = obj.loadStandardRef(ref,owner);
                case 'interval'
                    dij = obj.loadCompactRef(ref,owner,rootData, ...
                        'interval');
                case 'prob'
                    dij = obj.loadCompactRef(ref,owner,rootData,'prob');
            end
            planWorkflow.cache.DoseInfluenceCacheService.assertRefBixels( ...
                ref,dij);
        end
    end

    methods (Access = private)
        function dij = loadStandardRef(obj,ref,owner)
            cacheFile = obj.refCacheFile(ref);
            cached = ...
                planWorkflow.cache.DoseInfluenceCacheService.loadCacheFile( ...
                cacheFile,{char(ref.variableName),'cacheMetadata'}, ...
                ref.role);
            planWorkflow.cache.DoseInfluenceCacheService.assertCacheRefMetadata( ...
                ref,cached.cacheMetadata,cacheFile);
            cacheContext = ...
                planWorkflow.cache.DoseInfluenceCacheService.standardContextForRef( ...
                ref,owner);
            pln = ...
                planWorkflow.cache.DoseInfluenceCacheService.planForRef( ...
                ref,owner);
            tag = ...
                planWorkflow.cache.DoseInfluenceCacheService.standardTagForRef( ...
                ref,owner);
            if ~obj.isCompatible(cached,pln,tag,cacheContext)
                error(['planWorkflow:cache:DoseInfluenceCacheService:' ...
                    'IncompatibleDijCacheOnResume'], ...
                    ['Cannot rehydrate %s from cache "%s": cache is ' ...
                    'not compatible with the current dose context.'], ...
                    char(ref.role),cacheFile);
            end
            dij = cached.(char(ref.variableName));
        end

        function dij = loadCompactRef(obj,ref,owner,rootData,cacheKind)
            context = obj.workflowDataContext(rootData);
            switch char(cacheKind)
                case 'interval'
                    variables = {'dij_interval','dijIntervalContext', ...
                        'cacheMetadata'};
                    tag = ...
                        planWorkflow.precompute.IntervalDoseInfluence.cacheTag( ...
                        owner);
                    cacheContext = ...
                        planWorkflow.precompute.IntervalDoseInfluence.cacheContext( ...
                        context,owner);
                case 'prob'
                    variables = {'dij_prob','dijProbContext', ...
                        'cacheMetadata'};
                    tag = ...
                        planWorkflow.precompute.ProbDoseInfluence.cacheTag( ...
                        owner);
                    cacheContext = ...
                        planWorkflow.precompute.ProbDoseInfluence.cacheContext( ...
                        context,owner);
            end
            persistedFile = obj.refCacheFile(ref);
            cacheFile = persistedFile;
            cached = ...
                planWorkflow.cache.DoseInfluenceCacheService.loadCacheFile( ...
                cacheFile,variables,ref.role);
            planWorkflow.cache.DoseInfluenceCacheService.assertCacheRefMetadata( ...
                ref,cached.cacheMetadata,cacheFile);
            resolvedFile = obj.resolvedCompactCacheFile( ...
                tag,owner,cacheContext);
            switch char(cacheKind)
                case 'interval'
                    if planWorkflow.cache.DoseInfluenceCacheService.sameFile( ...
                            resolvedFile,persistedFile)
                        compatible = ...
                            planWorkflow.precompute.IntervalDoseInfluence.isCacheCompatible( ...
                            context,cached,owner);
                    else
                        compatible = ...
                            planWorkflow.precompute.IntervalDoseInfluence.isCachePayloadCompatible( ...
                            cached,owner);
                    end
                case 'prob'
                    if planWorkflow.cache.DoseInfluenceCacheService.sameFile( ...
                            resolvedFile,persistedFile)
                        compatible = ...
                            planWorkflow.precompute.ProbDoseInfluence.isCacheCompatible( ...
                            context,cached,owner);
                    else
                        compatible = ...
                            planWorkflow.precompute.ProbDoseInfluence.isCachePayloadCompatible( ...
                            cached,owner);
                    end
            end
            if ~compatible
                error(['planWorkflow:cache:DoseInfluenceCacheService:' ...
                    'IncompatibleCompactCacheOnResume'], ...
                    ['Cannot rehydrate %s: compact cache is not ' ...
                    'compatible with the current dose context.'], ...
                    char(ref.role));
            end
            variableName = char(ref.variableName);
            if ~isfield(cached,variableName)
                error(['planWorkflow:cache:DoseInfluenceCacheService:' ...
                    'MissingCachedVariable'], ...
                    'Cache "%s" does not contain variable "%s".', ...
                    cacheFile,variableName);
            end
            dij = cached.(variableName);
        end

        function cacheFile = refCacheFile(obj,ref)
            cacheFile = fullfile(obj.cachePath,char(ref.cacheRelativeFile));
        end

        function context = workflowDataContext(obj,rootData)
            context = struct();
            context.stageName = 'workflowDataArtifact';
            context.runConfig = obj.runConfig;
            context.data = rootData;
            context.log = @(~) [];
            context.runMeasuredPlanTask = @(varargin) [];
            context.cache = obj;
        end

        function cacheFile = resolvedCompactCacheFile(obj,tag,owner, ...
                cacheContext)
            cacheFile = '';
            try
                cacheFile = obj.file(tag,owner.pln,cacheContext);
            catch
                cacheFile = '';
            end
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

        function tf = sameFile(left,right)
            tf = ~isempty(left) && ~isempty(right) && ...
                strcmp(char(left),char(right));
        end

        function cached = loadCacheFile(cacheFile,variables,role)
            if ~isfile(cacheFile)
                error(['planWorkflow:cache:DoseInfluenceCacheService:' ...
                    'MissingDijCache'], ...
                    'Cannot persist or resume %s: cache file is missing: %s.', ...
                    char(role),cacheFile);
            end
            cached = load(cacheFile,variables{:});
            for variableIx = 1:numel(variables)
                variableName = char(variables{variableIx});
                if ~isfield(cached,variableName)
                    error(['planWorkflow:cache:DoseInfluenceCacheService:' ...
                        'MissingCachedVariable'], ...
                        'Cache "%s" does not contain variable "%s".', ...
                        cacheFile,variableName);
                end
            end
        end

        function assertKnownRefKind(ref)
            validKinds = {'standard','interval','prob'};
            if ~any(strcmp(char(ref.cacheKind),validKinds))
                error(['planWorkflow:cache:DoseInfluenceCacheService:' ...
                    'UnknownDijRefKind'], ...
                    'Unknown dose influence cache kind "%s".', ...
                    char(ref.cacheKind));
            end
        end

        function assertCacheRefMetadata(ref,cacheMetadata,cacheFile)
            planWorkflow.cache.DoseInfluenceCacheRef.assertMatchesMetadata( ...
                ref,cacheMetadata,cacheFile,ref.role, ...
                'planWorkflow:cache:DoseInfluenceCacheService');
        end

        function assertRefBixels(ref,dij)
            expected = ref.totalNumOfBixels;
            if isempty(expected)
                return;
            end
            actual = ...
                planWorkflow.precompute.OptimizationInput.totalNumOfBixels( ...
                dij);
            if ~isempty(actual) && actual ~= expected
                error(['planWorkflow:cache:DoseInfluenceCacheService:' ...
                    'DijRefBixelMismatch'], ...
                    ['Rehydrated %s has %d bixels, but persisted ' ...
                    'reference expects %d.'],char(ref.role),actual, ...
                    expected);
            end
        end

        function cacheContext = standardContextForRef(ref,owner)
            switch char(ref.role)
                case 'dijNominal'
                    cacheContext = ...
                        planWorkflow.cache.DoseInfluenceCache.context( ...
                        owner.cst,owner.stfNominal);
                otherwise
                    if isfield(owner,'optimizationInput') && ...
                            strcmp(char(ref.role),'optimizationInput')
                        cacheContext = ...
                            planWorkflow.cache.DoseInfluenceCache.context( ...
                            owner.optimizationInput.cst, ...
                            owner.optimizationInput.stf);
                    else
                        cacheContext = ...
                            planWorkflow.cache.DoseInfluenceCache.context( ...
                            owner.cst,owner.stf);
                    end
            end
        end

        function pln = planForRef(ref,owner)
            switch char(ref.role)
                case 'dijNominal'
                    pln = owner.plnNominal;
                otherwise
                    if isfield(owner,'optimizationInput') && ...
                            strcmp(char(ref.role),'optimizationInput')
                        pln = owner.optimizationInput.pln;
                    else
                        pln = owner.pln;
                    end
            end
        end

        function tag = standardTagForRef(ref,owner)
            if planWorkflow.cache.DoseInfluenceCacheService.hasPlanId(owner)
                planId = char(owner.planConfig.id);
                switch char(ref.role)
                    case 'dijNominal'
                        tag = ['robustNominal_' planId];
                    case {'dijRobust','optimizationInput'}
                        if strcmp(char(ref.role),'optimizationInput') && ...
                                isfield(owner,'optimizationInput') && ...
                                isfield(owner.optimizationInput,'dijKind') && ...
                                strcmp(char(owner.optimizationInput.dijKind), ...
                                'nominal')
                            tag = ['robustNominal_' planId];
                        else
                            tag = ['robust_' planId];
                        end
                    otherwise
                        tag = ['robust_' planId];
                end
                return;
            end
            tag = 'reference';
        end

        function tf = hasPlanId(owner)
            tf = isstruct(owner) && isfield(owner,'planConfig') && ...
                isstruct(owner.planConfig) && ...
                isfield(owner.planConfig,'id') && ...
                ~isempty(owner.planConfig.id);
        end
    end
end
