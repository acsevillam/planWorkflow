function cst = applyPlanObjectives(cst,planCst)
% applyPlanObjectives Copy plan roles/properties/objectives onto a cst.

validateCst(cst,'cst');
validateCst(planCst,'planCst');

referenceNames = planCst(:,2);
assertUniqueNames(referenceNames,'planCst');

for row = 1:size(cst,1)
    cst{row,6} = [];
    referenceIx = find(strcmp(referenceNames,cst{row,2}));
    if isempty(referenceIx)
        continue;
    end

    cst{row,3} = planCst{referenceIx,3};
    cst{row,5} = planCst{referenceIx,5};
    cst{row,6} = planCst{referenceIx,6};
end

end

function validateCst(cst,argumentName)
if ~iscell(cst) || size(cst,2) < 6
    error('planWorkflow:structures:InvalidCst', ...
        '%s must be a matRad cst cell array with at least six columns.', ...
        argumentName);
end
end

function assertUniqueNames(names,argumentName)
names = cellfun(@char,names(:),'UniformOutput',false);
[~,uniqueIx] = unique(names,'stable');
if numel(uniqueIx) ~= numel(names)
    error('planWorkflow:structures:DuplicateStructureName', ...
        '%s must not contain duplicate structure names.',argumentName);
end
end
