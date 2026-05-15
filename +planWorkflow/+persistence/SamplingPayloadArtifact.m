classdef SamplingPayloadArtifact
    % SamplingPayloadArtifact Stores heavy sampling payloads outside snapshots.

    properties (Constant)
        SchemaVersion = 1
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
                    planWorkflow.persistence.SamplingPayloadArtifact.compactRootPayload( ...
                    samplingData,runConfig,cachePath);
                if isfield(samplingData,'reference')
                    samplingData.reference = ...
                        planWorkflow.persistence.SamplingPayloadArtifact.compactSamplePayload( ...
                        samplingData.reference,runConfig,cachePath, ...
                        'reference');
                end
                if isfield(samplingData,'robust') && ...
                        iscell(samplingData.robust)
                    for sampleIx = 1:numel(samplingData.robust)
                        role = sprintf('robust_%d',sampleIx);
                        samplingData.robust{sampleIx} = ...
                            planWorkflow.persistence.SamplingPayloadArtifact.compactSamplePayload( ...
                            samplingData.robust{sampleIx},runConfig, ...
                            cachePath,role);
                    end
                end
            end

            samplingData = ...
                planWorkflow.results.SamplingDataCompactor.compactSamplingData( ...
                samplingData);
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
        function samplingData = compactRootPayload(samplingData, ...
                runConfig,cachePath)
            fields = ...
                planWorkflow.persistence.SamplingPayloadArtifact.presentFields( ...
                samplingData, ...
                planWorkflow.persistence.SamplingPayloadArtifact.rootFields());
            if isempty(fields)
                return;
            end
            samplingData.samplingPayloadRef = ...
                planWorkflow.persistence.SamplingPayloadArtifact.savePayload( ...
                samplingData,runConfig,cachePath,'sampling_root',fields);
        end

        function sample = compactSamplePayload(sample,runConfig,cachePath, ...
                role)
            if ~isstruct(sample) || isempty(sample)
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
                sample,runConfig,cachePath,role,fields);
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

        function ref = savePayload(source,runConfig,cachePath,role,fields)
            payload = struct();
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                payload.(fieldName) = source.(fieldName);
            end

            metadata = ...
                planWorkflow.persistence.SamplingPayloadArtifact.metadata( ...
                payload,runConfig,role,fields);
            payload.samplingPayloadMetadata = metadata;
            relativeFile = ...
                planWorkflow.persistence.SamplingPayloadArtifact.relativeFile( ...
                runConfig,role,metadata.payloadIdentityHash);
            cacheFile = fullfile(cachePath,relativeFile);
            planWorkflow.persistence.SamplingPayloadArtifact.ensureFolder( ...
                fileparts(cacheFile));
            builtin('save',cacheFile,'-struct','payload','-v7.3');

            ref = struct();
            ref.artifactKind = ...
                planWorkflow.persistence.SamplingPayloadArtifact.RefKind;
            ref.schemaVersion = ...
                planWorkflow.persistence.SamplingPayloadArtifact.SchemaVersion;
            ref.artifactId = metadata.artifactId;
            ref.role = char(role);
            ref.variables = fields(:)';
            ref.cacheRelativeFile = relativeFile;
            ref.payloadIdentityHash = metadata.payloadIdentityHash;
        end

        function payload = loadPayload(ref,cachePath)
            if isempty(cachePath)
                error(['planWorkflow:persistence:SamplingPayloadArtifact:' ...
                    'MissingCachePath'], ...
                    ['Sampling payload materialization requires ' ...
                     'runConfig.cacheRootPath.']);
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
                strcmp(char(metadata.role),char(ref.role));
            if ~valid
                error(['planWorkflow:persistence:SamplingPayloadArtifact:' ...
                    'InvalidPayloadMetadata'], ...
                    'Sampling payload artifact metadata is invalid: %s.', ...
                    cacheFile);
            end
        end

        function metadata = metadata(payload,runConfig,role,fields)
            artifactId = ...
                planWorkflow.persistence.SamplingPayloadArtifact.artifactId();
            identity = struct();
            identity.schemaVersion = ...
                planWorkflow.persistence.SamplingPayloadArtifact.SchemaVersion;
            identity.artifactId = artifactId;
            identity.role = char(role);
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
            metadata.role = char(role);
            metadata.variables = fields(:)';
            metadata.payloadIdentityHash = payloadIdentityHash;
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
