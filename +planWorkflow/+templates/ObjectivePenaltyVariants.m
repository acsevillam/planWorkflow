classdef ObjectivePenaltyVariants
    % ObjectivePenaltyVariants Expands robust objective penalty sweeps.

    methods (Static)
        function count = maxPenaltyCombinationCount()
            count = 1000;
        end

        function count = maxExpandedVariantCount()
            count = 10000;
        end

        function variants = variantsWithPenalties( ...
                objectiveSet,variants,robustnessMode)
            if nargin < 3 || isempty(robustnessMode)
                robustnessMode = 'none';
            end
            if nargin < 2 || isempty(variants)
                variants = ...
                    planWorkflow.config.RobustPlanConfig.defaultVariants( ...
                    robustnessMode);
            end

            variants = variants(:)';
            combinations = ...
                planWorkflow.templates.ObjectivePenaltyVariants.combinations( ...
                objectiveSet,'objective penalty variants');
            combinationCount = numel(combinations);
            expandedCount = numel(variants) * combinationCount;
            if combinationCount > 1
                expandedCount = ...
                    planWorkflow.templates.ObjectivePenaltyVariants.assertExpandedVariantLimit( ...
                    numel(variants),combinationCount, ...
                    'objective penalty variants');
            end
            expanded = repmat( ...
                planWorkflow.templates.ObjectivePenaltyVariants.decorateVariant( ...
                variants(1),1,combinations{1},1,combinationCount), ...
                1,expandedCount);

            outIx = 0;
            for variantIx = 1:numel(variants)
                for combinationIx = 1:combinationCount
                    outIx = outIx + 1;
                    expanded(outIx) = ...
                        planWorkflow.templates.ObjectivePenaltyVariants.decorateVariant( ...
                        variants(variantIx),variantIx, ...
                        combinations{combinationIx},combinationIx, ...
                        combinationCount);
                end
            end
            variants = expanded;
        end

        function count = penaltyCombinationCount(objectiveSet)
            axes = planWorkflow.templates.ObjectivePenaltyVariants.axes( ...
                objectiveSet);
            count = planWorkflow.templates.ObjectivePenaltyVariants.combinationCountFromAxes( ...
                axes,'objective penalty variants');
        end

        function assertPenaltyCombinationLimit(objectiveSet,context)
            if nargin < 2 || isempty(context)
                context = 'objective set';
            end
            axes = planWorkflow.templates.ObjectivePenaltyVariants.axes( ...
                objectiveSet);
            planWorkflow.templates.ObjectivePenaltyVariants.combinationCountFromAxes( ...
                axes,context);
        end

        function objectiveSet = materializeObjectiveSet( ...
                objectiveSet,variant)
            if nargin < 2
                variant = [];
            end
            assignments = ...
                planWorkflow.templates.ObjectivePenaltyVariants.assignmentsFromVariant( ...
                objectiveSet,variant);
            for assignmentIx = 1:numel(assignments)
                assignment = assignments(assignmentIx);
                groups = objectiveSet.(assignment.groupField);
                group = ...
                    planWorkflow.templates.ObjectivePenaltyVariants.groupAt( ...
                    groups,assignment.groupIx);
                objectives = group.objectives;
                objective = ...
                    planWorkflow.templates.ObjectivePenaltyVariants.objectiveAt( ...
                    objectives,assignment.objectiveIx);
                objective.parameters.penalty = assignment.value;
                objectives = ...
                    planWorkflow.templates.ObjectivePenaltyVariants.setObjectiveAt( ...
                    objectives,assignment.objectiveIx,objective);
                group.objectives = objectives;
                groups = ...
                    planWorkflow.templates.ObjectivePenaltyVariants.setGroupAt( ...
                    groups,assignment.groupIx,group);
                objectiveSet.(assignment.groupField) = groups;
            end
        end

        function text = summary(planConfig)
            robustCount = 1;
            if isstruct(planConfig) && isfield(planConfig,'variants') && ...
                    ~isempty(planConfig.variants)
                robustCount = numel(planConfig.variants);
            end
            totalCount = ...
                planWorkflow.config.RobustPlanConfig.variantWithPenaltyCount( ...
                planConfig);
            penaltyCount = max(1,totalCount / max(1,robustCount));
            text = sprintf(['Robust variants: %d | Penalty combinations: ' ...
                '%d | Total variants: %d'],robustCount,penaltyCount, ...
                totalCount);
        end

        function values = penaltyValues(variant)
            values = [];
            if ~isstruct(variant) || ~isfield(variant,'penaltyAssignments') || ...
                    isempty(variant.penaltyAssignments)
                return;
            end
            assignments = variant.penaltyAssignments;
            values = zeros(1,numel(assignments));
            for i = 1:numel(assignments)
                values(i) = assignments(i).value;
            end
        end
    end

    methods (Static, Access = private)
        function combinations = combinations(objectiveSet,context)
            if nargin < 2 || isempty(context)
                context = 'objective set';
            end
            axes = planWorkflow.templates.ObjectivePenaltyVariants.axes( ...
                objectiveSet);
            combinationCount = planWorkflow.templates.ObjectivePenaltyVariants.combinationCountFromAxes( ...
                axes,context);
            if isempty(axes)
                combinations = { ...
                    planWorkflow.templates.ObjectivePenaltyVariants.emptyAssignments()};
                return;
            end

            lengths = ...
                planWorkflow.templates.ObjectivePenaltyVariants.axisLengths( ...
                axes);
            combinations = cell(1,combinationCount);
            for combinationIx = 1:combinationCount
                assignments = repmat( ...
                    planWorkflow.templates.ObjectivePenaltyVariants.emptyAssignment(), ...
                    1,numel(axes));
                for axisIx = 1:numel(axes)
                    stride = prod(lengths(axisIx + 1:end));
                    valueIx = floor((combinationIx - 1) / stride);
                    valueIx = mod(valueIx,lengths(axisIx)) + 1;
                    assignments(axisIx).groupField = axes(axisIx).groupField;
                    assignments(axisIx).groupIx = axes(axisIx).groupIx;
                    assignments(axisIx).objectiveIx = ...
                        axes(axisIx).objectiveIx;
                    assignments(axisIx).structureName = ...
                        axes(axisIx).structureName;
                    assignments(axisIx).value = ...
                        axes(axisIx).values(valueIx);
                end
                combinations{combinationIx} = assignments;
            end
        end

        function axes = axes(objectiveSet)
            axes = repmat(struct( ...
                'groupField','', ...
                'groupIx',0, ...
                'objectiveIx',0, ...
                'structureName','', ...
                'values',[]),1,0);
            groupFields = {'structureObjectives','ringObjectives'};
            for fieldIx = 1:numel(groupFields)
                fieldName = groupFields{fieldIx};
                if ~isfield(objectiveSet,fieldName) || ...
                        isempty(objectiveSet.(fieldName))
                    continue;
                end
                groups = objectiveSet.(fieldName);
                for groupIx = 1:numel(groups)
                    group = ...
                        planWorkflow.templates.ObjectivePenaltyVariants.groupAt( ...
                        groups,groupIx);
                    if ~isfield(group,'objectives') || ...
                            isempty(group.objectives)
                        continue;
                    end
                    objectives = group.objectives;
                    for objectiveIx = 1:numel(objectives)
                        objective = ...
                            planWorkflow.templates.ObjectivePenaltyVariants.objectiveAt( ...
                            objectives,objectiveIx);
                        if planWorkflow.templates.ObjectivePenaltyVariants.isDisabled( ...
                                objective)
                            continue;
                        end
                        if ~isfield(objective,'parameters') || ...
                                ~isfield(objective.parameters,'penalty') || ...
                                ~isnumeric(objective.parameters.penalty) || ...
                                numel(objective.parameters.penalty) <= 1
                            continue;
                        end
                        axes(end + 1) = struct( ... %#ok<AGROW>
                            'groupField',fieldName, ...
                            'groupIx',groupIx, ...
                            'objectiveIx',objectiveIx, ...
                            'structureName',char(group.name), ...
                            'values',objective.parameters.penalty(:)');
                    end
                end
            end
        end

        function lengths = axisLengths(axes)
            lengths = zeros(1,numel(axes));
            for axisIx = 1:numel(axes)
                lengths(axisIx) = numel(axes(axisIx).values);
            end
        end

        function count = combinationCountFromAxes(axes,context)
            if nargin < 2 || isempty(context)
                context = 'objective set';
            end
            if isempty(axes)
                count = 1;
                return;
            end
            lengths = ...
                planWorkflow.templates.ObjectivePenaltyVariants.axisLengths( ...
                axes);
            count = planWorkflow.templates.ObjectivePenaltyVariants.checkedPenaltyProduct( ...
                lengths,context);
        end

        function count = checkedPenaltyProduct(lengths,context)
            limit = ...
                planWorkflow.templates.ObjectivePenaltyVariants.maxPenaltyCombinationCount();
            count = 1;
            for lengthIx = 1:numel(lengths)
                factor = double(lengths(lengthIx));
                if factor > 0 && count > floor(limit / factor)
                    attempted = count * factor;
                    error(['planWorkflow:templates:ObjectivePenaltyVariants:' ...
                        'TooManyPenaltyCombinations'], ...
                        ['%s defines at least %d penalty combinations, ' ...
                        'exceeding the limit of %d. Shorten penalty arrays ' ...
                        'or split the sweep into multiple robust plans.'], ...
                        context,attempted,limit);
                end
                count = count * factor;
            end
        end

        function expandedCount = assertExpandedVariantLimit( ...
                variantCount,combinationCount,context)
            limit = ...
                planWorkflow.templates.ObjectivePenaltyVariants.maxExpandedVariantCount();
            if variantCount > 0 && combinationCount > 0 && ...
                    variantCount > floor(limit / combinationCount)
                attempted = variantCount * combinationCount;
                error(['planWorkflow:templates:ObjectivePenaltyVariants:' ...
                    'TooManyVariantsWithPenalties'], ...
                    ['%s expands to %d internal variants (%d robust ' ...
                    'variants x %d penalty combinations), exceeding the ' ...
                    'limit of %d. Reduce robust variants, shorten penalty ' ...
                    'arrays, or split the sweep into multiple robust ' ...
                    'plans.'],context,attempted,variantCount, ...
                    combinationCount,limit);
            end
            expandedCount = variantCount * combinationCount;
        end

        function assignments = assignmentsFromVariant(objectiveSet,variant)
            if isstruct(variant) && isfield(variant,'penaltyAssignments')
                assignments = variant.penaltyAssignments;
                return;
            end
            combinations = ...
                planWorkflow.templates.ObjectivePenaltyVariants.combinations( ...
                objectiveSet,'objective penalty variants');
            assignments = combinations{1};
        end

        function variant = decorateVariant(baseVariant,baseVariantIx, ...
                assignments,combinationIx,combinationCount)
            variant = baseVariant;
            variant.baseVariantId = char(baseVariant.id);
            variant.baseVariantLabel = char(baseVariant.label);
            variant.baseVariantIndex = baseVariantIx;
            variant.penaltyCombinationIndex = combinationIx;
            variant.penaltyCombinationCount = combinationCount;
            variant.penaltyAssignments = assignments;
            variant.penaltyLabel = ...
                planWorkflow.templates.ObjectivePenaltyVariants.penaltyLabel( ...
                assignments);
            if combinationCount > 1
                variant.id = ...
                    planWorkflow.templates.ObjectivePenaltyVariants.variantId( ...
                    baseVariant.id,baseVariantIx,combinationIx);
                variant.label = ...
                    planWorkflow.templates.ObjectivePenaltyVariants.variantLabel( ...
                    baseVariant.label,variant.penaltyLabel);
            end
        end

        function id = variantId(baseId,baseVariantIx,combinationIx)
            suffix = sprintf('_v%d_p%d',baseVariantIx,combinationIx);
            baseId = char(baseId);
            maxBaseLength = max(1,namelengthmax - numel(suffix));
            id = [baseId(1:min(numel(baseId),maxBaseLength)) suffix];
        end

        function label = variantLabel(baseLabel,penaltyLabel)
            if isempty(penaltyLabel)
                label = char(baseLabel);
            else
                label = [char(baseLabel) ' / ' penaltyLabel];
            end
        end

        function label = penaltyLabel(assignments)
            label = '';
            if isempty(assignments)
                return;
            end
            values = zeros(1,numel(assignments));
            for i = 1:numel(assignments)
                values(i) = assignments(i).value;
            end
            valueText = arrayfun( ...
                @(value) strtrim(num2str(value,'%g')),values, ...
                'UniformOutput',false);
            if numel(values) == 1
                label = ['penalty=' valueText{1}];
            else
                label = ['penalties=' strjoin(valueText,',')];
            end
        end

        function tf = isDisabled(objective)
            tf = isfield(objective,'enabled') && ~logical(objective.enabled);
        end

        function assignment = emptyAssignment()
            assignment = struct('groupField','','groupIx',0, ...
                'objectiveIx',0,'structureName','','value',0);
        end

        function assignments = emptyAssignments()
            assignments = repmat( ...
                planWorkflow.templates.ObjectivePenaltyVariants.emptyAssignment(), ...
                1,0);
        end

        function group = groupAt(groups,index)
            if iscell(groups)
                group = groups{index};
            else
                group = groups(index);
            end
        end

        function groups = setGroupAt(groups,index,group)
            if iscell(groups)
                groups{index} = group;
            else
                groups(index) = group;
            end
        end

        function objective = objectiveAt(objectives,index)
            if iscell(objectives)
                objective = objectives{index};
            else
                objective = objectives(index);
            end
        end

        function objectives = setObjectiveAt(objectives,index,objective)
            if iscell(objectives)
                objectives{index} = objective;
            else
                objectives(index) = objective;
            end
        end
    end
end
