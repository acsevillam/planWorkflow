classdef ObjectiveFactory
    % ObjectiveFactory Builds matRad dose objective structs.

    methods (Static)
        function objectiveTypes = supportedObjectiveTypes()
            objectiveTypes = ...
                planWorkflow.matRadCapabilitiesReader.supportedObjectiveTypes();
        end

        function parameterNames = parameterNamesForObjectiveType( ...
                objectiveType)
            switch char(objectiveType)
                case {'matRad_SquaredOverdosing','SquaredOverdosing'}
                    parameterNames = {'penalty','dMax'};
                case {'matRad_SquaredUnderdosing','SquaredUnderdosing'}
                    parameterNames = {'penalty','dMin'};
                case {'matRad_MinDVH','MinDVH'}
                    parameterNames = {'penalty','dRef','vMinPercent'};
                case {'matRad_SquaredDeviation','SquaredDeviation'}
                    parameterNames = {'penalty','dRef'};
                case {'matRad_SquaredBertoluzzaDeviation', ...
                        'SquaredBertoluzzaDeviation'}
                    parameterNames = {'penalty','dRef'};
                case {'matRad_MaxDVH','MaxDVH'}
                    parameterNames = {'penalty','dRef','vMaxPercent'};
                case {'matRad_MeanDose','MeanDose'}
                    parameterNames = {'penalty','dMeanRef','fDiff'};
                case {'matRad_EUD','EUD'}
                    parameterNames = {'penalty','eudRef','eudExponent'};
                otherwise
                    error('planWorkflow:templates:PlanTemplate:UnknownObjectiveType', ...
                        'Unsupported objective type "%s".',char(objectiveType));
            end
        end

        function objective = constructObjective(objectiveType,params)
            switch char(objectiveType)
                case {'matRad_SquaredOverdosing','SquaredOverdosing'}
                    objective = struct(DoseObjectives.matRad_SquaredOverdosing( ...
                        params{:}));
                case {'matRad_SquaredUnderdosing','SquaredUnderdosing'}
                    objective = struct(DoseObjectives.matRad_SquaredUnderdosing( ...
                        params{:}));
                case {'matRad_MinDVH','MinDVH'}
                    objective = struct(DoseObjectives.matRad_MinDVH(params{:}));
                case {'matRad_SquaredDeviation','SquaredDeviation'}
                    objective = struct(DoseObjectives.matRad_SquaredDeviation( ...
                        params{:}));
                case {'matRad_SquaredBertoluzzaDeviation', ...
                        'SquaredBertoluzzaDeviation'}
                    objective = struct( ...
                        DoseObjectives.matRad_SquaredBertoluzzaDeviation( ...
                        params{:}));
                case {'matRad_MaxDVH','MaxDVH'}
                    objective = struct(DoseObjectives.matRad_MaxDVH(params{:}));
                case {'matRad_MeanDose','MeanDose'}
                    objective = struct(DoseObjectives.matRad_MeanDose(params{:}));
                case {'matRad_EUD','EUD'}
                    objective = struct(DoseObjectives.matRad_EUD(params{:}));
                otherwise
                    error('planWorkflow:templates:PlanTemplate:UnknownObjectiveType', ...
                        'Unsupported objective type "%s".',char(objectiveType));
            end
        end

        function validateRobustnessForObjectiveType( ...
                objectiveType,robustness,context)
            if ~planWorkflow.matRadCapabilitiesReader.supportsObjectiveRobustness( ...
                    objectiveType,robustness)
                error('planWorkflow:templates:PlanTemplate:UnsupportedRobustness', ...
                    ['%s.robustness "%s" is not supported by objective ' ...
                    'type "%s".'],context,char(robustness), ...
                    char(objectiveType));
            end
        end
    end
end
