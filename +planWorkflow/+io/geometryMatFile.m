function filePath = geometryMatFile(runConfig,mode)
% geometryMatFile Resolve the MAT geometry file for a workflow mode.

matRad_cfg = MatRad_Config.instance();
if isfield(runConfig,'patientDataPath') && ~isempty(runConfig.patientDataPath)
    patientDataPath = runConfig.patientDataPath;
else
    patientDataPath = fullfile(matRad_cfg.primaryUserFolder,'patients');
end

patientRoot = fullfile(patientDataPath,runConfig.description);
switch string(mode)
    case "optimization"
        caseID = runConfig.caseID;
    case "sampling"
        caseID = runConfig.sampling_caseID;
    otherwise
        error('planWorkflow:io:InvalidGeometryMode', ...
            'Unknown geometry mode "%s".',char(mode));
end

filePath = fullfile(patientRoot,[char(caseID) '.mat']);

end
