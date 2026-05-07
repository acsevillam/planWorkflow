classdef ObjectiveTableAdapter
    % ObjectiveTableAdapter maps template objective sets to GUI rows.

    methods (Static)
        function columnFormat = columnFormat(template)
            objectiveTypes = ...
                planWorkflow.templates.PlanTemplate.supportedObjectiveTypes();
            robustnessValues = ...
                planWorkflow.templates.PlanTemplate.supportedObjectiveRobustnessValues();
            columnFormat = { ...
                'logical', ...
                planWorkflow.gui.ObjectiveTableAdapter.structureOptions( ...
                template), ...
                objectiveTypes,'char',robustnessValues,'char'};
        end

        function data = toTable(template,objectiveSetName)
            if nargin < 2 || isempty(objectiveSetName)
                objectiveSetName = 'reference';
            end
            objectiveSet = planWorkflow.templates.PlanTemplate.objectiveSet( ...
                template,objectiveSetName);
            data = cell(0,6);
            data = planWorkflow.gui.ObjectiveTableAdapter.appendRows( ...
                data,objectiveSet.structureObjectives);
            data = planWorkflow.gui.ObjectiveTableAdapter.appendRows( ...
                data,objectiveSet.ringObjectives);
        end

        function template = applyTable(template,data,objectiveSetName)
            if nargin < 3 || isempty(objectiveSetName)
                objectiveSetName = 'reference';
            end

            objectiveSet = planWorkflow.templates.PlanTemplate.objectiveSet( ...
                template,objectiveSetName);
            objectiveSet.structureObjectives = ...
                planWorkflow.gui.ObjectiveTableAdapter.emptyGroups( ...
                template.structures);
            objectiveSet.ringObjectives = ...
                planWorkflow.gui.ObjectiveTableAdapter.emptyGroups( ...
                template.rings);

            for rowIx = 1:size(data,1)
                structureName = char(data{rowIx,2});
                objective = ...
                    planWorkflow.gui.ObjectiveTableAdapter.objectiveFromRow( ...
                    data(rowIx,:));
                [kind,index] = ...
                    planWorkflow.gui.ObjectiveTableAdapter.findGroup( ...
                    template,structureName);
                if strcmp(kind,'structure')
                    objectives = ...
                        objectiveSet.structureObjectives(index).objectives;
                    objectives{end + 1} = objective; %#ok<AGROW>
                    objectiveSet.structureObjectives(index).objectives = ...
                        objectives;
                else
                    objectives = objectiveSet.ringObjectives(index).objectives;
                    objectives{end + 1} = objective; %#ok<AGROW>
                    objectiveSet.ringObjectives(index).objectives = objectives;
                end
            end
            template = planWorkflow.templates.PlanTemplate.setObjectiveSet( ...
                template,objectiveSetName,objectiveSet);
        end

        function tf = isRobustnessEdit(event)
            tf = false;
            if isempty(event)
                return;
            end
            try
                indices = event.Indices;
            catch
                return;
            end
            if isempty(indices) || size(indices,2) < 2
                return;
            end
            tf = indices(2) == ...
                planWorkflow.gui.ObjectiveTableAdapter.robustnessColumnIndex();
        end

        function data = harmonizeNonNoneRobustness(data,robustness)
            robustness = char(robustness);
            robustnessColumn = ...
                planWorkflow.gui.ObjectiveTableAdapter.robustnessColumnIndex();
            for rowIx = 1:size(data,1)
                if ~strcmp(char(data{rowIx,robustnessColumn}),'none')
                    data{rowIx,robustnessColumn} = robustness;
                end
            end
        end

        function robustness = editedRobustness(data,event)
            robustnessColumn = ...
                planWorkflow.gui.ObjectiveTableAdapter.robustnessColumnIndex();
            rowIx = event.Indices(1);
            robustness = char(data{rowIx,robustnessColumn});
        end

        function columnIx = robustnessColumnIndex()
            columnIx = 5;
        end

        function groups = emptyGroups(baseSpecs)
            groups = repmat(struct('name','','objectives',{{}}), ...
                1,numel(baseSpecs));
            for i = 1:numel(baseSpecs)
                groups(i).name = char(baseSpecs(i).name);
                groups(i).objectives = cell(1,0);
            end
        end

        function row = defaultRow(structureName)
            params = struct();
            params.penalty = 1;
            params.dRef = struct('ref','prescriptionDose');
            params.vMaxPercent = 0;
            row = {true,structureName,'matRad_MaxDVH', ...
                jsonencode(params),'none',''};
        end
    end

    methods (Static, Access = private)
        function values = structureOptions(template)
            values = {};
            values = planWorkflow.gui.ObjectiveTableAdapter.appendGroupNames( ...
                values,template.structures);
            values = planWorkflow.gui.ObjectiveTableAdapter.appendGroupNames( ...
                values,template.rings);
            values = unique(values,'stable');
        end

        function values = appendGroupNames(values,groups)
            for groupIx = 1:numel(groups)
                name = planWorkflow.gui.ObjectiveTableAdapter.fieldText( ...
                    groups(groupIx),'name');
                if ~isempty(name)
                    values{end + 1} = name; %#ok<AGROW>
                end
            end
        end

        function data = appendRows(data,groups)
            for groupIx = 1:numel(groups)
                structureName = char(groups(groupIx).name);
                objectives = groups(groupIx).objectives;
                for objectiveIx = 1:numel(objectives)
                    objective = ...
                        planWorkflow.gui.ObjectiveTableAdapter.objectiveAt( ...
                        objectives,objectiveIx);
                    dosePullingText = '';
                    if isfield(objective,'dosePulling') && ...
                            ~isempty(objective.dosePulling)
                        dosePullingText = jsonencode(objective.dosePulling);
                    end
                    data(end + 1,:) = {logical(objective.enabled), ...
                        structureName,char(objective.type), ...
                        jsonencode(objective.parameters), ...
                        char(objective.properties.robustness), ...
                        dosePullingText}; %#ok<AGROW>
                end
            end
        end

        function objective = objectiveFromRow(row)
            objective = struct();
            objective.enabled = ...
                planWorkflow.gui.ObjectiveTableAdapter.logicalValue( ...
                row{1},'objective.enabled');
            objective.type = char(row{3});
            objectiveTypes = ...
                planWorkflow.templates.PlanTemplate.supportedObjectiveTypes();
            if ~any(strcmp(objective.type,objectiveTypes))
                error('planWorkflow:gui:ObjectiveTableAdapter:InvalidObjectiveType', ...
                    'Objective type "%s" is not supported.', ...
                    objective.type);
            end
            objective.parameters = jsondecode(char(row{4}));
            robustness = char(row{5});
            if ~planWorkflow.matRadCapabilitiesReader.supportsObjectiveRobustness( ...
                    objective.type,robustness)
                error(['planWorkflow:gui:ObjectiveTableAdapter:' ...
                    'InvalidObjectiveRobustness'], ...
                    ['Objective robustness "%s" is not supported by ' ...
                    'objective type "%s".'],robustness,objective.type);
            end
            objective.properties = struct('robustness',robustness);
            dosePullingText = strtrim(char(row{6}));
            if ~isempty(dosePullingText)
                objective.dosePulling = jsondecode(dosePullingText);
            end
        end

        function value = logicalValue(rawValue,context)
            if ~(islogical(rawValue) || isnumeric(rawValue)) || ...
                    ~isscalar(rawValue)
                error('planWorkflow:gui:ObjectiveTableAdapter:InvalidLogicalValue', ...
                    '%s must be a logical scalar.',context);
            end
            value = logical(rawValue);
        end

        function [kind,index] = findGroup(template,structureName)
            structureMatches = strcmp({template.structures.name},structureName);
            ringMatches = strcmp({template.rings.name},structureName);
            if sum(structureMatches) + sum(ringMatches) ~= 1
                error(['planWorkflow:gui:ObjectiveTableAdapter:' ...
                    'UnknownObjectiveStructure'], ...
                    'Unknown or ambiguous objective structure "%s".', ...
                    structureName);
            end
            if any(structureMatches)
                kind = 'structure';
                index = find(structureMatches,1);
            else
                kind = 'ring';
                index = find(ringMatches,1);
            end
        end

        function objective = objectiveAt(objectives,index)
            if iscell(objectives)
                objective = objectives{index};
            else
                objective = objectives(index);
            end
        end

        function text = fieldText(spec,fieldName)
            if ~isfield(spec,fieldName) || isempty(spec.(fieldName))
                text = '';
                return;
            end
            value = spec.(fieldName);
            if ischar(value)
                text = value;
            elseif isstring(value)
                text = char(value);
            elseif isnumeric(value) || islogical(value)
                text = mat2str(value);
            else
                text = char(string(value));
            end
        end
    end
end
