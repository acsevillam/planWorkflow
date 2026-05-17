classdef DoseInfluenceCache
    % DoseInfluenceCache Owns dose-influence cache identity and persistence.

    methods (Static)
        function [dij,cacheRef] = getOrCreate(runConfig,cachePath,tag,ct,cst, ...
                stf,pln,logFn)
            if nargin < 8
                logFn = [];
            end
            [dij,~,~,cacheRef] = ...
                planWorkflow.cache.DoseInfluenceCache.getOrCreateTimed( ...
                runConfig,cachePath,tag,ct,cst,stf,pln,logFn);
        end

        function [dij,dijPrecomputingTiming,dijPrecomputingSize,cacheRef] = getOrCreateTimed( ...
                runConfig,cachePath,tag,ct,cst,stf,pln,logFn, ...
                timingOptions)
            if nargin < 8 || isempty(logFn)
                logFn = @(message) [];
            end
            if nargin < 9 || isempty(timingOptions)
                timingOptions = ...
                    planWorkflow.cache.DoseInfluenceCache.timingOptions( ...
                    runConfig,tag,[]);
            end
            cacheContext = planWorkflow.cache.DoseInfluenceCache.context( ...
                cst,stf);
            cacheFile = planWorkflow.cache.DoseInfluenceCache.cacheFile( ...
                cachePath,runConfig,tag,pln,cacheContext);
            cacheRef = [];
            cacheTelemetry = ...
                planWorkflow.cache.DoseInfluenceCache.emptyCacheTelemetry( ...
                cacheFile,runConfig,tag);
            if runConfig.useCache && isfile(cacheFile)
                validationTimer = tic;
                cached = load(cacheFile,'cacheMetadata');
                cacheTelemetry.metadataValidationSeconds = toc( ...
                    validationTimer);
                if isfield(cached,'cacheMetadata')
                    validationTimer = tic;
                    isCompatible = ...
                        planWorkflow.cache.DoseInfluenceCache.isCompatible( ...
                        runConfig,cached,pln,tag,cacheContext);
                    cacheTelemetry.metadataValidationSeconds = ...
                        cacheTelemetry.metadataValidationSeconds + ...
                        toc(validationTimer);
                    if isCompatible && ...
                            planWorkflow.cache.DoseInfluenceCache.cacheFileHasVariables( ...
                            cacheFile,{'dij'})
                        loadTimer = tic;
                        loaded = load(cacheFile,'dij');
                        cacheTelemetry.loadSeconds = toc(loadTimer);
                        cached.dij = loaded.dij;
                        validationTimer = tic;
                        isCompatible = ...
                            planWorkflow.cache.DoseInfluenceCache.isCompatible( ...
                            runConfig,cached,pln,tag,cacheContext);
                        cacheTelemetry.metadataValidationSeconds = ...
                            cacheTelemetry.metadataValidationSeconds + ...
                            toc(validationTimer);
                    end
                    if isCompatible && isfield(cached,'dij')
                        dijPrecomputingTiming = ...
                            planWorkflow.performance.PrecomputeTiming.fromCacheMetadata( ...
                            cached.cacheMetadata);
                        dijPrecomputingSize = ...
                            planWorkflow.performance.PrecomputeSize.fromCacheMetadata( ...
                            cached.cacheMetadata);
                        if ~isempty(dijPrecomputingTiming) && ...
                                ~isempty(dijPrecomputingSize)
                            logFn(sprintf('Loaded cached dij: %s.', ...
                                cacheFile));
                            dij = cached.dij;
                            cacheRef = ...
                                planWorkflow.cache.DoseInfluenceCacheRef.create( ...
                                'standard',tag,cacheFile,cachePath, ...
                                cached.cacheMetadata,{'dij'}, ...
                                planWorkflow.cache.DoseInfluenceCacheRef.totalNumOfBixels( ...
                                dij));
                            cacheRef.cacheTelemetry = ...
                                planWorkflow.cache.DoseInfluenceCache.finalizeCacheTelemetry( ...
                                cacheTelemetry,cached.cacheMetadata,dij, ...
                                true);
                            return;
                        end
                    end
                    logFn(sprintf('Ignoring stale cached dij: %s.',cacheFile));
                end
            end

            dosePln = planWorkflow.plan.Plan.applyDoseParallelism( ...
                pln,runConfig);
            wallTimer = tic;
            dij = matRad_calcDoseInfluence(ct,cst,stf,dosePln);
            cacheTelemetry.computeSeconds = toc(wallTimer);
            dijPrecomputingTiming = ...
                planWorkflow.performance.PrecomputeTiming.fromOptions( ...
                cacheTelemetry.computeSeconds,timingOptions);
            dijPrecomputingSize = ...
                planWorkflow.performance.PrecomputeSize.fromOptions( ...
                dij,timingOptions);
            if runConfig.writeCache
                planWorkflow.cache.DoseInfluenceCache.ensureFileFolder( ...
                    cacheFile);
                cacheMetadata = planWorkflow.cache.DoseInfluenceCache.metadata( ...
                    runConfig,tag,pln,cacheContext);
                cacheMetadata.dijPrecomputingTiming = ...
                    dijPrecomputingTiming;
                cacheMetadata.dijPrecomputingSize = ...
                    dijPrecomputingSize;
                cacheMetadata.cacheTelemetry = ...
                    planWorkflow.cache.DoseInfluenceCache.finalizeCacheTelemetry( ...
                    cacheTelemetry,cacheMetadata,dij,false);
                saveTimer = tic;
                builtin('save',cacheFile,'dij','cacheMetadata','-v7.3');
                cacheMetadata.cacheTelemetry.saveSeconds = toc(saveTimer);
                cacheMetadata.cacheTelemetry = ...
                    planWorkflow.cache.DoseInfluenceCache.finalizeCacheTelemetry( ...
                    cacheMetadata.cacheTelemetry,cacheMetadata,dij,false);
                cacheRef = ...
                    planWorkflow.cache.DoseInfluenceCacheRef.create( ...
                    'standard',tag,cacheFile,cachePath,cacheMetadata, ...
                    {'dij'}, ...
                    planWorkflow.cache.DoseInfluenceCacheRef.totalNumOfBixels( ...
                    dij));
                cacheRef.cacheTelemetry = cacheMetadata.cacheTelemetry;
                logFn(sprintf('Cached dij: %s.',cacheFile));
            end
        end

        function [dij,dijPrecomputingTiming,dijPrecomputingSize, ...
                cacheRef,lazyCacheHit] = getOrCreateLazyTimed( ...
                runConfig,cachePath,tag,ct,cst,stf,pln,logFn, ...
                timingOptions)
            if nargin < 8 || isempty(logFn)
                logFn = @(message) [];
            end
            if nargin < 9 || isempty(timingOptions)
                timingOptions = ...
                    planWorkflow.cache.DoseInfluenceCache.timingOptions( ...
                    runConfig,tag,[]);
            end
            dij = [];
            dijPrecomputingTiming = [];
            dijPrecomputingSize = [];
            cacheRef = [];
            lazyCacheHit = false;

            cacheContext = planWorkflow.cache.DoseInfluenceCache.context( ...
                cst,stf);
            cacheFile = planWorkflow.cache.DoseInfluenceCache.cacheFile( ...
                cachePath,runConfig,tag,pln,cacheContext);
            cacheTelemetry = ...
                planWorkflow.cache.DoseInfluenceCache.emptyCacheTelemetry( ...
                cacheFile,runConfig,tag);
            if runConfig.useCache && isfile(cacheFile) && ...
                    planWorkflow.cache.DoseInfluenceCache.cacheFileHasVariables( ...
                    cacheFile,{'dij','cacheMetadata'})
                validationTimer = tic;
                cached = load(cacheFile,'cacheMetadata');
                cacheTelemetry.metadataValidationSeconds = toc( ...
                    validationTimer);
                validationTimer = tic;
                if planWorkflow.cache.DoseInfluenceCache.isCompatible( ...
                        runConfig,cached,pln,tag,cacheContext)
                    cacheTelemetry.metadataValidationSeconds = ...
                        cacheTelemetry.metadataValidationSeconds + ...
                        toc(validationTimer);
                    dijPrecomputingTiming = ...
                        planWorkflow.performance.PrecomputeTiming.fromCacheMetadata( ...
                        cached.cacheMetadata);
                    dijPrecomputingSize = ...
                        planWorkflow.performance.PrecomputeSize.fromCacheMetadata( ...
                        cached.cacheMetadata);
                    if ~isempty(dijPrecomputingTiming) && ...
                            ~isempty(dijPrecomputingSize)
                        cacheRef = ...
                            planWorkflow.cache.DoseInfluenceCacheRef.create( ...
                            'standard',tag,cacheFile,cachePath, ...
                            cached.cacheMetadata,{'dij'}, ...
                            planWorkflow.precompute.OptimizationInput.totalNumOfBixels( ...
                            stf));
                        cacheRef.cacheTelemetry = ...
                            planWorkflow.cache.DoseInfluenceCache.finalizeCacheTelemetry( ...
                            cacheTelemetry,cached.cacheMetadata,[],true);
                        lazyCacheHit = true;
                        logFn(sprintf('Resolved cached dij artifact: %s.', ...
                            cacheFile));
                        return;
                    end
                else
                    cacheTelemetry.metadataValidationSeconds = ...
                        cacheTelemetry.metadataValidationSeconds + ...
                        toc(validationTimer);
                end
            end

            [dij,dijPrecomputingTiming,dijPrecomputingSize,cacheRef] = ...
                planWorkflow.cache.DoseInfluenceCache.getOrCreateTimed( ...
                runConfig,cachePath,tag,ct,cst,stf,pln,logFn, ...
                timingOptions);
        end

        function cacheFile = cacheFile(cachePath,runConfig,tag,varargin)
            cacheKey = planWorkflow.cache.DoseInfluenceCache.buildKey( ...
                runConfig,tag,varargin{:});
            cacheFile = fullfile(cachePath,[cacheKey '.mat']);
        end

        function dij = getOrCalculateTransient(runConfig,cachePath,tag, ...
                robustnessModeName,ct,cst,stf,pln,logFn)
            if nargin < 9
                logFn = [];
            end
            dij = ...
                planWorkflow.cache.DoseInfluenceCache.getOrCalculateTransientTimed( ...
                runConfig,cachePath,tag,robustnessModeName,ct,cst,stf, ...
                pln,logFn);
        end

        function [dij,dijPrecomputingTiming,dijPrecomputingSize,cacheRef] = getOrCalculateTransientTimed( ...
                runConfig,cachePath,tag,robustnessModeName,ct,cst,stf, ...
                pln,logFn,timingOptions)
            if nargin < 9 || isempty(logFn)
                logFn = @(message) [];
            end
            if nargin < 10 || isempty(timingOptions)
                timingOptions = ...
                    planWorkflow.cache.DoseInfluenceCache.timingOptions( ...
                    runConfig,tag,[]);
            end
            cacheContext = planWorkflow.cache.DoseInfluenceCache.context( ...
                cst,stf);
            cacheFile = planWorkflow.cache.DoseInfluenceCache.cacheFile( ...
                cachePath,runConfig,tag,pln,cacheContext);
            cacheRef = [];
            if runConfig.useCache && isfile(cacheFile)
                try
                    cached = load(cacheFile,'dij','cacheMetadata');
                    if isfield(cached,'dij') && ...
                            planWorkflow.cache.DoseInfluenceCache.isCompatible( ...
                            runConfig,cached,pln,tag,cacheContext)
                        dijPrecomputingTiming = ...
                            planWorkflow.performance.PrecomputeTiming.fromCacheMetadata( ...
                            cached.cacheMetadata);
                        dijPrecomputingSize = ...
                            planWorkflow.performance.PrecomputeSize.fromCacheMetadata( ...
                            cached.cacheMetadata);
                        if ~isempty(dijPrecomputingTiming) && ...
                                ~isempty(dijPrecomputingSize)
                            logFn(sprintf('Loaded cached dij: %s.', ...
                                cacheFile));
                            dij = cached.dij;
                            cacheRef = ...
                                planWorkflow.cache.DoseInfluenceCacheRef.create( ...
                                'standard',tag,cacheFile,cachePath, ...
                                cached.cacheMetadata,{'dij'}, ...
                                planWorkflow.cache.DoseInfluenceCacheRef.totalNumOfBixels( ...
                                dij));
                            return;
                        end
                    end
                    logFn(sprintf('Ignoring stale cached dij: %s.', ...
                        cacheFile));
                catch ME
                    logFn(sprintf('Ignoring unreadable cached dij: %s (%s).', ...
                        cacheFile,ME.message));
                end
            end

            dosePln = planWorkflow.plan.Plan.applyDoseParallelism( ...
                pln,runConfig);
            wallTimer = tic;
            dij = matRad_calcDoseInfluence(ct,cst,stf,dosePln);
            dijPrecomputingTiming = ...
                planWorkflow.performance.PrecomputeTiming.fromOptions( ...
                toc(wallTimer),timingOptions);
            dijPrecomputingSize = ...
                planWorkflow.performance.PrecomputeSize.fromOptions( ...
                dij,timingOptions);
            if runConfig.writeCache
                logFn(sprintf(['Skipping persistent robust dij cache for ' ...
                    '%s; dij_interval is the cache artifact used by ' ...
                    'INTERVAL optimization.'],char(robustnessModeName)));
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
            if isfield(artifactMetadata,'robustnessMode') && ...
                    ~isempty(artifactMetadata.robustnessMode)
                metadata.robustnessMode = artifactMetadata.robustnessMode;
            elseif strcmp(char(tag),'reference')
                reference = ...
                    planWorkflow.config.RobustPlanConfig.referenceFromRunConfig( ...
                    runConfig);
                metadata.robustnessMode = reference.robustnessMode;
            end
            if isfield(artifactMetadata,'planId')
                metadata.planId = artifactMetadata.planId;
            end
            if isfield(artifactMetadata,'label')
                metadata.label = artifactMetadata.label;
                metadata.objectiveSetName = ...
                    artifactMetadata.objectiveSetName;
                metadata.scenario = artifactMetadata.scenario;
                metadata.robustnessMode = artifactMetadata.robustnessMode;
                metadata.robustnessOptions = artifactMetadata.robustnessOptions;
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
                metadata.scenarioFingerprint = ...
                    planWorkflow.cache.CacheIdentity.scenarioFingerprint( ...
                    pln.multScen);
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
                planWorkflow.cache.CacheIdentity.scenarioFingerprint( ...
                pln.multScen));
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

        function tf = cacheFileHasVariables(cacheFile,variables)
            available = who('-file',cacheFile);
            tf = all(ismember(variables,available));
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
        function telemetry = emptyCacheTelemetry(cacheFile,runConfig,tag)
            telemetry = struct();
            telemetry.schemaVersion = 1;
            telemetry.source = 'planWorkflow.cache.DoseInfluenceCache';
            telemetry.cacheTag = char(tag);
            telemetry.cacheHit = false;
            telemetry.cacheFile = char(cacheFile);
            telemetry.computeSeconds = 0;
            telemetry.metadataValidationSeconds = 0;
            telemetry.loadSeconds = 0;
            telemetry.saveSeconds = 0;
            telemetry.fileBytes = ...
                planWorkflow.cache.DoseInfluenceCache.fileBytes(cacheFile);
            telemetry.logicalBytes = NaN;
            telemetry.artifactKind = ...
                planWorkflow.cache.DoseInfluenceCache.artifactKind( ...
                runConfig,tag,[]);
        end

        function telemetry = finalizeCacheTelemetry( ...
                telemetry,cacheMetadata,value,cacheHit)
            telemetry.cacheHit = logical(cacheHit);
            telemetry.fileBytes = ...
                planWorkflow.cache.DoseInfluenceCache.fileBytes( ...
                telemetry.cacheFile);
            telemetry.artifactKind = ...
                planWorkflow.cache.DoseInfluenceCache.artifactKind( ...
                [],[],cacheMetadata);
            logicalBytes = ...
                planWorkflow.cache.DoseInfluenceCache.logicalBytesFromMetadata( ...
                cacheMetadata);
            if ~isfinite(logicalBytes) && ~isempty(value)
                logicalBytes = ...
                    planWorkflow.performance.PrecomputeSize.artifactBytes( ...
                    value);
            end
            telemetry.logicalBytes = logicalBytes;
        end

        function bytes = fileBytes(filePath)
            bytes = NaN;
            try
                info = dir(char(filePath));
                if ~isempty(info)
                    bytes = double(info.bytes);
                end
            catch
            end
        end

        function bytes = logicalBytesFromMetadata(cacheMetadata)
            bytes = NaN;
            if ~isstruct(cacheMetadata) || ...
                    ~isfield(cacheMetadata,'dijPrecomputingSize')
                return;
            end
            [sizeData,tf] = planWorkflow.performance.PrecomputeSize.normalize( ...
                cacheMetadata.dijPrecomputingSize);
            if tf
                bytes = sizeData.totalSizeBytes;
            end
        end

        function kind = artifactKind(runConfig,tag,cacheMetadata)
            kind = '';
            if isstruct(cacheMetadata) && isfield(cacheMetadata,'artifact') && ...
                    isstruct(cacheMetadata.artifact) && ...
                    isfield(cacheMetadata.artifact,'kind')
                kind = char(cacheMetadata.artifact.kind);
                return;
            end
            if isstruct(runConfig) && ~isempty(tag)
                artifact = planWorkflow.cache.CacheIdentity.artifactMetadata( ...
                    runConfig,tag);
                if isfield(artifact,'kind')
                    kind = char(artifact.kind);
                end
            end
        end

        function options = timingOptions(runConfig,tag,referenceTiming)
            artifact = planWorkflow.cache.CacheIdentity.artifactMetadata( ...
                runConfig,tag);
            label = char(tag);
            if isfield(artifact,'label') && ~isempty(artifact.label)
                label = char(artifact.label);
            elseif strcmp(char(tag),'reference')
                reference = ...
                    planWorkflow.config.RobustPlanConfig.referenceFromRunConfig( ...
                    runConfig);
                label = ...
                    planWorkflow.results.PlanLabels.referencePlanDisplayLabel( ...
                    reference);
            end

            artifactName = 'dij';
            role = 'reference';
            if isfield(artifact,'kind') && strcmp(artifact.kind,'robust')
                role = 'robust';
                if isfield(artifact,'role') && strcmp(artifact.role,'nominal')
                    artifactName = 'dij_nominal';
                else
                    artifactName = 'dij_robust';
                end
            end
            options = planWorkflow.performance.PrecomputeTiming.cacheOptions( ...
                role,label,artifactName,referenceTiming);
        end

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
