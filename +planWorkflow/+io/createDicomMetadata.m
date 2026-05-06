function metadata = createDicomMetadata(runConfig,mode)
% createDicomMetadata Build metadata for matRad DICOM geometry import.
%
% call
%   metadata = planWorkflow.io.createDicomMetadata(runConfig,mode)
%
% input
%   runConfig: planWorkflow run configuration
%   mode:      geometry mode, either 'optimization' or 'sampling'
%
% output
%   metadata: scalar struct passed to matRad_importMultipleDicomCt

if nargin < 2 || isempty(mode)
    mode = 'optimization';
end
mode = char(mode);

metadata = struct();
if isfield(runConfig,'resolution')
    metadata.resolution = runConfig.resolution;
end

switch mode
    case 'optimization'
        metadata = mergeMetadata(metadata,getMetadataField(runConfig,'dicomMetadata'));
    case 'sampling'
        samplingMetadata = getMetadataField(runConfig,'sampling_dicomMetadata');
        if isempty(fieldnames(samplingMetadata))
            samplingMetadata = getOptimizationMetadataForSampling(runConfig);
        end
        metadata = mergeMetadata(metadata,samplingMetadata);
    otherwise
        error('planWorkflow:io:createDicomMetadata:InvalidMode', ...
            'DICOM metadata mode must be ''optimization'' or ''sampling''.');
end

if ~isfield(metadata,'resolution') || isempty(metadata.resolution)
    error('planWorkflow:io:createDicomMetadata:MissingResolution', ...
        'DICOM import metadata requires a non-empty resolution field.');
end
end

function metadata = getMetadataField(runConfig,fieldName)
metadata = struct();
if isfield(runConfig,fieldName) && ~isempty(runConfig.(fieldName))
    metadata = runConfig.(fieldName);
end
if ~isstruct(metadata) || ~isscalar(metadata)
    error('planWorkflow:io:createDicomMetadata:InvalidMetadata', ...
        '%s must be a scalar struct.',fieldName);
end
end

function metadata = getOptimizationMetadataForSampling(runConfig)
metadata = struct();
if ~isfield(runConfig,'dicomMetadata') || isempty(runConfig.dicomMetadata)
    return;
end

if isfield(runConfig,'caseID') && isfield(runConfig,'sampling_caseID') && ...
        ~strcmp(char(runConfig.caseID),char(runConfig.sampling_caseID))
    return;
end

metadata = getMetadataField(runConfig,'dicomMetadata');
end

function merged = mergeMetadata(base,patch)
merged = base;
fields = fieldnames(patch);
for i = 1:numel(fields)
    merged.(fields{i}) = patch.(fields{i});
end
end
