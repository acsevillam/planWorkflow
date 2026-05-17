function value = sanitizeArtifactForSave(value)
    % sanitizeArtifactForSave sanitize workflow artifacts before saving.
    %
    % Copyright 2026 The matRad developers.
    %
    % This file is part of the matRad research software.
    %
    % matRad is free software: you can redistribute it and/or modify it under
    % the terms of the GNU General Public License as published by the Free
    % Software Foundation, either version 3 of the License, or any later
    % version.
    %
    % matRad is distributed in the hope that it will be useful, but WITHOUT ANY
    % WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    % FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
    % details.
    %
    % You should have received a copy of the GNU General Public License along
    % with matRad. If not, see <https://www.gnu.org/licenses/>.

    value = sanitizeNode(value, []);

end

function value = sanitizeNode(value, parent)

    if isstruct(value)
        value = sanitizeStruct(value);
    elseif iscell(value)
        value = sanitizeCell(value, parent);
    elseif isBiologicalModel(value)
        value = bioModelMetadata(value, parent);
    end

end

function value = sanitizeStruct(value)

    for elementIx = 1:numel(value)
        fields = fieldnames(value(elementIx));
        for fieldIx = 1:numel(fields)
            fieldName = fields{fieldIx};
            value(elementIx).(fieldName) = ...
                sanitizeNode(value(elementIx).(fieldName), value(elementIx));
        end
    end

end

function value = sanitizeCell(value, parent)

    for elementIx = 1:numel(value)
        value{elementIx} = sanitizeNode(value{elementIx}, parent);
    end

end

function tf = isBiologicalModel(value)

    tf = isobject(value) && isa(value, 'matRad_BiologicalModel');

end

function metadata = bioModelMetadata(bioModel, parent)

    if numel(bioModel) > 1
        metadata = repmat(bioModelMetadata(bioModel(1), parent), ...
                          size(bioModel));
        for modelIx = 2:numel(bioModel)
            metadata(modelIx) = bioModelMetadata(bioModel(modelIx), parent);
        end
        return
    end

    metadata = struct();
    metadata.artifactKind = 'planWorkflowBiologicalModelMetadata';
    metadata.bioModelClass = class(bioModel);
    metadata.model = bioModelProperty(bioModel, 'model');
    if isempty(metadata.model)
        metadata.model = contextModel(parent);
    end
    metadata.defaultReportQuantity = bioModelProperty( ...
                                                      bioModel, 'defaultReportQuantity');
    [metadata.quantityOpt, metadata.quantityVis] = contextQuantities(parent);

end

function value = bioModelProperty(bioModel, propertyName)

    value = '';
    try
        value = bioModel.(propertyName);
        value = scalarText(value);
    catch
        value = '';
    end

end

function value = contextModel(parent)

    value = '';
    if ~isstruct(parent) || ~isscalar(parent) || ~isfield(parent, 'bioParam')
        return
    end

    bioParam = parent.bioParam;
    if isstruct(bioParam) && isfield(bioParam, 'model')
        value = scalarText(bioParam.model);
    elseif isobject(bioParam) && isprop(bioParam, 'model')
        value = scalarText(bioParam.model);
    end

end

function [quantityOpt, quantityVis] = contextQuantities(parent)

    quantityOpt = '';
    quantityVis = '';
    if ~isstruct(parent) || ~isscalar(parent)
        return
    end

    if isfield(parent, 'propOpt') && isstruct(parent.propOpt)
        if isfield(parent.propOpt, 'quantityOpt')
            quantityOpt = scalarText(parent.propOpt.quantityOpt);
        end
        if isfield(parent.propOpt, 'quantityVis')
            quantityVis = scalarText(parent.propOpt.quantityVis);
        end
    end

    if isempty(quantityOpt) && isfield(parent, 'quantityOpt')
        quantityOpt = scalarText(parent.quantityOpt);
    end
    if isempty(quantityVis) && isfield(parent, 'quantityVis')
        quantityVis = scalarText(parent.quantityVis);
    end

end

function value = scalarText(value)

    if isstring(value) && isscalar(value)
        value = char(value);
    elseif ~ischar(value)
        value = '';
    end

end
