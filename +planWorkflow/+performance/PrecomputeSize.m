classdef PrecomputeSize
    % PrecomputeSize Builds dose-influence precompute size metadata.

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

        function sizeData = fromOptions(value,options)
            if nargin < 2 || ~isstruct(options)
                options = planWorkflow.performance.PrecomputeSize.cacheOptions( ...
                    '','','',[],[]);
            end
            sizeData = planWorkflow.performance.PrecomputeSize.single( ...
                planWorkflow.performance.PrecomputeSize.artifactBytes(value), ...
                planWorkflow.performance.PrecomputeSize.text(options,'role'), ...
                planWorkflow.performance.PrecomputeSize.text(options,'label'), ...
                planWorkflow.performance.PrecomputeSize.text(options,'artifact'), ...
                planWorkflow.performance.PrecomputeSize.field( ...
                options,'referenceSize',[]));
        end

        function sizeData = single(sizeBytes,role,label,artifact, ...
                referenceSize)
            if nargin < 5
                referenceSize = [];
            end
            component = ...
                planWorkflow.performance.PrecomputeSize.component( ...
                role,artifact,label,sizeBytes,referenceSize);
            sizeData = ...
                planWorkflow.performance.PrecomputeSize.fromComponents( ...
                component,referenceSize,label,role);
        end

        function sizeData = combine(inputSize,derivedRole,derivedArtifact, ...
                derivedValue,label,referenceSize)
            if nargin < 5
                label = '';
            end
            if nargin < 6
                referenceSize = [];
            end
            [normalizedInput,hasInput] = ...
                planWorkflow.performance.PrecomputeSize.normalize(inputSize);
            if hasInput
                referenceSize = normalizedInput;
                components = normalizedInput.components;
            else
                components = planWorkflow.performance.PrecomputeSize.emptyComponents();
            end
            derivedBytes = ...
                planWorkflow.performance.PrecomputeSize.sizeBytes(derivedValue);
            derivedComponent = ...
                planWorkflow.performance.PrecomputeSize.component( ...
                derivedRole,derivedArtifact,label,derivedBytes,referenceSize);
            components(end + 1) = derivedComponent;
            sizeData = ...
                planWorkflow.performance.PrecomputeSize.fromComponents( ...
                components,referenceSize,label,derivedRole);
        end

        function [sizeData,tf] = normalize(value)
            sizeData = struct();
            tf = false;
            if ~isstruct(value) || ~isscalar(value)
                return;
            end

            totalSizeBytes = ...
                planWorkflow.performance.PrecomputeSize.numeric( ...
                value,'totalSizeBytes',NaN);
            if ~planWorkflow.performance.PrecomputeSize.isFiniteNonnegative( ...
                    totalSizeBytes)
                return;
            end

            reference = ...
                planWorkflow.performance.PrecomputeSize.reference(value);
            relativeSize = ...
                planWorkflow.performance.PrecomputeSize.numeric( ...
                value,'relativeSize',NaN);
            if ~isfinite(relativeSize) && ...
                    planWorkflow.performance.PrecomputeSize.isPositive( ...
                    reference.sizeBytes)
                relativeSize = totalSizeBytes / reference.sizeBytes;
            end

            sizeData = struct();
            sizeData.schemaVersion = 1;
            sizeData.totalSizeBytes = totalSizeBytes;
            sizeData.relativeSize = relativeSize;
            sizeData.reference = reference;
            sizeData.components = ...
                planWorkflow.performance.PrecomputeSize.normalizeComponents( ...
                planWorkflow.performance.PrecomputeSize.field( ...
                value,'components', ...
                planWorkflow.performance.PrecomputeSize.emptyComponents()), ...
                reference);
            tf = true;
        end

        function tf = isValid(value)
            [~,tf] = planWorkflow.performance.PrecomputeSize.normalize(value);
        end

        function sizeData = asReference(sizeData,label)
            [sizeData,tf] = ...
                planWorkflow.performance.PrecomputeSize.normalize(sizeData);
            if ~tf
                sizeData = [];
                return;
            end
            if nargin < 2 || isempty(label)
                label = sizeData.reference.label;
            end
            sizeData.reference.label = char(label);
            sizeData.reference.sizeBytes = sizeData.totalSizeBytes;
            sizeData.relativeSize = NaN;
            if planWorkflow.performance.PrecomputeSize.isPositive( ...
                    sizeData.totalSizeBytes)
                sizeData.relativeSize = 1;
                for componentIx = 1:numel(sizeData.components)
                    sizeData.components(componentIx).relativeSize = ...
                        sizeData.components(componentIx).sizeBytes / ...
                        sizeData.totalSizeBytes;
                end
            end
        end

        function sizeData = fromCacheMetadata(cacheMetadata)
            [sizeData,tf] = planWorkflow.performance.PrecomputeSize.normalize( ...
                cacheMetadata.dijPrecomputingSize);
            if ~tf
                sizeData = [];
            end
        end

        function timings = enrich(timings)
            if ~isstruct(timings) || isempty(timings)
                return;
            end

            for timingIx = 1:numel(timings)
                if ~planWorkflow.performance.PrecomputeSize.isCompletedRecord( ...
                        timings(timingIx))
                    continue;
                end
                if ~isfield(timings(timingIx),'detail') || ...
                        isempty(timings(timingIx).detail)
                    continue;
                end
                detail = ...
                    planWorkflow.performance.PrecomputeSize.detailStruct( ...
                    timings(timingIx));
                if ~isfield(detail,'dijPrecomputingSize')
                    continue;
                end
                [dijSize,tf] = ...
                    planWorkflow.performance.PrecomputeSize.normalize( ...
                    detail.dijPrecomputingSize);
                if ~tf
                    continue;
                end
                timings(timingIx) = ...
                    planWorkflow.performance.PrecomputeSize.applyToRecord( ...
                    timings(timingIx),dijSize);
                detail.dijPrecomputingSize = dijSize;
                timings(timingIx).detail = jsonencode(detail);
            end
        end

        function record = applyToRecord(record,dijSize)
            [dijSize,tf] = ...
                planWorkflow.performance.PrecomputeSize.normalize(dijSize);
            if ~tf
                return;
            end
            record.dijPrecomputingSizeBytes = dijSize.totalSizeBytes;
            record.relativeDijPrecomputingSize = dijSize.relativeSize;
            record.dijPrecomputingSizeReferenceLabel = ...
                dijSize.reference.label;
            record.dijPrecomputingSizeReferenceBytes = ...
                dijSize.reference.sizeBytes;
        end

        function bytes = valueBytes(value) %#ok<INUSD>
            variableInfo = whos('value');
            bytes = double(variableInfo.bytes);
        end

        function bytes = artifactBytes(value)
            bytes = planWorkflow.performance.PrecomputeSize.precomputeBytes(value);
            if isfinite(bytes)
                return;
            end
            bytes = planWorkflow.performance.PrecomputeSize.valueBytes(value);
        end

        function bytes = precomputeBytes(value)
            bytes = NaN;
            if ~isstruct(value) || ~isfield(value,'precomputeSize') || ...
                    ~isstruct(value.precomputeSize)
                return;
            end
            bytes = planWorkflow.performance.PrecomputeSize.numeric( ...
                value.precomputeSize,'totalPrecomputingBytes',NaN);
        end
    end

    methods (Static, Access = private)
        function sizeData = fromComponents(components,referenceSize,label,role)
            if nargin < 3
                label = '';
            end
            if nargin < 4
                role = '';
            end
            components = ...
                planWorkflow.performance.PrecomputeSize.normalizeComponents( ...
                components, ...
                planWorkflow.performance.PrecomputeSize.reference( ...
                referenceSize));
            totalSizeBytes = 0;
            for i = 1:numel(components)
                totalSizeBytes = totalSizeBytes + components(i).sizeBytes;
            end

            reference = ...
                planWorkflow.performance.PrecomputeSize.reference( ...
                referenceSize);
            if ~planWorkflow.performance.PrecomputeSize.isPositive( ...
                    reference.sizeBytes) && strcmp(char(role),'reference')
                reference.label = char(label);
                reference.sizeBytes = totalSizeBytes;
            end

            relativeSize = NaN;
            if planWorkflow.performance.PrecomputeSize.isPositive( ...
                    reference.sizeBytes)
                relativeSize = totalSizeBytes / reference.sizeBytes;
            end

            for i = 1:numel(components)
                if ~isfinite(components(i).relativeSize) && ...
                        planWorkflow.performance.PrecomputeSize.isPositive( ...
                        reference.sizeBytes)
                    components(i).relativeSize = ...
                        components(i).sizeBytes / reference.sizeBytes;
                end
            end

            sizeData = struct();
            sizeData.schemaVersion = 1;
            sizeData.totalSizeBytes = totalSizeBytes;
            sizeData.relativeSize = relativeSize;
            sizeData.reference = reference;
            sizeData.components = components;
        end

        function component = component(role,artifact,label,sizeBytes, ...
                referenceSize)
            component = struct();
            component.role = char(role);
            component.artifact = char(artifact);
            component.label = char(label);
            component.sizeBytes = double(sizeBytes);
            component.relativeSize = NaN;
            reference = ...
                planWorkflow.performance.PrecomputeSize.reference(referenceSize);
            if planWorkflow.performance.PrecomputeSize.isPositive( ...
                    reference.sizeBytes)
                component.relativeSize = ...
                    component.sizeBytes / reference.sizeBytes;
            elseif strcmp(char(role),'reference') && ...
                    planWorkflow.performance.PrecomputeSize.isPositive( ...
                    component.sizeBytes)
                component.relativeSize = 1;
            end
        end

        function components = normalizeComponents(components,reference)
            if ~isstruct(components) || isempty(components)
                components = ...
                    planWorkflow.performance.PrecomputeSize.emptyComponents();
                return;
            end

            normalized = ...
                planWorkflow.performance.PrecomputeSize.emptyComponents();
            for i = 1:numel(components)
                sizeBytes = ...
                    planWorkflow.performance.PrecomputeSize.numeric( ...
                    components(i),'sizeBytes',NaN);
                if ~planWorkflow.performance.PrecomputeSize.isFiniteNonnegative( ...
                        sizeBytes)
                    continue;
                end
                item = struct();
                item.role = planWorkflow.performance.PrecomputeSize.text( ...
                    components(i),'role');
                item.artifact = ...
                    planWorkflow.performance.PrecomputeSize.text( ...
                    components(i),'artifact');
                item.label = planWorkflow.performance.PrecomputeSize.text( ...
                    components(i),'label');
                item.sizeBytes = sizeBytes;
                item.relativeSize = ...
                    planWorkflow.performance.PrecomputeSize.numeric( ...
                    components(i),'relativeSize',NaN);
                if ~isfinite(item.relativeSize) && ...
                        planWorkflow.performance.PrecomputeSize.isPositive( ...
                        reference.sizeBytes)
                    item.relativeSize = sizeBytes / reference.sizeBytes;
                end
                normalized(end + 1) = item; %#ok<AGROW>
            end
            components = normalized;
        end

        function components = emptyComponents()
            components = struct('role',{},'artifact',{},'label',{}, ...
                'sizeBytes',{},'relativeSize',{});
        end

        function reference = reference(value)
            reference = struct('label','','sizeBytes',NaN);
            if ~isstruct(value) || isempty(value)
                return;
            end
            if isfield(value,'reference') && isstruct(value.reference) && ...
                    isscalar(value.reference)
                reference.label = ...
                    planWorkflow.performance.PrecomputeSize.text( ...
                    value.reference,'label');
                reference.sizeBytes = ...
                    planWorkflow.performance.PrecomputeSize.numeric( ...
                    value.reference,'sizeBytes',NaN);
            elseif isfield(value,'dijPrecomputingSizeReferenceBytes')
                reference.label = ...
                    planWorkflow.performance.PrecomputeSize.text( ...
                    value,'dijPrecomputingSizeReferenceLabel');
                reference.sizeBytes = ...
                    planWorkflow.performance.PrecomputeSize.numeric( ...
                    value,'dijPrecomputingSizeReferenceBytes',NaN);
            elseif isfield(value,'totalSizeBytes')
                reference.sizeBytes = ...
                    planWorkflow.performance.PrecomputeSize.numeric( ...
                    value,'totalSizeBytes',NaN);
            end
        end

        function bytes = sizeBytes(value)
            if isnumeric(value) && isscalar(value)
                bytes = double(value);
            else
                bytes = planWorkflow.performance.PrecomputeSize.artifactBytes( ...
                    value);
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
                strcmp(planWorkflow.performance.PrecomputeSize.text( ...
                timing,'status'),'completed');
        end
    end
end
