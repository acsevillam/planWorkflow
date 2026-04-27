classdef IntervalStrategy < robOpt.robustness.AbstractStrategy
    % IntervalStrategy Marker for interval robust methods.

    methods
        function obj = IntervalStrategy(name)
            obj.name = name;
        end

        function tf = requiresIntervalDij(obj) %#ok<MANU>
            tf = true;
        end

        function [cst,pln] = apply(obj,cst,pln,objectiveInfo,runConfig) %#ok<INUSD>
            error('robOpt:robustness:IntervalStrategy:NotImplemented', ...
                ['%s requires an interval dose-influence precompute step. ' ...
                 'Implement that step in a concrete interval strategy before optimization.'], ...
                obj.name);
        end
    end
end
