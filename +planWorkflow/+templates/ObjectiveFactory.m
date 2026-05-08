classdef ObjectiveFactory
    % ObjectiveFactory Builds supported matRad optimization function structs.

    methods (Static)
        function objectiveTypes = supportedObjectiveTypes()
            discovered = ...
                planWorkflow.matRadCapabilitiesReader.supportedObjectiveTypes();
            supported = ...
                planWorkflow.templates.ObjectiveFactory.factorySupportedTypes();
            objectiveTypes = {};
            for i = 1:numel(supported)
                if any(strcmp(supported{i},discovered))
                    objectiveTypes{end + 1} = supported{i}; %#ok<AGROW>
                end
            end
            if isempty(objectiveTypes)
                objectiveTypes = supported;
            end
        end

        function parameterNames = parameterNamesForObjectiveType( ...
                objectiveType)
            switch char(objectiveType)
                case {'matRad_MeanVariance','MeanVariance'}
                    parameterNames = {'penalty'};
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
                case {'matRad_MinMaxMeanVariance','MinMaxMeanVariance'}
                    parameterNames = {'minMeanVariance','maxMeanVariance'};
                otherwise
                    error('planWorkflow:templates:PlanTemplate:UnknownObjectiveType', ...
                        'Unsupported objective type "%s".',char(objectiveType));
            end
        end

        function objective = constructObjective(objectiveType,params)
            switch char(objectiveType)
                case {'matRad_MeanVariance','MeanVariance'}
                    objective = struct(DoseObjectives.matRad_MeanVariance( ...
                        params{:}));
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
                case {'matRad_MinMaxMeanVariance','MinMaxMeanVariance'}
                    objective = struct( ...
                        DoseConstraints.matRad_MinMaxMeanVariance( ...
                        params{:}));
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

    methods (Static, Access = private)
        function types = factorySupportedTypes()
            types = {'matRad_SquaredOverdosing', ...
                'matRad_SquaredUnderdosing', ...
                'matRad_MinDVH', ...
                'matRad_SquaredDeviation', ...
                'matRad_SquaredBertoluzzaDeviation', ...
                'matRad_MaxDVH', ...
                'matRad_MeanDose', ...
                'matRad_EUD', ...
                'matRad_MeanVariance', ...
                'matRad_MinMaxMeanVariance'};
        end
    end
end
