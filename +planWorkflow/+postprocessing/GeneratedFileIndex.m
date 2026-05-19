classdef GeneratedFileIndex
    % GeneratedFileIndex Lists files produced by postprocessing runs.

    methods (Static)
        function entries = pngEntries(outputDir)
            entries = planWorkflow.postprocessing.GeneratedFileIndex.fileEntries( ...
                outputDir,'*.png','figure');
        end

        function entries = csvEntries(outputDir)
            entries = planWorkflow.postprocessing.GeneratedFileIndex.fileEntries( ...
                outputDir,'*.csv','table');
        end

        function rows = tableRows(entries)
            rows = cell(numel(entries),3);
            for i = 1:numel(entries)
                [~,name,ext] = fileparts(entries(i).filePath);
                rows(i,:) = {entries(i).label,[name ext],'Open'};
            end
        end
    end

    methods (Static, Access = private)
        function entries = fileEntries(outputDir,pattern,kind)
            emptyEntry = struct('id','','label','','filePath','','kind','');
            entries = emptyEntry([]);
            if nargin < 1 || isempty(outputDir) || ~isfolder(outputDir)
                return;
            end

            files = dir(fullfile(outputDir,pattern));
            if isempty(files)
                return;
            end
            [~,order] = sort({files.name});
            files = files(order);
            entries = repmat(emptyEntry,1,numel(files));
            for i = 1:numel(files)
                [~,name,~] = fileparts(files(i).name);
                entries(i) = struct( ...
                    'id',name, ...
                    'label',planWorkflow.postprocessing.GeneratedFileIndex.labelFromName(name), ...
                    'filePath',fullfile(files(i).folder,files(i).name), ...
                    'kind',kind);
            end
        end

        function label = labelFromName(name)
            label = strrep(char(name),'_',' ');
        end
    end
end
