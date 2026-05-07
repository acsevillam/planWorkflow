classdef ObjectiveRobustnessMutator
    % ObjectiveRobustnessMutator Applies robustness edits to objective sets.

    methods (Static)
        function template = setTemplateObjectiveSetRobustness( ...
                template,objectiveSetName,robustness)
            objectiveSet = ...
                planWorkflow.templates.PlanTemplate.objectiveSet( ...
                template,objectiveSetName);
            objectiveSet = ...
                planWorkflow.templates.ObjectiveRobustnessMutator.setObjectiveSetRobustness( ...
                objectiveSet,robustness);
            template = ...
                planWorkflow.templates.PlanTemplate.setObjectiveSet( ...
                template,objectiveSetName,objectiveSet);
        end

        function template = harmonizeTemplateNonNoneRobustness( ...
                template,objectiveSetName,robustness)
            objectiveSet = ...
                planWorkflow.templates.PlanTemplate.objectiveSet( ...
                template,objectiveSetName);
            objectiveSet = ...
                planWorkflow.templates.ObjectiveRobustnessMutator.harmonizeObjectiveSetNonNoneRobustness( ...
                objectiveSet,robustness);
            template = ...
                planWorkflow.templates.PlanTemplate.setObjectiveSet( ...
                template,objectiveSetName,objectiveSet);
        end

        function objectiveSet = setObjectiveSetRobustness( ...
                objectiveSet,robustness)
            objectiveSet = ...
                planWorkflow.templates.ObjectiveRobustnessMutator.updateObjectiveSet( ...
                objectiveSet,robustness,'all');
        end

        function objectiveSet = harmonizeObjectiveSetNonNoneRobustness( ...
                objectiveSet,robustness)
            objectiveSet = ...
                planWorkflow.templates.ObjectiveRobustnessMutator.updateObjectiveSet( ...
                objectiveSet,robustness,'nonNone');
        end
    end

    methods (Static, Access = private)
        function objectiveSet = updateObjectiveSet( ...
                objectiveSet,robustness,mode)
            robustness = char(robustness);
            groupFields = {'structureObjectives','ringObjectives'};
            for fieldIx = 1:numel(groupFields)
                fieldName = groupFields{fieldIx};
                if ~isfield(objectiveSet,fieldName) || ...
                        isempty(objectiveSet.(fieldName))
                    continue;
                end
                groups = objectiveSet.(fieldName);
                for groupIx = 1:numel(groups)
                    if iscell(groups)
                        group = groups{groupIx};
                    else
                        group = groups(groupIx);
                    end
                    if isfield(group,'objectives') && ...
                            ~isempty(group.objectives)
                        group.objectives = ...
                            planWorkflow.templates.ObjectiveRobustnessMutator.updateObjectives( ...
                            group.objectives,robustness,mode, ...
                            fieldName,groupIx);
                    end
                    if iscell(groups)
                        groups{groupIx} = group;
                    else
                        groups(groupIx) = group;
                    end
                end
                objectiveSet.(fieldName) = groups;
            end
        end

        function objectives = updateObjectives(objectives,robustness, ...
                mode,groupField,groupIx)
            for objectiveIx = 1:numel(objectives)
                if iscell(objectives)
                    objective = objectives{objectiveIx};
                else
                    objective = objectives(objectiveIx);
                end
                if ~planWorkflow.templates.ObjectiveRobustnessMutator.shouldUpdate( ...
                        objective,mode)
                    continue;
                end
                objective = ...
                    planWorkflow.templates.ObjectiveRobustnessMutator.setObjectiveRobustness( ...
                    objective,robustness,groupField,groupIx, ...
                    objectiveIx);
                if iscell(objectives)
                    objectives{objectiveIx} = objective;
                else
                    objectives(objectiveIx) = objective;
                end
            end
        end

        function tf = shouldUpdate(objective,mode)
            if strcmp(char(mode),'all')
                tf = true;
                return;
            end
            tf = ~strcmp( ...
                planWorkflow.templates.ObjectiveRobustnessMutator.objectiveRobustness( ...
                objective),'none');
        end

        function objective = setObjectiveRobustness(objective, ...
                robustness,groupField,groupIx,objectiveIx)
            objectiveType = '';
            if isfield(objective,'type')
                objectiveType = char(objective.type);
            end
            context = sprintf('%s(%d).objectives(%d)', ...
                char(groupField),groupIx,objectiveIx);
            planWorkflow.templates.PlanTemplate.validateObjectiveRobustnessForType( ...
                objectiveType,robustness,context);
            if ~isfield(objective,'properties') || ...
                    ~isstruct(objective.properties) || ...
                    ~isscalar(objective.properties)
                objective.properties = struct();
            end
            objective.properties.robustness = char(robustness);
        end

        function robustness = objectiveRobustness(objective)
            robustness = 'none';
            if isfield(objective,'properties') && ...
                    isstruct(objective.properties) && ...
                    isfield(objective.properties,'robustness') && ...
                    ~isempty(objective.properties.robustness)
                robustness = char(objective.properties.robustness);
            end
        end
    end
end
