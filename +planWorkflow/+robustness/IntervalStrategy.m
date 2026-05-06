classdef IntervalStrategy < planWorkflow.robustness.AbstractStrategy
    % IntervalStrategy Applies matRad INTERVAL2/INTERVAL3 objective settings.

    methods
        function obj = IntervalStrategy(name)
            name = char(name);
            if ~any(strcmp(name,{'INTERVAL2','INTERVAL3'}))
                error('planWorkflow:robustness:IntervalStrategy:UnsupportedMode', ...
                    'Unsupported interval robustness mode "%s".',name);
            end
            obj.name = name;
        end

        function tf = requiresIntervalDij(obj) %#ok<MANU>
            tf = true;
        end

        function [cst,pln] = apply(obj,cst,pln,objectiveInfo,runConfig)
            obj.validateTargetObjectives(cst,objectiveInfo.ixTarget);
            pln.propOpt.theta1 = obj.variantScalarValue( ...
                runConfig,'theta1');
            if strcmp(obj.name,'INTERVAL3')
                pln.propOpt.theta2 = obj.variantScalarValue( ...
                    runConfig,'theta2');
            end

            cst = obj.setTargetRobustness(cst,objectiveInfo.ixTarget, ...
                obj.name);
            cst = obj.setOARRobustness(cst, ...
                objectiveInfo.robustOarNames,obj.name);
        end
    end

    methods (Access = private)
        function validateTargetObjectives(obj,cst,ixTarget)
            for i = 1:numel(cst{ixTarget,6})
                objective = cst{ixTarget,6}{i};
                if ~isstruct(objective) || ~isfield(objective,'className') || ...
                        ~strcmp(objective.className, ...
                        'DoseObjectives.matRad_SquaredBertoluzzaDeviation')
                    error(['planWorkflow:robustness:IntervalStrategy:' ...
                        'TargetObjectiveRequired'], ...
                        ['%s target objectives require ' ...
                        'DoseObjectives.matRad_SquaredBertoluzzaDeviation. ' ...
                        'Update the plan template before selecting an ' ...
                        'interval robustness mode.'],obj.name);
                end
            end
        end

        function value = variantScalarValue(obj,runConfig,fieldName)
            if isfield(runConfig,'variant') && ...
                    isstruct(runConfig.variant) && ...
                    isfield(runConfig.variant,fieldName) && ...
                    ~isempty(runConfig.variant.(fieldName))
                value = runConfig.variant.(fieldName);
                return;
            end
            error('planWorkflow:robustness:IntervalStrategy:MissingVariantTheta', ...
                '%s strategies require %s in runConfig.variant.', ...
                obj.name,fieldName);
        end
    end
end
