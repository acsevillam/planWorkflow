classdef DoseInfluenceCacheRef
    % DoseInfluenceCacheRef Persistable identity for cached dij artifacts.

    properties (Constant)
        ArtifactKind = 'planWorkflowDoseInfluenceCacheRef'
        SchemaVersion = 2
    end

    methods (Static)
        function ref = create(cacheKind,tag,cacheFile,cachePath, ...
                cacheMetadata,variables,totalNumOfBixels)
            if nargin < 6 || isempty(variables)
                variables = {};
            end
            if nargin < 7
                totalNumOfBixels = [];
            end
            if ischar(variables) || (isstring(variables) && isscalar(variables))
                variables = {char(variables)};
            elseif isstring(variables)
                variables = cellstr(variables);
            end
            if ~isfield(cacheMetadata,'cacheIdentityHash')
                error(['planWorkflow:cache:DoseInfluenceCacheRef:' ...
                    'MissingIdentityHash'], ...
                    'Dose influence cache metadata must include cacheIdentityHash.');
            end
            cachePhysicalTag = ...
                planWorkflow.cache.DoseInfluenceCacheRef.metadataPhysicalTag( ...
                cacheMetadata);
            if isempty(cachePhysicalTag)
                error(['planWorkflow:cache:DoseInfluenceCacheRef:' ...
                    'MissingPhysicalTag'], ...
                    ['Dose influence cache metadata must include ' ...
                    'cacheIdentity.tag.']);
            end

            ref = struct();
            ref.artifactKind = planWorkflow.cache.DoseInfluenceCacheRef.ArtifactKind;
            ref.schemaVersion = ...
                planWorkflow.cache.DoseInfluenceCacheRef.SchemaVersion;
            ref.cacheKind = char(cacheKind);
            ref.tag = char(tag);
            ref.cacheRelativeFile = ...
                planWorkflow.cache.DoseInfluenceCacheRef.relativeFile( ...
                cacheFile,cachePath);
            ref.cacheIdentityHash = cacheMetadata.cacheIdentityHash;
            ref.producerTag = ...
                planWorkflow.cache.DoseInfluenceCacheRef.metadataProducerTag( ...
                cacheMetadata);
            ref.cachePhysicalTag = cachePhysicalTag;
            ref.variables = variables(:)';
            ref.totalNumOfBixels = totalNumOfBixels;
            if isfield(cacheMetadata,'scenarioFingerprint') && ...
                    ~isempty(cacheMetadata.scenarioFingerprint)
                ref.scenarioFingerprint = ...
                    char(cacheMetadata.scenarioFingerprint);
            end
            if isfield(cacheMetadata,'numOfScenarios') && ...
                    ~isempty(cacheMetadata.numOfScenarios)
                ref.numOfScenarios = cacheMetadata.numOfScenarios;
            end
        end

        function assertMatchesMetadata(ref,cacheMetadata,cacheFile, ...
                role,errorPrefix)
            if nargin < 4 || isempty(role)
                role = 'dose influence';
            end
            if nargin < 5 || isempty(errorPrefix)
                errorPrefix = 'planWorkflow:cache:DoseInfluenceCacheRef';
            end

            if ~isstruct(ref) || ~isfield(ref,'cacheIdentityHash') || ...
                    ~isstruct(cacheMetadata) || ...
                    ~isfield(cacheMetadata,'cacheIdentityHash') || ...
                    ~strcmp(char(cacheMetadata.cacheIdentityHash), ...
                    char(ref.cacheIdentityHash))
                error([char(errorPrefix) ':DijCacheRefIdentityMismatch'], ...
                    ['Cannot persist or resume %s from cache "%s": ' ...
                    'identity hash does not match the declared ref.'], ...
                    char(role),cacheFile);
            end

            if ~planWorkflow.cache.DoseInfluenceCacheRef.hasTextField( ...
                    ref,'cachePhysicalTag')
                error([char(errorPrefix) ':DijCacheRefTagMismatch'], ...
                    ['Cannot persist or resume %s from cache "%s": ' ...
                    'declared ref does not include cachePhysicalTag.'], ...
                    char(role),cacheFile);
            end

            expectedTag = char(ref.cachePhysicalTag);
            actualTag = ...
                planWorkflow.cache.DoseInfluenceCacheRef.metadataPhysicalTag( ...
                cacheMetadata);
            if isempty(actualTag) || ~strcmp(actualTag,expectedTag)
                error([char(errorPrefix) ':DijCacheRefTagMismatch'], ...
                    ['Cannot persist or resume %s from cache "%s": ' ...
                    'physical cache tag does not match the declared ref.'], ...
                    char(role),cacheFile);
            end

            [scenarioCompatible,scenarioReason] = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.isPersistedRefScenarioCompatible( ...
                cacheMetadata,ref);
            if ~scenarioCompatible
                error([char(errorPrefix) ':DijCacheRefScenarioMismatch'], ...
                    ['Cannot persist or resume %s from cache "%s": ' ...
                    '%s.'],char(role),cacheFile,char(scenarioReason));
            end
        end

        function tf = isRef(value)
            tf = isstruct(value) && isfield(value,'artifactKind') && ...
                strcmp(char(value.artifactKind), ...
                planWorkflow.cache.DoseInfluenceCacheRef.ArtifactKind);
        end

        function count = totalNumOfBixels(value)
            count = ...
                planWorkflow.precompute.OptimizationInput.totalNumOfBixels( ...
                value);
        end

        function tag = metadataProducerTag(cacheMetadata)
            tag = '';
            if isstruct(cacheMetadata) && isfield(cacheMetadata,'tag') && ...
                    ~isempty(cacheMetadata.tag)
                tag = char(cacheMetadata.tag);
            end
        end

        function tag = metadataPhysicalTag(cacheMetadata)
            tag = '';
            if ~isstruct(cacheMetadata)
                return;
            end
            if isfield(cacheMetadata,'cacheIdentity') && ...
                    isstruct(cacheMetadata.cacheIdentity) && ...
                    isfield(cacheMetadata.cacheIdentity,'tag') && ...
                    ~isempty(cacheMetadata.cacheIdentity.tag)
                tag = char(cacheMetadata.cacheIdentity.tag);
                return;
            end
        end
    end

    methods (Static, Access = private)
        function tf = hasTextField(value,fieldName)
            tf = isstruct(value) && isfield(value,fieldName) && ...
                ~isempty(value.(fieldName)) && ...
                ~isempty(char(value.(fieldName)));
        end

        function rel = relativeFile(filePath,rootPath)
            prefix = [char(rootPath) filesep];
            filePath = char(filePath);
            if startsWith(filePath,prefix)
                rel = filePath(numel(prefix) + 1:end);
            else
                rel = filePath;
            end
        end
    end
end
