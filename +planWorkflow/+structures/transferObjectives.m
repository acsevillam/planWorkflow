function cst = transferObjectives(cst,sourceCst)
% transferObjectives Copies objective payloads by structure name.

validateCst(cst,'destination CST');
validateCst(sourceCst,'source CST');

destinationNames = structureNames(cst,'destination CST');
sourceNames = structureNames(sourceCst,'source CST');
assertUniqueNames(destinationNames,'destination CST');
assertUniqueNames(sourceNames,'source CST');

for rowIx = 1:size(cst,1)
    sourceIx = find(strcmp(sourceNames,destinationNames{rowIx}),1);
    if isempty(sourceIx)
        continue;
    end
    cst{rowIx,6} = sourceCst{sourceIx,6};
end
end

function validateCst(cst,context)
if ~iscell(cst) || size(cst,2) < 6
    error('planWorkflow:structures:transferObjectives:InvalidCst', ...
        '%s must be a CST cell array with at least 6 columns.', ...
        char(context));
end
end

function names = structureNames(cst,context)
names = cell(1,size(cst,1));
for rowIx = 1:size(cst,1)
    name = cst{rowIx,2};
    if ~(ischar(name) || (isstring(name) && isscalar(name))) || ...
            strlength(string(name)) == 0
        error(['planWorkflow:structures:transferObjectives:' ...
            'InvalidStructureName'], ...
            '%s row %d must contain a nonempty text structure name.', ...
            char(context),rowIx);
    end
    names{rowIx} = char(name);
end
end

function assertUniqueNames(names,context)
for nameIx = 1:numel(names)
    if sum(strcmp(names,names{nameIx})) > 1
        error(['planWorkflow:structures:transferObjectives:' ...
            'DuplicateStructureName'], ...
            '%s contains duplicate structure name "%s".', ...
            char(context),names{nameIx});
    end
end
end
