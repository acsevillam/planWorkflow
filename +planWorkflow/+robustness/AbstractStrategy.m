classdef (Abstract) AbstractStrategy < handle
    % AbstractStrategy Base class for robust objective setup.

    properties (SetAccess = protected)
        name
    end

    methods
        function tf = requiresIntervalDij(obj) %#ok<MANU>
            tf = false;
        end

        function tf = requiresProbDij(obj) %#ok<MANU>
            tf = false;
        end
    end

    methods (Static)
        function strategy = create(strategyName)
            strategyName = char(strategyName);
            switch strategyName
                case 'none'
                    strategy = planWorkflow.robustness.NoneStrategy();
                case 'multi'
                    strategy = planWorkflow.robustness.MultiStrategy();
                case 'STOCH'
                    strategy = planWorkflow.robustness.StochasticStrategy( ...
                        'STOCH',false);
                case 'COWC'
                    strategy = planWorkflow.robustness.COWCStrategy( ...
                        'COWC',false);
                case 'c-COWC'
                    strategy = planWorkflow.robustness.CheapCOWCStrategy( ...
                        'c-COWC',false);
                case {'INTERVAL2','INTERVAL3'}
                    strategy = planWorkflow.robustness.IntervalStrategy( ...
                        strategyName);
                case 'PROB2'
                    strategy = planWorkflow.robustness.Prob2Strategy();
                otherwise
                    error('planWorkflow:robustness:UnknownStrategy', ...
                        'Unknown robust optimization strategy: %s.', ...
                        strategyName);
            end
        end
    end

    methods (Abstract)
        [cst,pln] = apply(obj,cst,pln,objectiveInfo,runConfig)
    end

    methods (Access = protected)
        function cst = setTargetRobustness(obj,cst,ixTarget,robustnessName) %#ok<INUSD>
            for i = 1:numel(cst{ixTarget,6})
                cst{ixTarget,6}{i}.robustness = robustnessName;
            end
        end

        function cst = setOARRobustness(obj,cst,robustOarNames,robustnessName) %#ok<INUSD>
            for i = 1:size(cst,1)
                for j = 1:numel(robustOarNames)
                    if strcmp(robustOarNames{j},cst{i,2})
                        for k = 1:numel(cst{i,6})
                            cst{i,6}{k}.robustness = robustnessName;
                        end
                    end
                end
            end
        end
    end
end
