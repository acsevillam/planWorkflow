classdef StructureBuilder
    % StructureBuilder Builds derived template structures.

    methods (Static)
        function cst = createBooleanStructures(cst,structures)
            planWorkflow.templates.StructureBuilder.validateCst(cst);
            for i = 1:numel(structures)
                spec = structures(i);
                if ~planWorkflow.templates.StructureBuilder.hasTextField( ...
                        spec,'operation')
                    continue;
                end

                structureName = char(spec.name);
                scenarioVoxels = ...
                    planWorkflow.templates.StructureBuilder.evaluateBooleanOperation( ...
                    cst,structureName,char(spec.operation));
                ix = planWorkflow.templates.StructureBuilder.findStructureIndex( ...
                    cst,structureName);
                if ix == 0
                    cst = planWorkflow.templates.StructureBuilder.appendStructure( ...
                        cst,spec,scenarioVoxels);
                else
                    cst{ix,4} = scenarioVoxels;
                end
            end
        end

        function [cst,ixRing] = createRing(cst,ct,ixTarget,ixBody,ring)
            vInnerMargin = planWorkflow.templates.StructureBuilder.marginStruct( ...
                ring.innerMarginMm);
            vOuterMargin = planWorkflow.templates.StructureBuilder.marginStruct( ...
                ring.outerMarginMm);
            metadata = struct('name',char(ring.name), ...
                'type',char(ring.role), ...
                'visibleColor',ring.visibleColor(:)');
            [cst,ixRing] = matRad_createRing(ixTarget,ixBody,cst,ct, ...
                vOuterMargin,vInnerMargin,metadata);
        end

        function margin = marginStruct(value)
            margin = struct('x',value,'y',value,'z',value);
        end

        function structureIx = structureIndexMap(cst)
            structureIx = struct();
            for i = 1:size(cst,1)
                fieldName = matlab.lang.makeValidName(char(cst{i,2}));
                structureIx.(fieldName) = i;
            end
        end

        function ix = getStructureIndex(structureIx,structureName,required)
            fieldName = matlab.lang.makeValidName(char(structureName));
            if isfield(structureIx,fieldName)
                ix = structureIx.(fieldName);
            else
                ix = 0;
            end

            if ix == 0 && required
                error('planWorkflow:templates:PlanTemplate:MissingStructure', ...
                    'Plan template requires structure "%s".',structureName);
            end
        end

        function ix = findStructureIndex(cst,structureName)
            ix = 0;
            for i = 1:size(cst,1)
                if strcmp(char(cst{i,2}),char(structureName))
                    ix = i;
                    return;
                end
            end
        end

        function index = indexOrEmpty(values,index)
            if numel(values) >= index
                index = values(index);
            else
                index = [];
            end
        end
    end

    methods (Static, Access = private)
        function cst = appendStructure(cst,spec,scenarioVoxels)
            ix = size(cst,1) + 1;
            cst{ix,1} = ix - 1;
            cst{ix,2} = char(spec.name);
            cst{ix,3} = char(spec.role);
            cst{ix,4} = scenarioVoxels;
            cst{ix,5} = struct('Priority',spec.priority, ...
                'Visible',true,'visibleColor', ...
                planWorkflow.templates.StructureBuilder.visibleColor(spec));
            cst{ix,6} = [];
        end

        function scenarioVoxels = evaluateBooleanOperation( ...
                cst,targetName,operation)
            [operands,operators] = ...
                planWorkflow.templates.StructureBuilder.parseBooleanOperation( ...
                operation);
            if any(strcmp(operands,char(targetName)))
                error('planWorkflow:templates:PlanTemplate:SelfBooleanOperation', ...
                    'Structure "%s" operation must not reference itself.', ...
                    char(targetName));
            end

            operandIx = zeros(1,numel(operands));
            scenarioCount = 0;
            for i = 1:numel(operands)
                operandIx(i) = ...
                    planWorkflow.templates.StructureBuilder.findStructureIndex( ...
                    cst,operands{i});
                if operandIx(i) == 0
                    error('planWorkflow:templates:PlanTemplate:MissingBooleanOperand', ...
                        'Boolean operation "%s" references missing structure "%s".', ...
                        char(operation),operands{i});
                end
                scenarioCount = max(scenarioCount,numel(cst{operandIx(i),4}));
            end

            scenarioVoxels = cell(1,scenarioCount);
            for scenIx = 1:scenarioCount
                voxels = planWorkflow.templates.StructureBuilder.scenarioVoxels( ...
                    cst,operandIx(1),scenIx);
                for opIx = 1:numel(operators)
                    rhs = planWorkflow.templates.StructureBuilder.scenarioVoxels( ...
                        cst,operandIx(opIx + 1),scenIx);
                    switch operators{opIx}
                        case '+'
                            voxels = union(voxels,rhs);
                        case '-'
                            voxels = setdiff(voxels,rhs);
                    end
                end
                scenarioVoxels{scenIx} = voxels(:);
            end
        end

        function voxels = scenarioVoxels(cst,structureIx,scenarioIx)
            structureScenarios = cst{structureIx,4};
            scenarioIx = min(scenarioIx,numel(structureScenarios));
            voxels = structureScenarios{scenarioIx};
            voxels = voxels(:);
        end

        function [operands,operators] = parseBooleanOperation(operation)
            operation = strtrim(char(operation));
            if isempty(operation)
                error('planWorkflow:templates:PlanTemplate:InvalidBooleanOperation', ...
                    'Boolean structure operation must not be empty.');
            end

            tokens = regexp(operation,'([^\+\-]+|[\+\-])','match');
            tokens = cellfun(@strtrim,tokens,'UniformOutput',false);
            tokens = tokens(~cellfun(@isempty,tokens));
            if numel(tokens) < 3 || mod(numel(tokens),2) == 0
                error('planWorkflow:templates:PlanTemplate:InvalidBooleanOperation', ...
                    ['Boolean structure operation "%s" must use structure ' ...
                    'names separated by + or -.'],operation);
            end

            operands = tokens(1:2:end);
            operators = tokens(2:2:end);
            validOperators = ismember(operators,{'+','-'});
            if any(cellfun(@isempty,operands)) || any(~validOperators)
                error('planWorkflow:templates:PlanTemplate:InvalidBooleanOperation', ...
                    'Boolean structure operation "%s" is invalid.',operation);
            end
        end

        function color = visibleColor(spec)
            if isfield(spec,'visibleColor') && ~isempty(spec.visibleColor)
                color = spec.visibleColor(:)';
            else
                color = [0 1 0];
            end
        end

        function tf = hasTextField(input,fieldName)
            tf = isfield(input,fieldName) && ~isempty(input.(fieldName)) && ...
                strlength(strtrim(string(input.(fieldName)))) > 0;
        end

        function validateCst(cst)
            if ~iscell(cst) || size(cst,2) < 6
                error('planWorkflow:templates:PlanTemplate:InvalidCst', ...
                    'cst must be a matRad cst cell array with at least six columns.');
            end
        end
    end
end
