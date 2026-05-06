classdef Workflow < planWorkflow.Engine
    % Workflow Public robust workflow entrypoint.

    methods
        function obj = Workflow(config)
            if nargin < 1
                config = struct();
            end
            obj@planWorkflow.Engine(config);
        end
    end
end
