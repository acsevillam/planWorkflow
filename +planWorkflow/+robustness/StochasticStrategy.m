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
            cst = obj.setTargetRobustness(cst,objectiveInfo.ixTarget,'STOCH');
            if obj.includeOAR
                cst = obj.setOARRobustness(cst, ...
                    objectiveInfo.robustOarNames,'STOCH');
            end
        end
    end
end
