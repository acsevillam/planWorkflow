classdef COWCStrategy < planWorkflow.robustness.AbstractStrategy
    % COWCStrategy Applies COWC robustness with logsumexp max approximation.

    properties (Access = private)
        includeOAR
    end

    methods
        function obj = COWCStrategy(name,includeOAR)
            if ~strcmp(char(name),'COWC')
                error('planWorkflow:robustness:COWCStrategy:UnsupportedMode', ...
                    'Unsupported COWC robustness mode "%s".',char(name));
            end
            obj.name = name;
            obj.includeOAR = includeOAR;
        end

        function [cst,pln] = apply(obj,cst,pln,objectiveInfo,runConfig) %#ok<INUSD>
            pln.propOpt.useMaxApprox = 'logsumexp';
        end
    end
end
