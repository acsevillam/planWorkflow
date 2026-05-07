function validateDicomImportFolder(dicomPath)
% validateDicomImportFolder Checks DICOM input before matRad import.

if isstring(dicomPath)
    dicomPath = char(dicomPath);
end

if ~isfolder(dicomPath)
    error('planWorkflow:io:MissingDicomFolder', ...
        'DICOM import folder not found: %s',dicomPath);
end

files = listFiles(dicomPath);
if isempty(files)
    error('planWorkflow:io:EmptyDicomFolder', ...
        'DICOM import folder is empty: %s',dicomPath);
end

lfsPointerFiles = {};
for i = 1:numel(files)
    if isGitLfsPointerFile(files{i})
        lfsPointerFiles{end + 1} = files{i}; %#ok<AGROW>
    end
end

if ~isempty(lfsPointerFiles)
    exampleFiles = lfsPointerFiles(1:min(3,numel(lfsPointerFiles)));
    error('planWorkflow:io:DicomFolderContainsGitLfsPointers', ...
        ['DICOM import folder contains Git LFS pointer files instead ' ...
         'of DICOM data: %s. Run git lfs pull in the matRad checkout ' ...
         'or replace the pointer files with real DICOM files.'], ...
        strjoin(exampleFiles,', '));
end

end

function files = listFiles(folder)
files = {};
entries = dir(folder);
for i = 1:numel(entries)
    entry = entries(i);
    if strcmp(entry.name,'.') || strcmp(entry.name,'..')
        continue;
    end

    path = fullfile(folder,entry.name);
    if entry.isdir
        files = [files,listFiles(path)]; %#ok<AGROW>
    else
        files{end + 1} = path; %#ok<AGROW>
    end
end
end

function tf = isGitLfsPointerFile(filePath)
tf = false;
fid = fopen(filePath,'r');
if fid < 0
    return;
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
header = fread(fid,256,'*char')';
tf = startsWith(header,'version https://git-lfs.github.com/spec/v1');
end
