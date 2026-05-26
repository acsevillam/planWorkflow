classdef PrecomputeCacheCompatibility
    % PrecomputeCacheCompatibility Shared precompute cache validation helpers.

    methods (Static)
        function [tf,reason] = isRobustScenarioCompatible( ...
                cacheMetadata,robustData)
            [tf,reason] = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.isDiscoveryScenarioCompatible( ...
                cacheMetadata,robustData);
        end

        function [tf,reason] = isDiscoveryScenarioCompatible( ...
                cacheMetadata,robustData)
            tf = true;
            reason = '';
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

            expectedFingerprint = ...
                planWorkflow.cache.CacheIdentity.scenarioFingerprint( ...
                robustData.pln.multScen);
            tf = strcmp(char(cacheMetadata.scenarioFingerprint), ...
                char(expectedFingerprint));
            if ~tf
                reason = ['cache scenario fingerprint does not match ' ...
                    'the current robust plan scenario model'];
                return;
            end
            if isfield(cacheMetadata,'numOfScenarios') && ...
                    ~isempty(cacheMetadata.numOfScenarios) && ...
                    cacheMetadata.numOfScenarios ~= ...
                    robustData.pln.multScen.numScenarios()
                tf = false;
                reason = ['cache scenario count does not match the ' ...
                    'current robust plan scenario model'];
            end
        end

        function [tf,reason] = isPersistedRefScenarioCompatible( ...
                cacheMetadata,ref)
            tf = true;
            reason = '';
            if ~isstruct(ref)
                return;
            end

            hasRefFingerprint = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.hasTextField( ...
                ref,'scenarioFingerprint');
            if hasRefFingerprint
                if ~isstruct(cacheMetadata) || ...
                        ~isfield(cacheMetadata,'scenarioFingerprint') || ...
                        isempty(cacheMetadata.scenarioFingerprint)
                    tf = false;
                    reason = ['declared ref includes a scenario ' ...
                        'fingerprint, but cache metadata does not'];
                    return;
                end
                if ~strcmp(char(cacheMetadata.scenarioFingerprint), ...
                        char(ref.scenarioFingerprint))
                    tf = false;
                    reason = ['cache scenario fingerprint does not ' ...
                        'match the persisted ref'];
                    return;
                end
            end

            hasRefScenarioCount = isfield(ref,'numOfScenarios') && ...
                ~isempty(ref.numOfScenarios);
            if hasRefScenarioCount
                if ~isstruct(cacheMetadata) || ...
                        ~isfield(cacheMetadata,'numOfScenarios') || ...
                        isempty(cacheMetadata.numOfScenarios)
                    tf = false;
                    reason = ['declared ref includes a scenario count, ' ...
                        'but cache metadata does not'];
                    return;
                end
                if cacheMetadata.numOfScenarios ~= ref.numOfScenarios
                    tf = false;
                    reason = ['cache scenario count does not match ' ...
                        'the persisted ref'];
                end
            end
        end

        function reason = compatibilityReport(cacheMetadata,robustData, ...
                ref,mode)
            if nargin < 4 || isempty(mode)
                mode = 'discovery';
            end
            switch char(mode)
                case 'discovery'
                    [tf,reason] = ...
                        planWorkflow.precompute.PrecomputeCacheCompatibility.isDiscoveryScenarioCompatible( ...
                        cacheMetadata,robustData);
                case 'rehydrate'
                    [tf,reason] = ...
                        planWorkflow.precompute.PrecomputeCacheCompatibility.isPersistedRefScenarioCompatible( ...
                        cacheMetadata,ref);
                otherwise
                    tf = false;
                    reason = sprintf('unknown cache compatibility mode "%s"', ...
                        char(mode));
            end
            if tf
                reason = '';
            end
        end
    end

    methods (Static, Access = private)
        function tf = hasTextField(value,fieldName)
            tf = isstruct(value) && isfield(value,fieldName) && ...
                ~isempty(value.(fieldName)) && ...
                ~isempty(char(value.(fieldName)));
        end
    end
end
