classdef PhotonWorkflow < planWorkflow.Engine
    % PhotonWorkflow Public photon robust workflow entrypoint.

    methods
        function obj = PhotonWorkflow(config)
            if nargin < 1
                config = struct();
            end
            if ~isfield(config,'radiationMode')
                config.radiationMode = 'photons';
            end
            if ~isfield(config,'workflowType')
                config.workflowType = 'photonRobust';
            end
            obj@planWorkflow.Engine(config);
        end
    end
end
