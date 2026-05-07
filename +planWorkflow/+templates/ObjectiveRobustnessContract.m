classdef ObjectiveRobustnessContract
    % ObjectiveRobustnessContract Derives precompute needs from objectives.

    methods (Static)
        function contract = forObjectiveSet(objectiveSet)
            robustnessValues = ...
                planWorkflow.templates.ObjectiveRobustnessContract.collect( ...
                objectiveSet);
            robustnessValues = unique(robustnessValues,'stable');

            hasNominal = any(strcmp(robustnessValues,'none'));
            nonNone = robustnessValues(~strcmp(robustnessValues,'none'));
            if numel(nonNone) > 1
                error(['planWorkflow:templates:ObjectiveRobustnessContract:' ...
                    'MultipleRobustnessModes'], ...
                    ['Objective set "%s" defines multiple non-none ' ...
                     'robustness modes: %s. Use at most one.'], ...
                    planWorkflow.templates.ObjectiveRobustnessContract.idText( ...
                    objectiveSet),strjoin(nonNone,', '));
            end

            if isempty(nonNone)
                robustnessMode = 'none';
            else
                robustnessMode = nonNone{1};
            end

            contract = struct();
            contract.objectiveSetId = ...
                planWorkflow.templates.ObjectiveRobustnessContract.idText( ...
                objectiveSet);
            contract.hasNominalObjectives = hasNominal;
            contract.robustnessMode = robustnessMode;
            contract.nonNoneModes = {nonNone};
            contract.requiresNominalDij = hasNominal || ...
                strcmp(robustnessMode,'none');
            contract.requiresScenarioDij = any(strcmp( ...
                robustnessMode,{'STOCH','COWC','c-COWC'}));
            contract.requiresIntervalDij = any(strcmp( ...
                robustnessMode,{'INTERVAL2','INTERVAL3'}));
        end

        function contract = forTemplateObjectiveSet(template,objectiveSetName)
            objectiveSet = ...
                planWorkflow.templates.TemplateResolver.objectiveSet( ...
                template,objectiveSetName);
            contract = ...
                planWorkflow.templates.ObjectiveRobustnessContract.forObjectiveSet( ...
                objectiveSet);
        end
    end

    methods (Static, Access = private)
        function robustnessValues = collect(objectiveSet)
            robustnessValues = {};
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
                    if ~isfield(group,'objectives') || ...
                            isempty(group.objectives)
                        continue;
                    end
                    objectives = group.objectives;
                    for objectiveIx = 1:numel(objectives)
                        if iscell(objectives)
                            objective = objectives{objectiveIx};
                        else
                            objective = objectives(objectiveIx);
                        end
                        if isfield(objective,'enabled') && ...
                                ~logical(objective.enabled)
                            continue;
                        end
                        robustnessValues{end + 1} = ...
                            planWorkflow.templates.ObjectiveRobustnessContract.objectiveRobustness( ...
                            objective); %#ok<AGROW>
                    end
                end
            end
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

        function id = idText(objectiveSet)
            id = '';
            if isstruct(objectiveSet) && isfield(objectiveSet,'id') && ...
                    ~isempty(objectiveSet.id)
                id = char(objectiveSet.id);
            end
        end
    end
end
