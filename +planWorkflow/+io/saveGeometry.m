function saveGeometry(runConfig,mode,ct,cst)
% saveGeometry Persist MAT geometry for a workflow mode.

acquisitionType = geometryAcquisitionType(runConfig,mode);
if ~strcmp(acquisitionType,'mat')
    return;
end

filePath = planWorkflow.io.geometryMatFile(runConfig,mode);
if isfile(filePath)
    save(filePath,'ct','cst','-append');
else
    patientRoot = fileparts(filePath);
    if ~isfolder(patientRoot)
        mkdir(patientRoot);
    end
    save(filePath,'ct','cst','-v7.3');
end

end

function acquisitionType = geometryAcquisitionType(runConfig,mode)
switch string(mode)
    case "optimization"
        acquisitionType = runConfig.AcquisitionType;
    case "sampling"
        acquisitionType = runConfig.sampling_AcquisitionType;
    otherwise
        error('planWorkflow:io:InvalidGeometryMode', ...
            'Unknown geometry mode "%s".',char(mode));
end

acquisitionType = char(acquisitionType);
end
