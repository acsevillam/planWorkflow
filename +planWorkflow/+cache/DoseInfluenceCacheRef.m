classdef DoseInfluenceCacheRef
    % DoseInfluenceCacheRef Persistable identity for cached dij artifacts.

    properties (Constant)
        ArtifactKind = 'planWorkflowDoseInfluenceCacheRef'
        SchemaVersion = 1
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
            ref.variables = variables(:)';
            ref.totalNumOfBixels = totalNumOfBixels;
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
    end

    methods (Static, Access = private)
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
