classdef PrecomputeTiming
    % PrecomputeTiming Builds dose-influence precompute timing metadata.

    methods (Static)
        function options = cacheOptions(role,label,artifact,referenceTiming, ...
                referenceSize)
            if nargin < 4
                referenceTiming = [];
            end
            if nargin < 5
                referenceSize = [];
            end
            options = struct();
            options.role = char(role);
            options.label = char(label);
            options.artifact = char(artifact);
            options.referenceTiming = referenceTiming;
            options.referenceSize = referenceSize;
        end

        function timing = fromOptions(timeSeconds,options)
            if nargin < 2 || ~isstruct(options)
                options = planWorkflow.performance.PrecomputeTiming.cacheOptions( ...
                    '','','',[],[]);
            end
            timing = planWorkflow.performance.PrecomputeTiming.single( ...
                timeSeconds, ...
                planWorkflow.performance.PrecomputeTiming.text( ...
                options,'role'), ...
                planWorkflow.performance.PrecomputeTiming.text( ...
                options,'label'), ...
                planWorkflow.performance.PrecomputeTiming.text( ...
                options,'artifact'), ...
                planWorkflow.performance.PrecomputeTiming.field( ...
                options,'referenceTiming',[]));
        end

        function timing = single(timeSeconds,role,label,artifact, ...
                referenceTiming)
            if nargin < 5
                referenceTiming = [];
            end
            component = ...
                planWorkflow.performance.PrecomputeTiming.component( ...
                role,artifact,label,timeSeconds,referenceTiming);
            timing = planWorkflow.performance.PrecomputeTiming.fromComponents( ...
                component,referenceTiming,label,role);
        end

        function timing = combine(inputTiming,derivedRole,derivedArtifact, ...
                derivedTimeSeconds,label)
            if nargin < 5
                label = '';
            end
            [normalizedInput,hasInput] = ...
                planWorkflow.performance.PrecomputeTiming.normalize( ...
                inputTiming);
            if hasInput
                referenceTiming = normalizedInput;
                components = normalizedInput.components;
            else
                referenceTiming = [];
                components = planWorkflow.performance.PrecomputeTiming.emptyComponents();
            end
            derivedComponent = ...
                planWorkflow.performance.PrecomputeTiming.component( ...
                derivedRole,derivedArtifact,label,derivedTimeSeconds, ...
                referenceTiming);
            components(end + 1) = derivedComponent;
            timing = planWorkflow.performance.PrecomputeTiming.fromComponents( ...
                components,referenceTiming,label,derivedRole);
        end

        function [timing,tf] = normalize(value)
            timing = struct();
            tf = false;
            if ~isstruct(value) || ~isscalar(value)
                return;
            end

            totalTimeSeconds = ...
                planWorkflow.performance.PrecomputeTiming.numeric( ...
                value,'totalTimeSeconds',NaN);
            if ~planWorkflow.performance.PrecomputeTiming.isFiniteNonnegative( ...
                    totalTimeSeconds)
                return;
            end

            reference = ...
                planWorkflow.performance.PrecomputeTiming.reference(value);
            relativeTime = ...
                planWorkflow.performance.PrecomputeTiming.numeric( ...
                value,'relativeTime',NaN);
            if ~isfinite(relativeTime) && ...
                    planWorkflow.performance.PrecomputeTiming.isPositive( ...
                    reference.timeSeconds)
                relativeTime = totalTimeSeconds / reference.timeSeconds;
            end

            timing = struct();
            timing.schemaVersion = 1;
            timing.totalTimeSeconds = totalTimeSeconds;
            timing.relativeTime = relativeTime;
            timing.reference = reference;
            timing.components = ...
                planWorkflow.performance.PrecomputeTiming.normalizeComponents( ...
                planWorkflow.performance.PrecomputeTiming.field( ...
                value,'components', ...
                planWorkflow.performance.PrecomputeTiming.emptyComponents()), ...
                reference);
            tf = true;
        end

        function tf = isValid(value)
            [~,tf] = planWorkflow.performance.PrecomputeTiming.normalize(value);
        end

        function timing = asReference(timing,label)
            [timing,tf] = ...
                planWorkflow.performance.PrecomputeTiming.normalize(timing);
            if ~tf
                timing = [];
                return;
            end
            if nargin < 2 || isempty(label)
                label = timing.reference.label;
            end
            timing.reference.label = char(label);
            timing.reference.timeSeconds = timing.totalTimeSeconds;
            timing.relativeTime = NaN;
            if planWorkflow.performance.PrecomputeTiming.isPositive( ...
                    timing.totalTimeSeconds)
                timing.relativeTime = 1;
                for componentIx = 1:numel(timing.components)
                    timing.components(componentIx).relativeTime = ...
                        timing.components(componentIx).timeSeconds / ...
                        timing.totalTimeSeconds;
                end
            end
        end

        function timing = fromCacheMetadata(cacheMetadata)
            [timing,tf] = planWorkflow.performance.PrecomputeTiming.normalize( ...
                cacheMetadata.dijPrecomputingTiming);
            if ~tf
                timing = [];
            end
        end

        function timings = enrich(timings)
            if ~isstruct(timings) || isempty(timings)
                return;
            end

            for timingIx = 1:numel(timings)
                if ~planWorkflow.performance.PrecomputeTiming.isCompletedRecord( ...
                        timings(timingIx))
                    continue;
                end
                if ~isfield(timings(timingIx),'detail') || ...
                        isempty(timings(timingIx).detail)
                    continue;
                end
                detail = ...
                    planWorkflow.performance.PrecomputeTiming.detailStruct( ...
                    timings(timingIx));
                if ~isfield(detail,'dijPrecomputingTiming')
                    continue;
                end
                [dijTiming,tf] = ...
                    planWorkflow.performance.PrecomputeTiming.normalize( ...
                    detail.dijPrecomputingTiming);
                if ~tf
                    continue;
                end
                timings(timingIx) = ...
                    planWorkflow.performance.PrecomputeTiming.applyToRecord( ...
                    timings(timingIx),dijTiming);
                detail.dijPrecomputingTiming = dijTiming;
                timings(timingIx).detail = jsonencode(detail);
            end
        end

        function record = applyToRecord(record,dijTiming)
            [dijTiming,tf] = ...
                planWorkflow.performance.PrecomputeTiming.normalize( ...
                dijTiming);
            if ~tf
                return;
            end
            record.dijPrecomputingTimeSeconds = dijTiming.totalTimeSeconds;
            record.relativeDijPrecomputingTime = dijTiming.relativeTime;
            record.dijPrecomputingReferenceLabel = ...
                dijTiming.reference.label;
            record.dijPrecomputingReferenceTimeSeconds = ...
                dijTiming.reference.timeSeconds;
        end
    end

    methods (Static, Access = private)
        function timing = fromComponents(components,referenceTiming,label,role)
            if nargin < 3
                label = '';
            end
            if nargin < 4
                role = '';
            end
            components = ...
                planWorkflow.performance.PrecomputeTiming.normalizeComponents( ...
                components, ...
                planWorkflow.performance.PrecomputeTiming.reference( ...
                referenceTiming));
            totalTimeSeconds = 0;
            for i = 1:numel(components)
                totalTimeSeconds = totalTimeSeconds + components(i).timeSeconds;
            end

            reference = ...
                planWorkflow.performance.PrecomputeTiming.reference( ...
                referenceTiming);
            if ~planWorkflow.performance.PrecomputeTiming.isPositive( ...
                    reference.timeSeconds) && strcmp(char(role),'reference')
                reference.label = char(label);
                reference.timeSeconds = totalTimeSeconds;
            end

            relativeTime = NaN;
            if planWorkflow.performance.PrecomputeTiming.isPositive( ...
                    reference.timeSeconds)
                relativeTime = totalTimeSeconds / reference.timeSeconds;
            end

            for i = 1:numel(components)
                if ~isfinite(components(i).relativeTime) && ...
                        planWorkflow.performance.PrecomputeTiming.isPositive( ...
                        reference.timeSeconds)
                    components(i).relativeTime = ...
                        components(i).timeSeconds / reference.timeSeconds;
                end
            end

            timing = struct();
            timing.schemaVersion = 1;
            timing.totalTimeSeconds = totalTimeSeconds;
            timing.relativeTime = relativeTime;
            timing.reference = reference;
            timing.components = components;
        end

        function component = component(role,artifact,label,timeSeconds, ...
                referenceTiming)
            component = struct();
            component.role = char(role);
            component.artifact = char(artifact);
            component.label = char(label);
            component.timeSeconds = double(timeSeconds);
            component.relativeTime = NaN;
            reference = ...
                planWorkflow.performance.PrecomputeTiming.reference( ...
                referenceTiming);
            if planWorkflow.performance.PrecomputeTiming.isPositive( ...
                    reference.timeSeconds)
                component.relativeTime = ...
                    component.timeSeconds / reference.timeSeconds;
            elseif strcmp(char(role),'reference') && ...
                    planWorkflow.performance.PrecomputeTiming.isPositive( ...
                    component.timeSeconds)
                component.relativeTime = 1;
            end
        end

        function components = normalizeComponents(components,reference)
            if ~isstruct(components) || isempty(components)
                components = ...
                    planWorkflow.performance.PrecomputeTiming.emptyComponents();
                return;
            end

            normalized = ...
                planWorkflow.performance.PrecomputeTiming.emptyComponents();
            for i = 1:numel(components)
                timeSeconds = ...
                    planWorkflow.performance.PrecomputeTiming.numeric( ...
                    components(i),'timeSeconds',NaN);
                if ~planWorkflow.performance.PrecomputeTiming.isFiniteNonnegative( ...
                        timeSeconds)
                    continue;
                end
                item = struct();
                item.role = planWorkflow.performance.PrecomputeTiming.text( ...
                    components(i),'role');
                item.artifact = ...
                    planWorkflow.performance.PrecomputeTiming.text( ...
                    components(i),'artifact');
                item.label = planWorkflow.performance.PrecomputeTiming.text( ...
                    components(i),'label');
                item.timeSeconds = timeSeconds;
                item.relativeTime = ...
                    planWorkflow.performance.PrecomputeTiming.numeric( ...
                    components(i),'relativeTime',NaN);
                if ~isfinite(item.relativeTime) && ...
                        planWorkflow.performance.PrecomputeTiming.isPositive( ...
                        reference.timeSeconds)
                    item.relativeTime = timeSeconds / reference.timeSeconds;
                end
                normalized(end + 1) = item; %#ok<AGROW>
            end
            components = normalized;
        end

        function components = emptyComponents()
            components = struct('role',{},'artifact',{},'label',{}, ...
                'timeSeconds',{},'relativeTime',{});
        end

        function reference = reference(value)
            reference = struct('label','','timeSeconds',NaN);
            if ~isstruct(value) || isempty(value)
                return;
            end
            if isfield(value,'reference') && isstruct(value.reference) && ...
                    isscalar(value.reference)
                reference.label = ...
                    planWorkflow.performance.PrecomputeTiming.text( ...
                    value.reference,'label');
                reference.timeSeconds = ...
                    planWorkflow.performance.PrecomputeTiming.numeric( ...
                    value.reference,'timeSeconds',NaN);
            elseif isfield(value,'dijPrecomputingReferenceTimeSeconds')
                reference.label = ...
                    planWorkflow.performance.PrecomputeTiming.text( ...
                    value,'dijPrecomputingReferenceLabel');
                reference.timeSeconds = ...
                    planWorkflow.performance.PrecomputeTiming.numeric( ...
                    value,'dijPrecomputingReferenceTimeSeconds',NaN);
            elseif isfield(value,'totalTimeSeconds')
                reference.timeSeconds = ...
                    planWorkflow.performance.PrecomputeTiming.numeric( ...
                    value,'totalTimeSeconds',NaN);
            end
        end

        function detail = detailStruct(timing)
            rawText = char(timing.detail);
            try
                detail = jsondecode(rawText);
                if ~isstruct(detail) || ~isscalar(detail)
                    detail = struct('raw',rawText);
                end
            catch
                detail = struct('raw',rawText);
            end
        end

        function value = numeric(source,fieldName,defaultValue)
            value = defaultValue;
            if ~isstruct(source) || ~isfield(source,fieldName)
                return;
            end
            rawValue = source.(fieldName);
            if isnumeric(rawValue) && isscalar(rawValue)
                value = double(rawValue);
            end
        end

        function value = text(source,fieldName)
            value = '';
            if ~isstruct(source) || ~isfield(source,fieldName)
                return;
            end
            rawValue = source.(fieldName);
            if ischar(rawValue)
                value = rawValue;
            elseif isstring(rawValue) && isscalar(rawValue)
                value = char(rawValue);
            end
        end

        function value = field(source,fieldName,defaultValue)
            value = defaultValue;
            if isstruct(source) && isfield(source,fieldName)
                value = source.(fieldName);
            end
        end

        function tf = isFiniteNonnegative(value)
            tf = isnumeric(value) && isscalar(value) && ...
                isfinite(value) && value >= 0;
        end

        function tf = isPositive(value)
            tf = isnumeric(value) && isscalar(value) && ...
                isfinite(value) && value > 0;
        end

        function tf = isCompletedRecord(timing)
            tf = isstruct(timing) && ...
                strcmp(planWorkflow.performance.PrecomputeTiming.text( ...
                timing,'status'),'completed');
        end
    end
end
