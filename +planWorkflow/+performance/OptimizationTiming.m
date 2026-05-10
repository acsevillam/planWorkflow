classdef OptimizationTiming
    % OptimizationTiming Adds optimization iteration timing metrics.

    methods (Static)
        function timings = enrich(timings)
            if ~isstruct(timings) || isempty(timings)
                return;
            end

            referenceTpi = NaN;
            referenceLabel = '';
            for timingIx = 1:numel(timings)
                timing = timings(timingIx);
                if ~planWorkflow.performance.OptimizationTiming.isOptimizationTiming( ...
                        timing)
                    continue;
                end

                detail = ...
                    planWorkflow.performance.OptimizationTiming.detailStruct( ...
                    timing);
                iterations = ...
                    planWorkflow.performance.OptimizationTiming.iterations( ...
                    timing,detail);
                if isempty(iterations)
                    continue;
                end

                timings(timingIx).iterations = iterations;
                detail.iterations = iterations;

                wallTimeSeconds = ...
                    planWorkflow.performance.OptimizationTiming.numericField( ...
                    timing,'wallTimeSeconds');
                tpi = planWorkflow.performance.OptimizationTiming.tpi( ...
                    wallTimeSeconds,iterations);
                if isempty(tpi)
                    timings(timingIx).detail = jsonencode(detail);
                    continue;
                end

                timings(timingIx).timePerIterationSeconds = tpi;
                detail.timePerIterationSeconds = tpi;

                role = planWorkflow.performance.OptimizationTiming.text( ...
                    timing,'role');
                if strcmp(role,'reference')
                    if tpi > 0
                        referenceTpi = tpi;
                        referenceLabel = ...
                            planWorkflow.performance.OptimizationTiming.text( ...
                            timing,'label');
                        timings(timingIx).rTPI = 1;
                        timings(timingIx).rTPIReferenceLabel = referenceLabel;
                        timings(timingIx).rTPIReferenceTimePerIterationSeconds = ...
                            referenceTpi;
                    end
                elseif isfinite(referenceTpi) && referenceTpi > 0
                    timings(timingIx).rTPI = tpi / referenceTpi;
                    timings(timingIx).rTPIReferenceLabel = referenceLabel;
                    timings(timingIx).rTPIReferenceTimePerIterationSeconds = ...
                        referenceTpi;
                end

                detail = ...
                    planWorkflow.performance.OptimizationTiming.appendRtpiDetail( ...
                    detail,timings(timingIx));
                timings(timingIx).detail = jsonencode(detail);
            end
        end
    end

    methods (Static, Access = private)
        function tf = isOptimizationTiming(timing)
            tf = isstruct(timing) && ...
                strcmp(planWorkflow.performance.OptimizationTiming.text( ...
                timing,'stage'),'optimize') && ...
                strcmp(planWorkflow.performance.OptimizationTiming.text( ...
                timing,'task'),'fluenceOptimization') && ...
                strcmp(planWorkflow.performance.OptimizationTiming.text( ...
                timing,'status'),'completed');
        end

        function detail = detailStruct(timing)
            detail = struct();
            if ~isstruct(timing) || ~isfield(timing,'detail') || ...
                    isempty(timing.detail)
                return;
            end

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

        function iterations = iterations(timing,detail)
            iterations = [];
            if isstruct(detail) && isfield(detail,'iterations') && ...
                    planWorkflow.performance.OptimizationTiming.isPositiveScalar( ...
                    detail.iterations)
                iterations = double(detail.iterations);
                return;
            end
            if isstruct(timing) && isfield(timing,'iterations') && ...
                    planWorkflow.performance.OptimizationTiming.isPositiveScalar( ...
                    timing.iterations)
                iterations = double(timing.iterations);
            end
        end

        function tpi = tpi(wallTimeSeconds,iterations)
            tpi = [];
            if isnumeric(wallTimeSeconds) && isscalar(wallTimeSeconds) && ...
                    isfinite(wallTimeSeconds) && ...
                    planWorkflow.performance.OptimizationTiming.isPositiveScalar( ...
                    iterations)
                tpi = double(wallTimeSeconds) / double(iterations);
            end
        end

        function tf = isPositiveScalar(value)
            tf = isnumeric(value) && isscalar(value) && isfinite(value) && ...
                value > 0;
        end

        function detail = appendRtpiDetail(detail,timing)
            if isfield(timing,'rTPI') && ...
                    planWorkflow.performance.OptimizationTiming.isFiniteScalar( ...
                    timing.rTPI)
                detail.rTPI = timing.rTPI;
                reference = struct();
                if isfield(timing,'rTPIReferenceLabel')
                    reference.label = char(timing.rTPIReferenceLabel);
                else
                    reference.label = '';
                end
                if isfield(timing,'rTPIReferenceTimePerIterationSeconds')
                    reference.timePerIterationSeconds = ...
                        timing.rTPIReferenceTimePerIterationSeconds;
                    detail.rTPIReference = reference;
                end
            end
        end

        function tf = isFiniteScalar(value)
            tf = isnumeric(value) && isscalar(value) && isfinite(value);
        end

        function value = numericField(timing,fieldName)
            value = NaN;
            if ~isstruct(timing) || ~isfield(timing,fieldName)
                return;
            end

            rawValue = timing.(fieldName);
            if isnumeric(rawValue) && isscalar(rawValue)
                value = double(rawValue);
            end
        end

        function value = text(timing,fieldName)
            value = '';
            if ~isstruct(timing) || ~isfield(timing,fieldName)
                return;
            end

            rawValue = timing.(fieldName);
            if ischar(rawValue)
                value = rawValue;
            elseif isstring(rawValue) && isscalar(rawValue)
                value = char(rawValue);
            end
        end
    end
end
