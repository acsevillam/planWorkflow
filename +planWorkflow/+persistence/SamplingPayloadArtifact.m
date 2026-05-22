classdef SamplingPayloadArtifact
    % SamplingPayloadArtifact Stores heavy sampling payloads outside snapshots.

    properties (Constant)
        SchemaVersion = 1
        ManifestSchemaVersion = 1
        RefKind = 'planWorkflowSamplingPayloadRef'
    end

    methods (Static)
        function samplingData = compactSamplingData(samplingData, ...
                runConfig,cachePath)
            if nargin < 2
                runConfig = struct();
            end
            if nargin < 3 || isempty(cachePath)
                cachePath = ...
                    planWorkflow.persistence.SamplingPayloadArtifact.cachePath( ...
                    runConfig);
            end
            if ~isstruct(samplingData) || isempty(samplingData)
                return;
            end

            if ~isempty(cachePath)
                samplingData = ...
                    planWorkflow.persistence.SamplingPayloadArtifact.compactRootPayloadRef( ...
                    samplingData,runConfig,cachePath);
                if isfield(samplingData,'reference')
                    unitInfo = ...
                        planWorkflow.persistence.SamplingPayloadArtifact.unitInfoFromSample( ...
                        samplingData.reference,'reference','reference',1);
                    samplingData.reference = ...
                        planWorkflow.persistence.SamplingPayloadArtifact.compactSampleUnitRef( ...
                        samplingData.reference,runConfig,cachePath, ...
                        'reference',unitInfo);
                end
                if isfield(samplingData,'robust') && ...
                        iscell(samplingData.robust)
                    for sampleIx = 1:numel(samplingData.robust)
                        role = sprintf('robust_%d',sampleIx);
                        unitInfo = ...
                            planWorkflow.persistence.SamplingPayloadArtifact.unitInfoFromSample( ...
                            samplingData.robust{sampleIx},role,role, ...
                            sampleIx + 1);
                        samplingData.robust{sampleIx} = ...
                            planWorkflow.persistence.SamplingPayloadArtifact.compactSampleUnitRef( ...
                            samplingData.robust{sampleIx},runConfig, ...
                            cachePath,role,unitInfo);
                    end
                end
            end

            samplingData = ...
                planWorkflow.results.SamplingDataCompactor.compactSamplingData( ...
                samplingData);
        end

        function samplingData = compactRootPayload(samplingData, ...
                runConfig,cachePath)
            if nargin < 2
                runConfig = struct();
            end
            if nargin < 3 || isempty(cachePath)
                cachePath = ...
                    planWorkflow.persistence.SamplingPayloadArtifact.cachePath( ...
                    runConfig);
            end
            if ~isstruct(samplingData) || isempty(samplingData)
                return;
            end
            if isempty(cachePath)
                return;
            end
            samplingData = ...
                planWorkflow.persistence.SamplingPayloadArtifact.compactRootPayloadRef( ...
                samplingData,runConfig,cachePath);
            samplingData = ...
                planWorkflow.results.SamplingDataCompactor.compactRootPayload( ...
                samplingData);
        end

        function sample = compactSampleUnit(sample,runConfig,cachePath, ...
                unitKey,unitInfo)
            if nargin < 2
                runConfig = struct();
            end
            if nargin < 3 || isempty(cachePath)
                cachePath = ...
                    planWorkflow.persistence.SamplingPayloadArtifact.cachePath( ...
                    runConfig);
            end
            if nargin < 4 || isempty(unitKey)
                unitKey = 'sample';
            end
            if nargin < 5
                unitInfo = struct();
            end
            if ~isstruct(sample) || isempty(sample)
                return;
            end

            if isempty(cachePath)
                return;
            end
            unitInfo = ...
                planWorkflow.persistence.SamplingPayloadArtifact.unitInfoFromSample( ...
                sample,unitKey,unitKey,[],unitInfo);
            sample = ...
                planWorkflow.persistence.SamplingPayloadArtifact.compactSampleUnitRef( ...
                sample,runConfig,cachePath,unitKey,unitInfo);
            planWorkflow.persistence.SamplingPayloadArtifact.recordSampleUnit( ...
                sample,runConfig,cachePath,unitKey,unitInfo);
            sample = ...
                planWorkflow.results.SamplingDataCompactor.compactSample( ...
                sample);
        end

        function sample = materializeSampleUnit(sample,runConfig,cachePath)
            if nargin < 2
                runConfig = struct();
            end
            if nargin < 3 || isempty(cachePath)
                cachePath = ...
                    planWorkflow.persistence.SamplingPayloadArtifact.cachePath( ...
                    runConfig);
            end
            sample = ...
                planWorkflow.persistence.SamplingPayloadArtifact.materializeSamplePayload( ...
                sample,cachePath);
        end

        function samplingData = materializeSamplingData(samplingData, ...
                runConfig,cachePath)
            if nargin < 2
                runConfig = struct();
            end
            if nargin < 3 || isempty(cachePath)
                cachePath = ...
                    planWorkflow.persistence.SamplingPayloadArtifact.cachePath( ...
                    runConfig);
            end
            if ~isstruct(samplingData) || isempty(samplingData)
                return;
            end

            samplingData = ...
                planWorkflow.persistence.SamplingPayloadArtifact.materializeRootPayload( ...
                samplingData,cachePath);
            if isfield(samplingData,'reference')
                samplingData.reference = ...
                    planWorkflow.persistence.SamplingPayloadArtifact.materializeSamplePayload( ...
                    samplingData.reference,cachePath);
            end
            if isfield(samplingData,'robust') && iscell(samplingData.robust)
                for sampleIx = 1:numel(samplingData.robust)
                    samplingData.robust{sampleIx} = ...
                        planWorkflow.persistence.SamplingPayloadArtifact.materializeSamplePayload( ...
                        samplingData.robust{sampleIx},cachePath);
                end
            end
        end

        function [sample,found] = cachedSampleUnit(runConfig,cachePath, ...
                unitKey,unitInfo)
            sample = struct();
            found = false;
            if nargin < 2 || isempty(cachePath)
                cachePath = ...
                    planWorkflow.persistence.SamplingPayloadArtifact.cachePath( ...
                    runConfig);
            end
            if nargin < 4
                unitInfo = struct();
            end
            if isempty(cachePath)
                return;
            end

            manifest = ...
                planWorkflow.persistence.SamplingPayloadArtifact.loadUnitManifest( ...
                runConfig,cachePath);
            unitIx = ...
                planWorkflow.persistence.SamplingPayloadArtifact.findManifestUnit( ...
                manifest,unitKey);
            if isempty(unitIx)
                return;
            end

            unit = manifest.units(unitIx);
            if ~planWorkflow.persistence.SamplingPayloadArtifact.isRef(unit.ref)
                return;
            end
            if ~planWorkflow.persistence.SamplingPayloadArtifact.unitMetadataCompatible( ...
                    unit.metadata,unitInfo)
                return;
            end
            if ~planWorkflow.persistence.SamplingPayloadArtifact.payloadFileIsComplete( ...
                    unit.ref,cachePath)
                return;
            end

            if isfield(unit,'sample') && isstruct(unit.sample) && ...
                    ~isempty(unit.sample)
                sample = unit.sample;
                sample.samplingPayloadRef = unit.ref;
            else
                sample = ...
                    planWorkflow.persistence.SamplingPayloadArtifact.sampleFromUnitMetadata( ...
                    unit.metadata,unit.ref);
            end
            found = true;
        end

        function tf = isRef(value)
            tf = isstruct(value) && isscalar(value) && ...
                isfield(value,'artifactKind') && ...
                strcmp(char(value.artifactKind), ...
                planWorkflow.persistence.SamplingPayloadArtifact.RefKind) && ...
                isfield(value,'schemaVersion') && ...
                value.schemaVersion == ...
                planWorkflow.persistence.SamplingPayloadArtifact.SchemaVersion;
        end

        function cachePath = cachePath(runConfig)
            cachePath = [];
            if isstruct(runConfig) && isfield(runConfig,'cacheRootPath')
                cachePath = runConfig.cacheRootPath;
            end
        end
    end

    methods (Static, Access = private)
        function samplingData = compactRootPayloadRef(samplingData, ...
                runConfig,cachePath)
            fields = ...
                planWorkflow.persistence.SamplingPayloadArtifact.presentFields( ...
                samplingData, ...
                planWorkflow.persistence.SamplingPayloadArtifact.rootFields());
            if isempty(fields)
                return;
            end
            unitInfo = struct('role','sampling_root','unitKey', ...
                'sampling_root','unitIndex',0);
            samplingData.samplingPayloadRef = ...
                planWorkflow.persistence.SamplingPayloadArtifact.savePayload( ...
                samplingData,runConfig,cachePath,'sampling_root', ...
                fields,unitInfo);
        end

        function sample = compactSampleUnitRef(sample,runConfig,cachePath, ...
                unitKey,unitInfo)
            if ~isstruct(sample) || isempty(sample)
                return;
            end
            if isfield(sample,'samplingPayloadRef') && ...
                    planWorkflow.persistence.SamplingPayloadArtifact.isRef( ...
                    sample.samplingPayloadRef) && ...
                    planWorkflow.persistence.SamplingPayloadArtifact.payloadFileIsComplete( ...
                    sample.samplingPayloadRef,cachePath)
                return;
            end
            fields = ...
                planWorkflow.persistence.SamplingPayloadArtifact.presentFields( ...
                sample, ...
                planWorkflow.persistence.SamplingPayloadArtifact.sampleFields());
            if isempty(fields)
                return;
            end
            sample.samplingPayloadRef = ...
                planWorkflow.persistence.SamplingPayloadArtifact.savePayload( ...
                sample,runConfig,cachePath,unitKey,fields,unitInfo);
        end

        function samplingData = materializeRootPayload(samplingData, ...
                cachePath)
            if planWorkflow.persistence.SamplingPayloadArtifact.hasAllFields( ...
                    samplingData, ...
                    planWorkflow.persistence.SamplingPayloadArtifact.rootFields())
                return;
            end
            if ~isfield(samplingData,'samplingPayloadRef') || ...
                    ~planWorkflow.persistence.SamplingPayloadArtifact.isRef( ...
                    samplingData.samplingPayloadRef)
                return;
            end
            payload = ...
                planWorkflow.persistence.SamplingPayloadArtifact.loadPayload( ...
                samplingData.samplingPayloadRef,cachePath);
            samplingData = ...
                planWorkflow.persistence.SamplingPayloadArtifact.mergePayload( ...
                samplingData,payload);
        end

        function sample = materializeSamplePayload(sample,cachePath)
            if ~isstruct(sample) || isempty(sample)
                return;
            end
            if planWorkflow.persistence.SamplingPayloadArtifact.hasAllFields( ...
                    sample, ...
                    planWorkflow.persistence.SamplingPayloadArtifact.sampleFields())
                return;
            end
            if ~isfield(sample,'samplingPayloadRef') || ...
                    ~planWorkflow.persistence.SamplingPayloadArtifact.isRef( ...
                    sample.samplingPayloadRef)
                return;
            end
            payload = ...
                planWorkflow.persistence.SamplingPayloadArtifact.loadPayload( ...
                sample.samplingPayloadRef,cachePath);
            sample = ...
                planWorkflow.persistence.SamplingPayloadArtifact.mergePayload( ...
                sample,payload);
        end

        function ref = savePayload(source,runConfig,cachePath,role, ...
                fields,unitInfo)
            payload = struct();
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                payload.(fieldName) = source.(fieldName);
            end

            metadata = ...
                planWorkflow.persistence.SamplingPayloadArtifact.metadata( ...
                payload,source,runConfig,role,fields,unitInfo);
            payload.samplingPayloadMetadata = metadata;
            relativeFile = ...
                planWorkflow.persistence.SamplingPayloadArtifact.relativeFile( ...
                runConfig,role,metadata.payloadIdentityHash);
            cacheFile = fullfile(cachePath,relativeFile);
            planWorkflow.persistence.SamplingPayloadArtifact.ensureFolder( ...
                fileparts(cacheFile));
            planWorkflow.persistence.SamplingPayloadArtifact.atomicSave( ...
                cacheFile,payload);

            ref = ...
                planWorkflow.persistence.SamplingPayloadArtifact.refFromMetadata( ...
                metadata,relativeFile);
        end

        function payload = loadPayload(ref,cachePath)
            if isempty(cachePath)
                error(['planWorkflow:persistence:SamplingPayloadArtifact:' ...
                    'MissingCachePath'], ...
                    ['Sampling payload materialization requires ' ...
                     'runConfig.cacheRootPath.']);
            end
            if planWorkflow.persistence.SamplingPayloadArtifact.isTmpFile( ...
                    ref.cacheRelativeFile)
                error(['planWorkflow:persistence:SamplingPayloadArtifact:' ...
                    'InvalidPayloadFile'], ...
                    'Temporary sampling payload artifacts are not valid.');
            end
            cacheFile = fullfile(cachePath,ref.cacheRelativeFile);
            if exist(cacheFile,'file') ~= 2
                error(['planWorkflow:persistence:SamplingPayloadArtifact:' ...
                    'MissingPayloadFile'], ...
                    'Missing sampling payload artifact: %s.',cacheFile);
            end

            variables = ...
                planWorkflow.persistence.SamplingPayloadArtifact.normalizeFields( ...
                ref.variables);
            loaded = load(cacheFile,variables{:}, ...
                'samplingPayloadMetadata');
            if ~isfield(loaded,'samplingPayloadMetadata')
                error(['planWorkflow:persistence:SamplingPayloadArtifact:' ...
                    'InvalidPayloadFile'], ...
                    'Sampling payload artifact lacks metadata: %s.', ...
                    cacheFile);
            end
            planWorkflow.persistence.SamplingPayloadArtifact.validateMetadata( ...
                loaded.samplingPayloadMetadata,ref,cacheFile);

            payload = struct();
            for fieldIx = 1:numel(variables)
                fieldName = variables{fieldIx};
                if ~isfield(loaded,fieldName)
                    error(['planWorkflow:persistence:SamplingPayloadArtifact:' ...
                        'InvalidPayloadFile'], ...
                        ['Sampling payload artifact %s is missing ' ...
                         'variable %s.'],cacheFile,fieldName);
                end
                payload.(fieldName) = loaded.(fieldName);
            end
        end

        function validateMetadata(metadata,ref,cacheFile)
            valid = isstruct(metadata) && isscalar(metadata) && ...
                isfield(metadata,'artifactKind') && ...
                strcmp(char(metadata.artifactKind), ...
                planWorkflow.persistence.SamplingPayloadArtifact.RefKind) && ...
                isfield(metadata,'schemaVersion') && ...
                metadata.schemaVersion == ...
                planWorkflow.persistence.SamplingPayloadArtifact.SchemaVersion && ...
                isfield(metadata,'payloadIdentityHash') && ...
                strcmp(char(metadata.payloadIdentityHash), ...
                char(ref.payloadIdentityHash)) && ...
                isfield(metadata,'artifactId') && ...
                isfield(ref,'artifactId') && ...
                strcmp(char(metadata.artifactId),char(ref.artifactId)) && ...
                isfield(metadata,'role') && ...
                strcmp(char(metadata.role),char(ref.role)) && ...
                isfield(metadata,'unitKey') && isfield(metadata,'planId') && ...
                isfield(metadata,'variantId') && ...
                isfield(metadata,'label') && isfield(metadata,'unitIndex') && ...
                isfield(metadata,'numSamples') && isfield(metadata,'variables');
            if valid
                valid = isequal( ...
                    planWorkflow.persistence.SamplingPayloadArtifact.normalizeFields( ...
                    metadata.variables), ...
                    planWorkflow.persistence.SamplingPayloadArtifact.normalizeFields( ...
                    ref.variables));
            end
            if valid && isfield(ref,'unitKey')
                valid = strcmp(char(metadata.unitKey),char(ref.unitKey));
            end
            if ~valid
                error(['planWorkflow:persistence:SamplingPayloadArtifact:' ...
                    'InvalidPayloadMetadata'], ...
                    'Sampling payload artifact metadata is invalid: %s.', ...
                    cacheFile);
            end
        end

        function metadata = metadata(payload,source,runConfig,role, ...
                fields,unitInfo)
            artifactId = ...
                planWorkflow.persistence.SamplingPayloadArtifact.artifactId();
            unitInfo = ...
                planWorkflow.persistence.SamplingPayloadArtifact.unitInfoFromSample( ...
                source,role,role,[],unitInfo);
            unitInfo.numSamples = ...
                planWorkflow.persistence.SamplingPayloadArtifact.numSamples( ...
                source,unitInfo.numSamples);

            identity = struct();
            identity.schemaVersion = ...
                planWorkflow.persistence.SamplingPayloadArtifact.SchemaVersion;
            identity.artifactId = artifactId;
            identity.artifactKey = char(role);
            identity.role = char(unitInfo.role);
            identity.unit = unitInfo;
            identity.variables = fields(:)';
            identity.run = ...
                planWorkflow.persistence.SamplingPayloadArtifact.runIdentity( ...
                runConfig);
            identity.payload = ...
                planWorkflow.persistence.SamplingPayloadArtifact.payloadSummary( ...
                payload,fields);
            payloadIdentityHash = ...
                planWorkflow.cache.CacheIdentity.valueHash(identity);

            metadata = struct();
            metadata.artifactKind = ...
                planWorkflow.persistence.SamplingPayloadArtifact.RefKind;
            metadata.schemaVersion = ...
                planWorkflow.persistence.SamplingPayloadArtifact.SchemaVersion;
            metadata.artifactId = artifactId;
            metadata.role = char(unitInfo.role);
            metadata.unitKey = char(unitInfo.unitKey);
            metadata.planId = char(unitInfo.planId);
            metadata.variantId = char(unitInfo.variantId);
            metadata.label = char(unitInfo.label);
            metadata.unitIndex = unitInfo.unitIndex;
            metadata.numSamples = unitInfo.numSamples;
            metadata.variables = fields(:)';
            metadata.payloadIdentityHash = payloadIdentityHash;
        end

        function ref = refFromMetadata(metadata,relativeFile)
            ref = struct();
            ref.artifactKind = ...
                planWorkflow.persistence.SamplingPayloadArtifact.RefKind;
            ref.schemaVersion = ...
                planWorkflow.persistence.SamplingPayloadArtifact.SchemaVersion;
            ref.artifactId = metadata.artifactId;
            ref.role = char(metadata.role);
            ref.unitKey = char(metadata.unitKey);
            ref.planId = char(metadata.planId);
            ref.variantId = char(metadata.variantId);
            ref.label = char(metadata.label);
            ref.unitIndex = metadata.unitIndex;
            ref.numSamples = metadata.numSamples;
            ref.variables = metadata.variables(:)';
            ref.cacheRelativeFile = relativeFile;
            ref.payloadIdentityHash = metadata.payloadIdentityHash;
        end

        function recordSampleUnit(sample,runConfig,cachePath,unitKey,unitInfo)
            if ~isstruct(sample) || ~isfield(sample,'samplingPayloadRef') || ...
                    ~planWorkflow.persistence.SamplingPayloadArtifact.isRef( ...
                    sample.samplingPayloadRef)
                return;
            end
            if ~planWorkflow.persistence.SamplingPayloadArtifact.payloadFileIsComplete( ...
                    sample.samplingPayloadRef,cachePath)
                return;
            end

            manifest = ...
                planWorkflow.persistence.SamplingPayloadArtifact.loadUnitManifest( ...
                runConfig,cachePath);
            unitInfo = ...
                planWorkflow.persistence.SamplingPayloadArtifact.unitInfoFromSample( ...
                sample,unitKey,unitKey,[],unitInfo);
            metadata = ...
                planWorkflow.persistence.SamplingPayloadArtifact.metadataFromRef( ...
                sample.samplingPayloadRef,unitInfo);

            unit = struct();
            unit.unitKey = char(unitKey);
            unit.ref = sample.samplingPayloadRef;
            unit.metadata = metadata;
            unit.sample = ...
                planWorkflow.results.SamplingDataCompactor.compactSample( ...
                sample);
            unit.updatedAt = char(datetime('now','Format', ...
                'yyyy-MM-dd HH:mm:ss'));

            unitIx = ...
                planWorkflow.persistence.SamplingPayloadArtifact.findManifestUnit( ...
                manifest,unitKey);
            if isempty(unitIx)
                manifest.units(end + 1) = unit;
            else
                manifest.units(unitIx) = unit;
            end
            planWorkflow.persistence.SamplingPayloadArtifact.saveUnitManifest( ...
                manifest,runConfig,cachePath);
        end

        function metadata = metadataFromRef(ref,unitInfo)
            metadata = struct();
            metadata.artifactKind = ref.artifactKind;
            metadata.schemaVersion = ref.schemaVersion;
            metadata.artifactId = ref.artifactId;
            metadata.role = char(ref.role);
            metadata.unitKey = char(unitInfo.unitKey);
            metadata.planId = char(unitInfo.planId);
            metadata.variantId = char(unitInfo.variantId);
            metadata.label = char(unitInfo.label);
            metadata.unitIndex = unitInfo.unitIndex;
            metadata.numSamples = ref.numSamples;
            metadata.variables = ref.variables(:)';
            metadata.payloadIdentityHash = ref.payloadIdentityHash;
        end

        function manifest = loadUnitManifest(runConfig,cachePath)
            manifest = ...
                planWorkflow.persistence.SamplingPayloadArtifact.emptyManifest();
            manifestFile = ...
                planWorkflow.persistence.SamplingPayloadArtifact.unitManifestFile( ...
                runConfig,cachePath);
            if exist(manifestFile,'file') ~= 2
                return;
            end
            try
                loaded = load(manifestFile,'samplingUnitManifest');
                if isfield(loaded,'samplingUnitManifest') && ...
                        isstruct(loaded.samplingUnitManifest) && ...
                        isfield(loaded.samplingUnitManifest,'units')
                    manifest = loaded.samplingUnitManifest;
                end
            catch
                manifest = ...
                    planWorkflow.persistence.SamplingPayloadArtifact.emptyManifest();
            end
        end

        function saveUnitManifest(manifest,runConfig,cachePath)
            manifestFile = ...
                planWorkflow.persistence.SamplingPayloadArtifact.unitManifestFile( ...
                runConfig,cachePath);
            planWorkflow.persistence.SamplingPayloadArtifact.ensureFolder( ...
                fileparts(manifestFile));
            payload = struct('samplingUnitManifest',manifest);
            planWorkflow.persistence.SamplingPayloadArtifact.atomicSave( ...
                manifestFile,payload);
        end

        function manifest = emptyManifest()
            manifest = struct();
            manifest.schemaVersion = ...
                planWorkflow.persistence.SamplingPayloadArtifact.ManifestSchemaVersion;
            manifest.units = ...
                planWorkflow.persistence.SamplingPayloadArtifact.emptyManifestUnits();
        end

        function units = emptyManifestUnits()
            units = repmat(struct('unitKey','', ...
                'ref',struct(), ...
                'metadata',struct(), ...
                'sample',struct(), ...
                'updatedAt',''),0,1);
        end

        function unitIx = findManifestUnit(manifest,unitKey)
            unitIx = [];
            if ~isstruct(manifest) || ~isfield(manifest,'units')
                return;
            end
            for ix = 1:numel(manifest.units)
                if isfield(manifest.units(ix),'unitKey') && ...
                        strcmp(char(manifest.units(ix).unitKey),char(unitKey))
                    unitIx = ix;
                    return;
                end
            end
        end

        function tf = unitMetadataCompatible(metadata,unitInfo)
            unitInfo = ...
                planWorkflow.persistence.SamplingPayloadArtifact.normalizeUnitInfo( ...
                unitInfo);
            required = {'role','unitKey','planId','variantId','label', ...
                'unitIndex'};
            tf = isstruct(metadata) && isscalar(metadata);
            for fieldIx = 1:numel(required)
                fieldName = required{fieldIx};
                tf = tf && isfield(metadata,fieldName);
                if ~tf
                    return;
                end
                if ischar(metadata.(fieldName)) || isstring(metadata.(fieldName))
                    tf = strcmp(char(metadata.(fieldName)), ...
                        char(unitInfo.(fieldName)));
                else
                    tf = isequal(metadata.(fieldName),unitInfo.(fieldName));
                end
                if ~tf
                    return;
                end
            end
        end

        function tf = payloadFileIsComplete(ref,cachePath)
            tf = false;
            if isempty(cachePath) || ...
                    ~planWorkflow.persistence.SamplingPayloadArtifact.isRef(ref) || ...
                    planWorkflow.persistence.SamplingPayloadArtifact.isTmpFile( ...
                    ref.cacheRelativeFile)
                return;
            end
            cacheFile = fullfile(cachePath,ref.cacheRelativeFile);
            if exist(cacheFile,'file') ~= 2
                return;
            end
            try
                fileInfo = whos('-file',cacheFile);
                names = {fileInfo.name};
                variables = ...
                    planWorkflow.persistence.SamplingPayloadArtifact.normalizeFields( ...
                    ref.variables);
                required = [{'samplingPayloadMetadata'},variables];
                if ~all(ismember(required,names))
                    return;
                end
                loaded = load(cacheFile,'samplingPayloadMetadata');
                planWorkflow.persistence.SamplingPayloadArtifact.validateMetadata( ...
                    loaded.samplingPayloadMetadata,ref,cacheFile);
                tf = true;
            catch
                tf = false;
            end
        end

        function sample = sampleFromUnitMetadata(metadata,ref)
            sample = struct();
            sample.label = char(metadata.label);
            sample.planId = char(metadata.planId);
            sample.variantId = char(metadata.variantId);
            sample.role = char(metadata.role);
            sample.samplingPayloadRef = ref;
        end

        function unitInfo = unitInfoFromSample(sample,role,unitKey, ...
                unitIndex,overrides)
            if nargin < 5
                overrides = struct();
            end
            unitInfo = struct();
            unitInfo.role = char(role);
            unitInfo.unitKey = char(unitKey);
            unitInfo.planId = '';
            unitInfo.variantId = '';
            unitInfo.label = '';
            unitInfo.unitIndex = unitIndex;
            unitInfo.numSamples = [];
            fields = {'role','planId','variantId','label'};
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                if isstruct(sample) && isfield(sample,fieldName) && ...
                        ~isempty(sample.(fieldName))
                    unitInfo.(fieldName) = char(sample.(fieldName));
                end
                if isstruct(overrides) && isfield(overrides,fieldName) && ...
                        ~isempty(overrides.(fieldName))
                    unitInfo.(fieldName) = char(overrides.(fieldName));
                end
            end
            if isstruct(overrides) && isfield(overrides,'unitKey') && ...
                    ~isempty(overrides.unitKey)
                unitInfo.unitKey = char(overrides.unitKey);
            end
            if isstruct(overrides) && isfield(overrides,'unitIndex') && ...
                    ~isempty(overrides.unitIndex)
                unitInfo.unitIndex = overrides.unitIndex;
            end
            if isstruct(overrides) && isfield(overrides,'numSamples') && ...
                    ~isempty(overrides.numSamples)
                unitInfo.numSamples = overrides.numSamples;
            end
            unitInfo = ...
                planWorkflow.persistence.SamplingPayloadArtifact.normalizeUnitInfo( ...
                unitInfo);
        end

        function unitInfo = normalizeUnitInfo(unitInfo)
            defaults = struct('role','', ...
                'unitKey','', ...
                'planId','', ...
                'variantId','', ...
                'label','', ...
                'unitIndex',[], ...
                'numSamples',[]);
            fields = fieldnames(defaults);
            if ~isstruct(unitInfo) || ~isscalar(unitInfo)
                unitInfo = struct();
            end
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                if ~isfield(unitInfo,fieldName)
                    unitInfo.(fieldName) = defaults.(fieldName);
                end
            end
            textFields = {'role','unitKey','planId','variantId','label'};
            for fieldIx = 1:numel(textFields)
                fieldName = textFields{fieldIx};
                unitInfo.(fieldName) = char(unitInfo.(fieldName));
            end
        end

        function count = numSamples(source,fallback)
            count = fallback;
            if isstruct(source) && isfield(source,'mSampDose') && ...
                    isnumeric(source.mSampDose)
                count = size(source.mSampDose,2);
            elseif isstruct(source) && isfield(source,'caSamp') && ...
                    iscell(source.caSamp)
                count = numel(source.caSamp);
            end
        end

        function atomicSave(cacheFile,payload)
            tmpFile = [cacheFile '.tmp'];
            if exist(tmpFile,'file') == 2
                delete(tmpFile);
            end
            cleanup = onCleanup(@() ...
                planWorkflow.persistence.SamplingPayloadArtifact.deleteTmpFile( ...
                tmpFile));
            builtin('save',tmpFile,'-struct','payload','-v7.3');
            movefile(tmpFile,cacheFile,'f');
            clear cleanup;
        end

        function deleteTmpFile(tmpFile)
            if exist(tmpFile,'file') == 2
                delete(tmpFile);
            end
        end

        function tf = isTmpFile(fileName)
            fileName = char(fileName);
            tf = numel(fileName) >= 4 && strcmp(fileName(end-3:end),'.tmp');
        end

        function id = artifactId()
            id = char(java.util.UUID.randomUUID());
        end

        function identity = runIdentity(runConfig)
            identity = struct();
            fields = {'runId','description','caseID','radiationMode', ...
                'workflowType','plan_template','plan_beams'};
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                if isstruct(runConfig) && isfield(runConfig,fieldName) && ...
                        ~isempty(runConfig.(fieldName))
                    identity.(fieldName) = char(runConfig.(fieldName));
                else
                    identity.(fieldName) = '';
                end
            end
        end

        function summary = payloadSummary(payload,fields)
            summary = repmat(struct( ...
                'name','', ...
                'class','', ...
                'size',[], ...
                'bytes',0),1,0);
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                value = payload.(fieldName); %#ok<NASGU>
                info = whos('value');
                item = struct();
                item.name = fieldName;
                item.class = class(payload.(fieldName));
                item.size = size(payload.(fieldName));
                item.bytes = info.bytes;
                summary(end + 1) = item; %#ok<AGROW>
            end
        end

        function relativeFile = relativeFile(runConfig,role,identityHash)
            runId = ...
                planWorkflow.persistence.SamplingPayloadArtifact.runId( ...
                runConfig);
            shortHash = char(identityHash);
            shortHash = shortHash(1:min(16,numel(shortHash)));
            fileName = sprintf('%s_%s.mat', ...
                planWorkflow.persistence.SamplingPayloadArtifact.safeName( ...
                role),shortHash);
            relativeFile = fullfile('sampling_payloads',runId,fileName);
        end

        function manifestFile = unitManifestFile(runConfig,cachePath)
            manifestFile = fullfile(cachePath,'sampling_payloads', ...
                planWorkflow.persistence.SamplingPayloadArtifact.runId( ...
                runConfig),'sampling_unit_manifest.mat');
        end

        function runId = runId(runConfig)
            runId = 'unspecified_run';
            if isstruct(runConfig) && isfield(runConfig,'runId') && ...
                    ~isempty(runConfig.runId)
                runId = char(runConfig.runId);
            end
            runId = planWorkflow.persistence.SamplingPayloadArtifact.safeName( ...
                runId);
        end

        function value = safeName(value)
            value = regexprep(char(value),'[^A-Za-z0-9_.-]','_');
            if isempty(value)
                value = 'unnamed';
            end
        end

        function fields = presentFields(input,fields)
            fields = ...
                planWorkflow.persistence.SamplingPayloadArtifact.normalizeFields( ...
                fields);
            keep = false(size(fields));
            for fieldIx = 1:numel(fields)
                keep(fieldIx) = isstruct(input) && ...
                    isfield(input,fields{fieldIx});
            end
            fields = fields(keep);
        end

        function tf = hasAllFields(input,fields)
            fields = ...
                planWorkflow.persistence.SamplingPayloadArtifact.normalizeFields( ...
                fields);
            tf = isstruct(input);
            for fieldIx = 1:numel(fields)
                tf = tf && isfield(input,fields{fieldIx});
            end
        end

        function output = mergePayload(output,payload)
            fields = fieldnames(payload);
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                output.(fieldName) = payload.(fieldName);
            end
        end

        function fields = normalizeFields(fields)
            if ischar(fields) || (isstring(fields) && isscalar(fields))
                fields = {char(fields)};
            elseif isstring(fields)
                fields = cellstr(fields);
            end
            fields = fields(:)';
        end

        function fields = rootFields()
            fields = {'ct','cst','multScen'};
        end

        function fields = sampleFields()
            fields = {'caSamp','mSampDose','resultGUINomScen'};
        end

        function ensureFolder(folder)
            if exist(folder,'dir') ~= 7
                mkdir(folder);
            end
        end
    end
end
