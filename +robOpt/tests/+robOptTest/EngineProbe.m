classdef EngineProbe < robOpt.Engine
    % EngineProbe Exposes protected Engine configuration hooks for tests.

    methods
        function obj = EngineProbe(config)
            obj@robOpt.Engine(config);
        end

        function configureStagePublic(obj,stageName,stageConfig)
            obj.configureStage(stageName,stageConfig);
        end
    end
end
