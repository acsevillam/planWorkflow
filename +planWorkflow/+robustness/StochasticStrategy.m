classdef StochasticStrategy < planWorkflow.robustness.AbstractStrategy
    % StochasticStrategy Applies STOCH robustness to objectives.

    properties (Access = private)
        includeOAR
    end

    methods
        function obj = StochasticStrategy(name,includeOAR)
            if ~strcmp(char(name),'STOCH')
                error('planWorkflow:robustness:StochasticStrategy:UnsupportedMode', ...
                    'Unsupported stochastic robustness mode "%s".', ...
                    char(name));
            end
            obj.name = name;
            obj.includeOAR = includeOAR;
        end

        function [cst,pln] = apply(obj,cst,pln,objectiveInfo,runConfig) %#ok<INUSD>
        end
    end
end
