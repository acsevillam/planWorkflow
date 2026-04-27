classdef (Abstract) AbstractStrategy < handle
    % AbstractStrategy Base class for robust objective setup.

    properties (SetAccess = protected)
        name
    end

    methods
        function tf = requiresIntervalDij(obj) %#ok<MANU>
            tf = false;
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

        function cst = setOARRobustness(obj,cst,oarStructSel,robustnessName) %#ok<INUSD>
            for i = 1:size(cst,1)
                for j = 1:numel(oarStructSel)
                    if strcmp(oarStructSel{j},cst{i,2})
                        for k = 1:numel(cst{i,6})
                            cst{i,6}{k}.robustness = robustnessName;
                        end
                    end
                end
            end
        end
    end
end
