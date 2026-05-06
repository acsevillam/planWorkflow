classdef DoseInfluenceCache
    % DoseInfluenceCache Owns dose-influence cache identity and persistence.

    methods (Static)
        function dij = getOrCreate(runConfig,cachePath,tag,ct,cst, ...
                stf,pln,logFn)
            if nargin < 8 || isempty(logFn)
                logFn = @(message) [];
            end
            cacheContext = planWorkflow.cache.DoseInfluenceCache.context( ...
                cst,stf);
            cacheFile = planWorkflow.cache.DoseInfluenceCache.cacheFile( ...
                cachePath,runConfig,tag,pln,cacheContext);
            if runConfig.useCache && isfile(cacheFile)
                cached = load(cacheFile,'dij','cacheMetadata');
                if isfield(cached,'dij')
                    if planWorkflow.cache.DoseInfluenceCache.isCompatible( ...
                            runConfig,cached,pln,tag,cacheContext)
                        logFn(sprintf('Loaded cached dij: %s.',cacheFile));
                        dij = cached.dij;
                        return;
                    end
                    logFn(sprintf('Ignoring stale cached dij: %s.',cacheFile));
                end
            end

            dij = matRad_calcDoseInfluence(ct,cst,stf,pln);
            if runConfig.writeCache
                planWorkflow.cache.DoseInfluenceCache.ensureFileFolder( ...
                    cacheFile);
                cacheMetadata = planWorkflow.cache.DoseInfluenceCache.metadata( ...
                    runConfig,tag,pln,cacheContext); %#ok<NASGU>
                builtin('save',cacheFile,'dij','cacheMetadata','-v7.3');
                logFn(sprintf('Cached dij: %s.',cacheFile));
            end
        end

        function cacheFile = cacheFile(cachePath,runConfig,tag,varargin)
            cacheKey = planWorkflow.cache.DoseInfluenceCache.buildKey( ...
                runConfig,tag,varargin{:});
            cacheFile = fullfile(cachePath,[cacheKey '.mat']);
        end

        function dij = getOrCalculateTransient(runConfig,cachePath,tag, ...
                strategyName,ct,cst,stf,pln,logFn)
            if nargin < 9 || isempty(logFn)
                logFn = @(message) [];
            end
            cacheContext = planWorkflow.cache.DoseInfluenceCache.context( ...
                cst,stf);
            cacheFile = planWorkflow.cache.DoseInfluenceCache.cacheFile( ...
                cachePath,runConfig,tag,pln,cacheContext);
            if runConfig.useCache && isfile(cacheFile)
                try
                    cached = load(cacheFile,'dij','cacheMetadata');
                    if isfield(cached,'dij') && ...
                            planWorkflow.cache.DoseInfluenceCache.isCompatible( ...
                            runConfig,cached,pln,tag,cacheContext)
                        logFn(sprintf('Loaded cached dij: %s.',cacheFile));
                        dij = cached.dij;
                        return;
                    end
                    logFn(sprintf('Ignoring stale cached dij: %s.', ...
                        cacheFile));
                catch ME
                    logFn(sprintf('Ignoring unreadable cached dij: %s (%s).', ...
                        cacheFile,ME.message));
                end
            end

            dij = matRad_calcDoseInfluence(ct,cst,stf,pln);
            if runConfig.writeCache
                logFn(sprintf(['Skipping persistent robust dij cache for ' ...
                    '%s; dij_interval is the cache artifact used by ' ...
                    'INTERVAL optimization.'],char(strategyName)));
            end
        end

        function cacheKey = buildKey(runConfig,tag,varargin)
            descriptor = planWorkflow.cache.DoseInfluenceCache.descriptor( ...
                runConfig,tag,varargin{:});
            cacheKey = descriptor.relativeKey;
        end

        function metadata = metadata(runConfig,tag,pln,context)
            if nargin < 4
                context = struct();
            end
            descriptor = planWorkflow.cache.DoseInfluenceCache.descriptor( ...
                runConfig,tag,pln,context);
            metadata = struct();
            metadata.tag = tag;
            metadata.createdAt = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
            metadata.runConfig = runConfig;
            artifactMetadata = ...
                planWorkflow.cache.CacheIdentity.artifactMetadata( ...
                runConfig,tag);
            metadata.artifact = artifactMetadata;
            if isfield(artifactMetadata,'strategy') && ...
                    ~isempty(artifactMetadata.strategy)
                metadata.strategy = artifactMetadata.strategy;
            elseif strcmp(char(tag),'reference')
                reference = ...
                    planWorkflow.config.RobustPlanConfig.referenceFromRunConfig( ...
                    runConfig);
                if isfield(reference,'strategy') && ~isempty(reference.strategy)
                    metadata.strategy = reference.strategy;
                end
            end
            if isfield(artifactMetadata,'planId')
                metadata.planId = artifactMetadata.planId;
            end
            if isfield(artifactMetadata,'label')
                metadata.label = artifactMetadata.label;
                metadata.objectiveSetName = ...
                    artifactMetadata.objectiveSetName;
                metadata.scenario = artifactMetadata.scenario;
                metadata.strategyOptions = artifactMetadata.strategyOptions;
                metadata.optimization4D = artifactMetadata.optimization4D;
            end
            metadata.cacheIdentity = descriptor.identity;
            metadata.cacheIdentityHash = descriptor.identityHash;
            metadata.cacheIdentityShortHash = descriptor.shortHash;
            metadata.cacheRelativeKey = descriptor.relativeKey;
            if isfield(runConfig,'plan_template_hash')
                metadata.planTemplateHash = runConfig.plan_template_hash;
            end
            if isfield(pln,'machine')
                metadata.machine = pln.machine;
            end
            if isfield(pln,'multScen') && isa(pln.multScen,'matRad_ScenarioModel')
                metadata.scenarioFingerprint = pln.multScen.fingerprint();
                metadata.numOfScenarios = pln.multScen.numScenarios();
            end
            metadata.className = 'planWorkflow.cache.DoseInfluenceCache';
        end

        function tf = isCompatible(runConfig,cached,pln,tag,context)
            if nargin < 4 || isempty(tag)
                tag = 'reference';
            end
            if nargin < 5
                context = struct();
            end
            tf = planWorkflow.cache.DoseInfluenceCache.isIdentityCompatible( ...
                runConfig,cached,tag,pln,context);
            if ~tf
                return;
            end
            if ~isfield(cached,'cacheMetadata') || ...
                    ~isfield(cached.cacheMetadata,'scenarioFingerprint') || ...
                    ~isfield(pln,'multScen') || ...
                    ~isa(pln.multScen,'matRad_ScenarioModel')
                return;
            end
            tf = strcmp(cached.cacheMetadata.scenarioFingerprint, ...
                pln.multScen.fingerprint());
            if tf && isfield(cached,'dij') && isfield(cached.dij,'numOfScenarios')
                tf = cached.dij.numOfScenarios == pln.multScen.numScenarios();
            end
            if tf && isfield(cached,'dij')
                tf = planWorkflow.cache.DoseInfluenceCache.hasUsableScenarioMatrices( ...
                    cached.dij,pln.multScen);
            end
        end

        function tf = isIdentityCompatible(runConfig,cached,tag,pln,context)
            tf = false;
            if nargin < 5
                context = struct();
            end
            if ~isfield(cached,'cacheMetadata') || ...
                    ~isfield(cached.cacheMetadata,'cacheIdentityHash')
                return;
            end
            descriptor = planWorkflow.cache.DoseInfluenceCache.descriptor( ...
                runConfig,tag,pln,context);
            tf = strcmp(cached.cacheMetadata.cacheIdentityHash, ...
                descriptor.identityHash);
        end

        function descriptor = descriptor(runConfig,tag,pln,context)
            if nargin < 3 || isempty(pln)
                pln = struct();
            end
            if nargin < 4 || isempty(context)
                context = struct();
            end
            descriptor = planWorkflow.cache.CacheIdentity.build( ...
                runConfig,tag,pln,context);
        end

        function context = context(cst,stf)
            context = struct('cst',{cst}, ...
                'stf',planWorkflow.cache.DoseInfluenceCache.stfSignature(stf));
        end

        function signature = stfSignature(stf)
            signature = struct();
            signature.numOfBeams = numel(stf);
            signature.totalNumOfBixels = sum([stf.totalNumOfBixels]);
            signature.beamTotalNumOfBixels = [stf.totalNumOfBixels];
            signature.gantryAngles = ...
                planWorkflow.cache.DoseInfluenceCache.stfNumericField( ...
                stf,'gantryAngle');
            signature.couchAngles = ...
                planWorkflow.cache.DoseInfluenceCache.stfNumericField( ...
                stf,'couchAngle');
            signature.bixelWidth = ...
                planWorkflow.cache.DoseInfluenceCache.stfNumericField( ...
                stf,'bixelWidth');
            signature.isoCenter = ...
                planWorkflow.cache.DoseInfluenceCache.stfNumericMatrixField( ...
                stf,'isoCenter');
            signature.rayGeometryHash = planWorkflow.cache.CacheIdentity.valueHash( ...
                planWorkflow.cache.DoseInfluenceCache.stfRayGeometry(stf));
        end

        function ensureFileFolder(cacheFile)
            cacheFolder = fileparts(cacheFile);
            if ~isfolder(cacheFolder)
                mkdir(cacheFolder);
            end
        end

        function tf = hasUsableScenarioMatrices(dij,multScen)
            tf = true;
            if multScen.numScenarios() <= 1
                return;
            end

            if ~isfield(dij,'physicalDose') || ~iscell(dij.physicalDose)
                tf = false;
                return;
            end

            scenarioIds = multScen.scenarioIds();
            for scenarioIx = 1:numel(scenarioIds)
                fullScenIx = multScen.getDijScenarioIndex( ...
                    scenarioIds(scenarioIx));
                if fullScenIx > numel(dij.physicalDose) || ...
                        isempty(dij.physicalDose{fullScenIx}) || ...
                        nnz(dij.physicalDose{fullScenIx}) == 0
                    tf = false;
                    return;
                end
            end
        end
    end

    methods (Static, Access = private)
        function values = stfNumericField(stf,fieldName)
            values = NaN(1,numel(stf));
            for i = 1:numel(stf)
                if isfield(stf(i),fieldName) && ...
                        isnumeric(stf(i).(fieldName)) && ...
                        isscalar(stf(i).(fieldName))
                    values(i) = stf(i).(fieldName);
                end
            end
        end

        function values = stfNumericMatrixField(stf,fieldName)
            values = cell(1,numel(stf));
            for i = 1:numel(stf)
                if isfield(stf(i),fieldName) && ...
                        isnumeric(stf(i).(fieldName))
                    values{i} = stf(i).(fieldName);
                else
                    values{i} = [];
                end
            end
        end

        function geometry = stfRayGeometry(stf)
            geometry = cell(1,numel(stf));
            for beamIx = 1:numel(stf)
                beamGeometry = struct();
                beamGeometry.numOfRays = ...
                    planWorkflow.cache.DoseInfluenceCache.optionalNumericScalar( ...
                    stf(beamIx),'numOfRays');
                if isfield(stf(beamIx),'numOfBixelsPerRay')
                    beamGeometry.numOfBixelsPerRay = ...
                        stf(beamIx).numOfBixelsPerRay(:)';
                else
                    beamGeometry.numOfBixelsPerRay = [];
                end
                beamGeometry.ray = ...
                    planWorkflow.cache.DoseInfluenceCache.stfRayGeometryRows( ...
                    stf(beamIx));
                geometry{beamIx} = beamGeometry;
            end
        end

        function rows = stfRayGeometryRows(beamStf)
            rows = struct('targetPoint_bev',{},'rayPos_bev',{});
            if ~isfield(beamStf,'ray')
                return;
            end
            rows(1,numel(beamStf.ray)) = struct( ...
                'targetPoint_bev',[],'rayPos_bev',[]);
            for rayIx = 1:numel(beamStf.ray)
                ray = beamStf.ray(rayIx);
                if isfield(ray,'targetPoint_bev') && ...
                        isnumeric(ray.targetPoint_bev)
                    rows(rayIx).targetPoint_bev = ray.targetPoint_bev;
                end
                if isfield(ray,'rayPos_bev') && isnumeric(ray.rayPos_bev)
                    rows(rayIx).rayPos_bev = ray.rayPos_bev;
                end
            end
        end

        function value = optionalNumericScalar(source,fieldName)
            value = NaN;
            if isfield(source,fieldName) && isnumeric(source.(fieldName)) && ...
                    isscalar(source.(fieldName))
                value = source.(fieldName);
            end
        end
    end
end
