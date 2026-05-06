classdef TemplateIO
    % TemplateIO Handles JSON I/O for plan templates.

    methods (Static)
        function template = loadFromFolder(templateFolder,expectedId)
            templateFolder = char(templateFolder);
            expectedId = char(expectedId);

            if ~isfolder(templateFolder)
                error('planWorkflow:templates:PlanTemplate:UnknownTemplate', ...
                    'Unknown plan template "%s".',expectedId);
            end

            metadata = planWorkflow.templates.TemplateIO.decodeJsonFile( ...
                fullfile(templateFolder,'metadata.json'));
            planWorkflow.templates.TemplateValidator.validateMetadataComponent( ...
                metadata);
            beams = planWorkflow.templates.TemplateIO.decodeTemplateComponent( ...
                templateFolder,metadata,'beams');
            objectives = planWorkflow.templates.TemplateIO.decodeTemplateComponent( ...
                templateFolder,metadata,'objectives');
            structures = planWorkflow.templates.TemplateIO.decodeTemplateComponent( ...
                templateFolder,metadata,'structures');
            objectives = ...
                planWorkflow.templates.TemplateIO.resolveObjectiveSetReferences( ...
                templateFolder,metadata,objectives);

            planWorkflow.templates.TemplateValidator.validateComponents( ...
                beams,structures,objectives);

            template = planWorkflow.templates.TemplateIO.templateMetadata( ...
                metadata);
            template.prescriptionDose = objectives.prescriptionDose;
            template.dosePulling = objectives.dosePulling;
            template.radiationModes = beams.radiationModes;
            template.beamSets = beams.beamSets;
            template.primaryTarget = objectives.target;
            template.structures = structures.structures;
            template.rings = structures.rings;
            template.objectiveSets = ...
                planWorkflow.templates.TemplateIO.objectiveSetsFromComponent( ...
                objectives);
            template.targets = ...
                planWorkflow.templates.TemplateIO.targetCandidates( ...
                template.structures,template.primaryTarget);

            planWorkflow.templates.TemplateValidator.validateTemplate( ...
                template,expectedId);
        end

        function writeToFolder(template,templateFolder,description,templateId)
            templateFolder = char(templateFolder);
            if isfolder(templateFolder)
                error('planWorkflow:templates:PlanTemplate:TemplateExists', ...
                    'Plan template folder already exists: %s.', ...
                    templateFolder);
            end

            components = planWorkflow.templates.TemplateIO.toComponents( ...
                template,description,templateId);
            planWorkflow.templates.TemplateValidator.validateComponents( ...
                components.beams,components.structures, ...
                components.objectives);

            mkdir(templateFolder);
            planWorkflow.templates.TemplateIO.writeJsonFile( ...
                fullfile(templateFolder,'metadata.json'), ...
                components.metadata);
            planWorkflow.templates.TemplateIO.writeJsonFile( ...
                fullfile(templateFolder,'beams.json'),components.beams);
            planWorkflow.templates.TemplateIO.writeJsonFile( ...
                fullfile(templateFolder,'objectives.json'), ...
                components.objectives);
            planWorkflow.templates.TemplateIO.writeJsonFile( ...
                fullfile(templateFolder,'structures.json'), ...
                components.structures);
        end

        function value = decodeJsonFile(jsonFile)
            jsonFile = char(jsonFile);
            if ~isfile(jsonFile)
                error('planWorkflow:templates:PlanTemplate:MissingComponent', ...
                    'Plan template component is missing: %s.',jsonFile);
            end

            try
                value = jsondecode(fileread(jsonFile));
            catch ME
                error('planWorkflow:templates:PlanTemplate:InvalidJson', ...
                    'Could not decode plan template JSON "%s": %s', ...
                    jsonFile,ME.message);
            end

            if ~isstruct(value) || ~isscalar(value)
                error('planWorkflow:templates:PlanTemplate:InvalidStruct', ...
                    '%s must decode to a scalar JSON object.',jsonFile);
            end
        end

        function writeJsonFile(jsonFile,value)
            jsonFile = char(jsonFile);
            fid = fopen(jsonFile,'w');
            if fid == -1
                error('planWorkflow:templates:PlanTemplate:WriteFailed', ...
                    'Could not open plan template component for writing: %s.', ...
                    jsonFile);
            end
            cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
        end

        function components = toComponents(template,description,templateId)
            description = char(description);
            templateId = ...
                planWorkflow.templates.PlanTemplate.normalizeTemplateId( ...
                description,templateId);
            template = planWorkflow.templates.TemplateIO.withIdentity( ...
                template,description,templateId);
            planWorkflow.templates.TemplateValidator.validateTemplate( ...
                template,templateId);

            components = struct();
            components.metadata = struct( ...
                'schemaVersion',template.schemaVersion, ...
                'id',templateId, ...
                'description',description);
            components.beams = struct();
            components.beams.radiationModes = template.radiationModes;
            components.beams.beamSets = template.beamSets;
            components.structures = struct( ...
                'structures',template.structures, ...
                'rings',template.rings);
            components.objectives = struct( ...
                'target',char(template.primaryTarget), ...
                'prescriptionDose',template.prescriptionDose, ...
                'dosePulling',template.dosePulling, ...
                'objectiveSets',template.objectiveSets);
        end
    end

    methods (Static, Access = private)
        function value = decodeTemplateComponent( ...
                templateFolder,metadata,componentName)
            jsonFile = fullfile(templateFolder,[componentName '.json']);
            if isfield(metadata,'components') && ...
                    isfield(metadata.components,componentName)
                jsonFile = ...
                    planWorkflow.templates.TemplateIO.componentReferenceFile( ...
                    templateFolder,metadata, ...
                    metadata.components.(componentName),componentName);
            end
            value = planWorkflow.templates.TemplateIO.decodeJsonFile(jsonFile);
        end

        function jsonFile = componentReferenceFile( ...
                templateFolder,metadata,componentReference,componentName)
            jsonFile = ...
                planWorkflow.templates.TemplateIO.relativeJsonReferenceFile( ...
                templateFolder,metadata.description,componentReference, ...
                sprintf('metadata.json.components.%s',componentName));
        end

        function jsonFile = relativeJsonReferenceFile( ...
                templateFolder,description,componentReference,context)
            parts = ...
                planWorkflow.templates.TemplateValidator.validateComponentReference( ...
                componentReference,context,description);
            jsonFile = fullfile(fileparts(templateFolder),parts{:});
        end

        function metadata = templateMetadata(metadata)
            if isfield(metadata,'components')
                metadata = rmfield(metadata,'components');
            end
        end

        function objectives = resolveObjectiveSetReferences( ...
                templateFolder,metadata,objectives)
            if ~isstruct(objectives) || ~isscalar(objectives) || ...
                    ~isfield(objectives,'objectiveSets')
                return;
            end

            objectiveSets = objectives.objectiveSets;
            if isfield(objectiveSets,'reference')
                objectiveSets.reference = ...
                    planWorkflow.templates.TemplateIO.resolveObjectiveSetReference( ...
                    templateFolder,metadata,objectiveSets.reference, ...
                    'objectives.json.objectiveSets.reference');
            end

            if isfield(objectiveSets,'robustPlans') && ...
                    isstruct(objectiveSets.robustPlans)
                robustPlans = objectiveSets.robustPlans;
                resolvedPlans = cell(1,numel(robustPlans));
                for planIx = 1:numel(robustPlans)
                    resolvedPlans{planIx} = ...
                        planWorkflow.templates.TemplateIO.resolveObjectiveSetReference( ...
                        templateFolder,metadata,robustPlans(planIx), ...
                        sprintf(['objectives.json.objectiveSets.' ...
                        'robustPlans(%d)'],planIx));
                end
                objectiveSets.robustPlans = [resolvedPlans{:}];
            end
            objectives.objectiveSets = objectiveSets;
        end

        function objectiveSet = resolveObjectiveSetReference( ...
                templateFolder,metadata,objectiveSet,context)
            if ~isstruct(objectiveSet) || ~isscalar(objectiveSet) || ...
                    ~isfield(objectiveSet,'ref')
                return;
            end

            jsonFile = ...
                planWorkflow.templates.TemplateIO.relativeJsonReferenceFile( ...
                templateFolder,metadata.description,objectiveSet.ref, ...
                [context '.ref']);
            resolvedSet = ...
                planWorkflow.templates.TemplateIO.decodeJsonFile(jsonFile);
            overrideSet = rmfield(objectiveSet,'ref');
            objectiveSet = ...
                planWorkflow.templates.TemplateIO.mergeStruct( ...
                resolvedSet,overrideSet);
        end

        function merged = mergeStruct(base,override)
            merged = base;
            fields = fieldnames(override);
            for i = 1:numel(fields)
                merged.(fields{i}) = override.(fields{i});
            end
        end

        function template = withIdentity(template,description,templateId)
            template.schemaVersion = 1;
            template.id = char(templateId);
            template.description = char(description);
            template.targets = planWorkflow.templates.TemplateIO.targetCandidates( ...
                template.structures,template.primaryTarget);
        end

        function objectiveSets = objectiveSetsFromComponent(objectives)
            objectiveSets = objectives.objectiveSets;
        end

        function targets = targetCandidates(structures,~)
            targets = {};
            for i = 1:numel(structures)
                structureName = char(structures(i).name);
                isTargetRole = strcmp(char(structures(i).role),'TARGET');
                if isTargetRole
                    targets{end + 1} = structureName; %#ok<AGROW>
                end
            end
            [~,ia] = unique(targets,'stable');
            targets = targets(sort(ia));
        end
    end
end
