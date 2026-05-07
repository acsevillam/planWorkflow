function [ct,cst] = loadGeometry(run_config,mode)

matRad_cfg = MatRad_Config.instance();
if isfield(run_config,'patientDataPath') && ~isempty(run_config.patientDataPath)
    patientDataPath = run_config.patientDataPath;
else
    patientDataPath = fullfile(matRad_cfg.primaryUserFolder,'patients');
end
patientRoot = fullfile(patientDataPath,run_config.description);

if(mode=="optimization")
    caseID = run_config.caseID;
    AcquisitionType = run_config.AcquisitionType;
end

if(mode=="sampling")
    caseID = run_config.sampling_caseID;
    AcquisitionType = run_config.sampling_AcquisitionType;
end

switch AcquisitionType
    case 'mat'
        % Import 3D CT
        load(planWorkflow.io.geometryMatFile(run_config,mode),'ct','cst');

    case 'dicom'
        % Import 4D CT
        metadata = planWorkflow.io.createDicomMetadata(run_config,mode);
        dicomPath = fullfile(patientRoot,caseID,'dicom');
        planWorkflow.io.validateDicomImportFolder(dicomPath);
        [ct,cst] = matRad_importMultipleDicomCt(dicomPath,metadata);
        clear 'metadata';

end

end
