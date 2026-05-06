classdef PlanEvaluationContext
    % PlanEvaluationContext Normalizes dose display metadata for results.

    methods (Static)
        function context = fromPlanResults(planResults)
            context = struct();
            context.evaluationModeBase = 'perFraction';
            context.evaluationMode = 'perFraction';
            context.evaluationScale = 1;
            context.numOfFractions = [];
            context.analysisQuantity = '';
            context.endpointQuantity = '';

            if ~isstruct(planResults)
                return;
            end

            if isfield(planResults,'analysisQuantity') && ...
                    ~isempty(planResults.analysisQuantity)
                context.analysisQuantity = char(planResults.analysisQuantity);
            end
            if isfield(planResults,'endpointQuantity') && ...
                    ~isempty(planResults.endpointQuantity)
                context.endpointQuantity = char(planResults.endpointQuantity);
            end
            if isempty(context.endpointQuantity)
                context.endpointQuantity = context.analysisQuantity;
            end
            if isfield(planResults,'evaluationModeBase') && ...
                    ~isempty(planResults.evaluationModeBase)
                context.evaluationModeBase = char(planResults.evaluationModeBase);
            end
            if isfield(planResults,'evaluationMode') && ...
                    ~isempty(planResults.evaluationMode)
                context.evaluationMode = char(planResults.evaluationMode);
            end
            if isfield(planResults,'evaluationScale') && ...
                    planWorkflow.analysis.PlanEvaluationContext.isPositiveScalar( ...
                    planResults.evaluationScale)
                context.evaluationScale = planResults.evaluationScale;
            end
            if isfield(planResults,'numOfFractions') && ...
                    planWorkflow.analysis.PlanEvaluationContext.isPositiveScalar( ...
                    planResults.numOfFractions)
                context.numOfFractions = planResults.numOfFractions;
            end
        end

        function tf = isPositiveScalar(value)
            tf = isnumeric(value) && isscalar(value) && ...
                isfinite(value) && value > 0;
        end
    end
end
