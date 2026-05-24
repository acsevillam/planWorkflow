classdef PrecomputeCacheCompatibility
    % PrecomputeCacheCompatibility Shared precompute cache validation helpers.

    methods (Static)
        function tf = isRobustScenarioCompatible(cacheMetadata,robustData)
            tf = true;
            if ~isstruct(cacheMetadata) || ...
                    ~isfield(cacheMetadata,'scenarioFingerprint')
                return;
            end
            if ~isstruct(robustData) || ~isfield(robustData,'pln') || ...
                    ~isstruct(robustData.pln) || ...
                    ~isfield(robustData.pln,'multScen') || ...
                    ~isa(robustData.pln.multScen,'matRad_ScenarioModel')
                return;
            end

            tf = strcmp(cacheMetadata.scenarioFingerprint, ...
                planWorkflow.cache.CacheIdentity.scenarioFingerprint( ...
                robustData.pln.multScen));
        end
    end
end
