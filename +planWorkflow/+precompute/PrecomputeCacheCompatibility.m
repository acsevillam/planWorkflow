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

        function [tf,reason] = isPersistedRefClinicalContextCompatible( ...
                cacheMetadata,ref,context,payloadKind)
            if nargin < 3 || isempty(context)
                context = struct();
            end
            if nargin < 4
                payloadKind = '';
            end

            [tf,reason] = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.isPersistedRefScenarioCompatible( ...
                cacheMetadata,ref);
            if ~tf
                return;
            end

            [tf,reason] = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.compareRefTextField( ...
                cacheMetadata,ref,'planId','plan id');
            if ~tf
                return;
            end
            [tf,reason] = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.compareRefTextField( ...
                cacheMetadata,ref,'robustnessMode','robustness mode');
            if ~tf
                return;
            end

            [tf,reason] = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.compareRefIdentityHash( ...
                cacheMetadata,ref,'cstHash','cst','CST');
            if ~tf
                return;
            end
            [tf,reason] = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.compareRefIdentityHash( ...
                cacheMetadata,ref,'stfHash','stf','STF');
            if ~tf
                return;
            end
            [tf,reason] = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.compareRefPayloadContextHash( ...
                cacheMetadata,ref,payloadKind);
            if ~tf
                return;
            end

            [tf,reason] = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.compareContextCst( ...
                cacheMetadata,context);
            if ~tf
                return;
            end
            [tf,reason] = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.compareContextStf( ...
                cacheMetadata,context);
        end

        function hash = cacheIdentityComponentHash(cacheMetadata, ...
                componentName)
            hash = '';
            if ~isstruct(cacheMetadata) || ...
                    ~isfield(cacheMetadata,'cacheIdentity') || ...
                    ~isstruct(cacheMetadata.cacheIdentity) || ...
                    ~isfield(cacheMetadata.cacheIdentity,componentName)
                return;
            end
            hash = planWorkflow.cache.CacheIdentity.valueHash( ...
                cacheMetadata.cacheIdentity.(componentName));
        end

        function hash = payloadContextHash(cacheMetadata,cacheKind)
            hash = '';
            componentName = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.payloadComponentName( ...
                cacheKind);
            if isempty(componentName)
                return;
            end
            hash = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.cacheIdentityComponentHash( ...
                cacheMetadata,componentName);
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
        function [tf,reason] = compareRefTextField(cacheMetadata,ref, ...
                fieldName,label)
            tf = true;
            reason = '';
            if ~planWorkflow.precompute.PrecomputeCacheCompatibility.hasTextField( ...
                    ref,fieldName)
                return;
            end
            if ~isstruct(cacheMetadata) || ...
                    ~isfield(cacheMetadata,fieldName) || ...
                    isempty(cacheMetadata.(fieldName))
                tf = false;
                reason = sprintf(['declared ref includes %s, but cache ' ...
                    'metadata does not'],char(label));
                return;
            end
            tf = strcmp(char(cacheMetadata.(fieldName)), ...
                char(ref.(fieldName)));
            if ~tf
                reason = sprintf('cache %s does not match the persisted ref', ...
                    char(label));
            end
        end

        function [tf,reason] = compareRefIdentityHash(cacheMetadata,ref, ...
                refFieldName,componentName,label)
            tf = true;
            reason = '';
            if ~planWorkflow.precompute.PrecomputeCacheCompatibility.hasTextField( ...
                    ref,refFieldName)
                return;
            end
            actualHash = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.cacheIdentityComponentHash( ...
                cacheMetadata,componentName);
            if isempty(actualHash)
                tf = false;
                reason = sprintf(['declared ref includes %s hash, but ' ...
                    'cache metadata does not'],char(label));
                return;
            end
            tf = strcmp(char(actualHash),char(ref.(refFieldName)));
            if ~tf
                reason = sprintf(['cache %s metadata does not match the ' ...
                    'persisted ref'],char(label));
            end
        end

        function [tf,reason] = compareRefPayloadContextHash( ...
                cacheMetadata,ref,payloadKind)
            tf = true;
            reason = '';
            if ~planWorkflow.precompute.PrecomputeCacheCompatibility.hasTextField( ...
                    ref,'payloadContextHash')
                return;
            end
            actualHash = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.payloadContextHash( ...
                cacheMetadata,payloadKind);
            if isempty(actualHash)
                tf = false;
                reason = ['declared ref includes payload context hash, ' ...
                    'but cache metadata does not'];
                return;
            end
            tf = strcmp(char(actualHash),char(ref.payloadContextHash));
            if ~tf
                reason = ['cache payload context does not match the ' ...
                    'persisted ref'];
            end
        end

        function [tf,reason] = compareContextCst(cacheMetadata,context)
            tf = true;
            reason = '';
            if ~isstruct(context) || ~isfield(context,'cst') || ...
                    isempty(context.cst)
                return;
            end
            actualHash = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.cacheIdentityComponentHash( ...
                cacheMetadata,'cst');
            if isempty(actualHash)
                tf = false;
                reason = ['cache metadata does not include CST identity ' ...
                    'required by the rehydration context'];
                return;
            end
            expectedHash = planWorkflow.cache.CacheIdentity.valueHash( ...
                planWorkflow.cache.CacheIdentity.cstIdentity(context.cst));
            tf = strcmp(char(actualHash),char(expectedHash));
            if ~tf
                reason = ['cache CST metadata does not match the ' ...
                    'rehydration context'];
            end
        end

        function [tf,reason] = compareContextStf(cacheMetadata,context)
            tf = true;
            reason = '';
            if ~isstruct(context) || ~isfield(context,'stf') || ...
                    isempty(context.stf)
                return;
            end
            actualHash = ...
                planWorkflow.precompute.PrecomputeCacheCompatibility.cacheIdentityComponentHash( ...
                cacheMetadata,'stf');
            if isempty(actualHash)
                tf = false;
                reason = ['cache metadata does not include STF identity ' ...
                    'required by the rehydration context'];
                return;
            end
            expectedHash = planWorkflow.cache.CacheIdentity.valueHash( ...
                planWorkflow.cache.DoseInfluenceCache.stfSignature( ...
                context.stf));
            tf = strcmp(char(actualHash),char(expectedHash));
            if ~tf
                reason = ['cache STF metadata does not match the ' ...
                    'rehydration context'];
            end
        end

        function componentName = payloadComponentName(cacheKind)
            switch char(cacheKind)
                case 'prob'
                    componentName = 'prob';
                case 'interval'
                    componentName = 'interval';
                otherwise
                    componentName = '';
            end
        end

        function tf = hasTextField(value,fieldName)
            tf = isstruct(value) && isfield(value,fieldName) && ...
                ~isempty(value.(fieldName)) && ...
                ~isempty(char(value.(fieldName)));
        end
    end
end
