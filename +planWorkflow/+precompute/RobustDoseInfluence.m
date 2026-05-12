classdef RobustDoseInfluence
    % RobustDoseInfluence Owns robust dij payload semantics.

    methods (Static)
        function robustData = attach(robustData,dij)
            robustData.dijRobust = dij;
        end
    end
end
