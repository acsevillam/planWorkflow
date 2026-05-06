classdef ObjectiveApplicator
    % ObjectiveApplicator Applies template objective sets to matRad cst.

    methods (Static)
        function [cst,objectiveInfo] = apply( ...
                runConfig,cst,template,objectiveSet,objectiveSetName)
            targetName = char(template.primaryTarget);
            planWorkflow.templates.TemplateValidator.assertSupportedTarget( ...
                template,targetName);

            cst = ...
                planWorkflow.templates.StructureBuilder.createBooleanStructures( ...
                cst,template.structures);
            cst = planWorkflow.templates.ObjectiveApplicator.clearObjectives( ...
                cst);
            context = ...
                planWorkflow.templates.ObjectiveApplicator.objectiveContext( ...
                template,runConfig);
            structureIx = ...
                planWorkflow.templates.StructureBuilder.structureIndexMap(cst);

            ixBody = planWorkflow.templates.StructureBuilder.getStructureIndex( ...
                structureIx,'BODY',true);
            ixCTV = planWorkflow.templates.StructureBuilder.getStructureIndex( ...
                structureIx,char(template.primaryTarget),true);

            for i = 1:numel(template.structures)
                spec = template.structures(i);
                structureName = char(spec.name);

                ix = ...
                    planWorkflow.templates.StructureBuilder.getStructureIndex( ...
                    structureIx,structureName,false);
                if ix == 0
                    continue;
                end

                spec.objectives = ...
                    planWorkflow.templates.ObjectiveApplicator.objectivesForGroup( ...
                    objectiveSet.structureObjectives,structureName, ...
                    sprintf('template.objectiveSets.%s.structureObjectives', ...
                    char(objectiveSetName)));
                cst = ...
                    planWorkflow.templates.ObjectiveApplicator.applyStructureSpec( ...
                    cst,ix,spec,context);
            end

            ixTarget = planWorkflow.templates.StructureBuilder.getStructureIndex( ...
                structureIx,targetName,true);

            objectiveInfo = struct();
            objectiveInfo.templateId = char(template.id);
            objectiveInfo.beamSetId = char(runConfig.plan_beams);
            objectiveInfo.targetName = targetName;
            objectiveInfo.ixTarget = ixTarget;
            objectiveInfo.ixBody = ixBody;
            objectiveInfo.ixCTV = ixCTV;
            objectiveInfo.robustOarNames = ...
                planWorkflow.templates.ObjectiveApplicator.robustOarNames(cst);
            objectiveInfo.prescriptionDose = template.prescriptionDose;
            objectiveInfo.objectiveSetName = char(objectiveSetName);
        end

        function [cst,objectiveInfo] = addDerivedStructures( ...
                runConfig,cst,ct,objectiveInfo,template,objectiveSet, ...
                objectiveSetName)
            context = ...
                planWorkflow.templates.ObjectiveApplicator.objectiveContext( ...
                template,runConfig);

            ringIndices = zeros(1,numel(template.rings));
            for i = 1:numel(template.rings)
                ring = template.rings(i);
                ring.objectives = ...
                    planWorkflow.templates.ObjectiveApplicator.objectivesForGroup( ...
                    objectiveSet.ringObjectives,char(ring.name), ...
                    sprintf('template.objectiveSets.%s.ringObjectives', ...
                    char(objectiveSetName)));
                ixRing = ...
                    planWorkflow.templates.StructureBuilder.findStructureIndex( ...
                    cst,char(ring.name));
                if ixRing == 0
                    [cst,ixRing] = ...
                        planWorkflow.templates.StructureBuilder.createRing( ...
                        cst,ct,objectiveInfo.ixTarget, ...
                        objectiveInfo.ixBody,ring);
                end

                cst{ixRing,3} = char(ring.role);
                cst{ixRing,5}.Priority = ring.priority;
                if isfield(ring,'visibleColor') && ~isempty(ring.visibleColor)
                    cst{ixRing,5}.visibleColor = ring.visibleColor(:)';
                end
                cst{ixRing,6} = ...
                    planWorkflow.templates.ObjectiveApplicator.buildObjectives( ...
                    ring.objectives,context);
                ringIndices(i) = ixRing;
            end

            objectiveInfo.ringIndices = ringIndices;
            objectiveInfo.ixRing1 = ...
                planWorkflow.templates.StructureBuilder.indexOrEmpty( ...
                ringIndices,1);
            objectiveInfo.ixRing2 = ...
                planWorkflow.templates.StructureBuilder.indexOrEmpty( ...
                ringIndices,2);
        end

        function cst = clearObjectives(cst)
            planWorkflow.templates.ObjectiveApplicator.validateCst(cst);
            for structure = 1:size(cst,1)
                cst{structure,6} = [];
            end
        end

        function cst = applyStructureSpec(cst,ix,spec,context)
            cst{ix,3} = char(spec.role);
            cst{ix,5}.Priority = spec.priority;
            if isfield(spec,'visibleColor') && ~isempty(spec.visibleColor)
                cst{ix,5}.visibleColor = spec.visibleColor(:)';
            end
            cst{ix,6} = ...
                planWorkflow.templates.ObjectiveApplicator.buildObjectives( ...
                spec.objectives,context);
        end

        function objectives = buildObjectives(objectiveSpecs,context)
            objectives = {};
            if isempty(objectiveSpecs)
                return;
            end

            for i = 1:numel(objectiveSpecs)
                objectiveSpec = ...
                    planWorkflow.templates.ObjectiveApplicator.objectiveAt( ...
                    objectiveSpecs,i);
                if ~objectiveSpec.enabled
                    continue;
                end
                if isfield(objectiveSpec,'properties') && ...
                        isfield(objectiveSpec.properties,'robustness')
                    planWorkflow.templates.ObjectiveFactory.validateRobustnessForObjectiveType( ...
                        objectiveSpec.type,objectiveSpec.properties.robustness, ...
                        'template.objectives.properties');
                end
                parameterNames = ...
                    planWorkflow.templates.ObjectiveFactory.parameterNamesForObjectiveType( ...
                    objectiveSpec.type);
                namedParams = ...
                    planWorkflow.templates.ObjectiveApplicator.evaluateParameterMap( ...
                    objectiveSpec.parameters,parameterNames,context);
                [namedParams,pullingInfo] = ...
                    planWorkflow.templates.ObjectiveApplicator.applyInitialDosePulling( ...
                    objectiveSpec,parameterNames,namedParams,context);
                params = ...
                    planWorkflow.templates.ObjectiveApplicator.orderedParameterValues( ...
                    namedParams,parameterNames);
                objective = ...
                    planWorkflow.templates.ObjectiveFactory.constructObjective( ...
                    objectiveSpec.type,params);
                objective = ...
                    planWorkflow.templates.ObjectiveApplicator.applyObjectiveProperties( ...
                    objective,objectiveSpec.properties);
                objective = ...
                    planWorkflow.templates.ObjectiveApplicator.applyDosePullingInfo( ...
                    objective,pullingInfo,parameterNames);
                objectives{end + 1} = objective; %#ok<AGROW>
            end
        end

        function context = objectiveContext(template,runConfig)
            context = struct();
            context.prescriptionDose = template.prescriptionDose;
            context.dosePulling = struct();
            channelNames = fieldnames(template.dosePulling);
            for i = 1:numel(channelNames)
                channelName = channelNames{i};
                channel = template.dosePulling.(channelName);
                startValue = ...
                    planWorkflow.config.DosePullingConfig.activeStartValue( ...
                    runConfig,channel,channelName);
                if isempty(startValue)
                    continue;
                end
                channelKey = matlab.lang.makeValidName(channelName);
                context.dosePulling.(channelKey) = struct( ...
                    'name',channelName,'step',channel.step, ...
                    'startValue',startValue);
            end
        end

        function names = robustOarNames(cst)
            names = {};
            for i = 1:size(cst,1)
                structureName = char(cst{i,2});
                if strcmp(structureName,'BODY') || ...
                        ~strcmp(char(cst{i,3}),'OAR') || isempty(cst{i,6})
                    continue;
                end
                names{end + 1} = structureName; %#ok<AGROW>
            end
        end
    end

    methods (Static, Access = private)
        function objectives = objectivesForGroup(groups,groupName,context)
            groupIx = planWorkflow.templates.ObjectiveApplicator.findTextField( ...
                groups,'name',groupName);
            if groupIx == 0
                error('planWorkflow:templates:PlanTemplate:MissingObjectives', ...
                    '%s must define objectives for "%s".', ...
                    context,char(groupName));
            end
            objectives = groups(groupIx).objectives;
        end

        function objectiveSpec = objectiveAt(objectives,index)
            if iscell(objectives)
                objectiveSpec = objectives{index};
            else
                objectiveSpec = objectives(index);
            end
        end

        function namedParams = evaluateParameterMap( ...
                parameterSpecs,parameterNames,context)
            namedParams = struct();
            for i = 1:numel(parameterNames)
                name = parameterNames{i};
                namedParams.(name) = ...
                    planWorkflow.templates.ObjectiveApplicator.evaluateParameterValue( ...
                    parameterSpecs.(name),context);
            end
        end

        function value = evaluateParameterValue(parameterSpec,context)
            if isnumeric(parameterSpec)
                value = parameterSpec;
                return;
            end
            if ischar(parameterSpec) || isstring(parameterSpec)
                value = char(parameterSpec);
                return;
            end

            switch char(parameterSpec.ref)
                case 'prescriptionDose'
                    value = context.prescriptionDose;
                otherwise
                    error('planWorkflow:templates:PlanTemplate:UnknownParameterSource', ...
                        'Unknown objective parameter source "%s".', ...
                        char(parameterSpec.ref));
            end
            value = value * ...
                planWorkflow.templates.ObjectiveApplicator.optionalNumericField( ...
                parameterSpec,'scale',1) + ...
                planWorkflow.templates.ObjectiveApplicator.optionalNumericField( ...
                parameterSpec,'offset',0);
        end

        function [namedParams,pullingInfo] = applyInitialDosePulling( ...
                objectiveSpec,parameterNames,namedParams,context)
            pullingInfo = struct('enabled',false,'step',[], ...
                'penaltyRate',0,'parameterRates',[]);
            if ~isfield(objectiveSpec,'dosePulling') || ...
                    isempty(objectiveSpec.dosePulling)
                return;
            end

            channelName = char(objectiveSpec.dosePulling.channel);
            channelKey = matlab.lang.makeValidName(channelName);
            if ~isfield(context.dosePulling,channelKey)
                return;
            end
            channel = context.dosePulling.(channelKey);
            rateNames = fieldnames(objectiveSpec.dosePulling.rates);
            parameterRates = zeros(1,max(0,numel(parameterNames) - 1));

            for i = 1:numel(rateNames)
                rateName = rateNames{i};
                rate = objectiveSpec.dosePulling.rates.(rateName);
                namedParams.(rateName) = namedParams.(rateName) + ...
                    channel.startValue * rate;
                if strcmp(rateName,'penalty')
                    pullingInfo.penaltyRate = rate;
                else
                    paramIx = find(strcmp(parameterNames(2:end),rateName),1);
                    parameterRates(paramIx) = rate;
                end
            end

            pullingInfo.enabled = true;
            pullingInfo.step = channel.step;
            pullingInfo.parameterRates = parameterRates;
        end

        function params = orderedParameterValues(namedParams,parameterNames)
            params = cell(1,numel(parameterNames));
            for i = 1:numel(parameterNames)
                params{i} = namedParams.(parameterNames{i});
            end
        end

        function objective = applyObjectiveProperties(objective,properties)
            objective.robustness = char(properties.robustness);
        end

        function objective = applyDosePullingInfo( ...
                objective,pullingInfo,parameterNames) %#ok<INUSD>
            objective.dosePulling = logical(pullingInfo.enabled);
            if objective.dosePulling
                objective.pullingStep = pullingInfo.step;
                objective.penaltyPullingRate = pullingInfo.penaltyRate;
                objective.objectivePullingRate = num2cell( ...
                    pullingInfo.parameterRates);
            end
        end

        function ix = findTextField(values,fieldName,needle)
            ix = 0;
            for i = 1:numel(values)
                if strcmp(char(values(i).(fieldName)),char(needle))
                    ix = i;
                    return;
                end
            end
        end

        function value = optionalNumericField(input,fieldName,defaultValue)
            if isfield(input,fieldName)
                value = input.(fieldName);
            else
                value = defaultValue;
            end
        end

        function validateCst(cst)
            if ~iscell(cst) || size(cst,2) < 6
                error('planWorkflow:templates:PlanTemplate:InvalidCst', ...
                    'cst must be a matRad cst cell array with at least six columns.');
            end
        end
    end
end
