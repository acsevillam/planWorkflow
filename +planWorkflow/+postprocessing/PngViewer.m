classdef PngViewer
    % PngViewer Opens generated PNG files in MATLAB figures.

    methods (Static)
        function fig = open(filePath,options)
            if nargin < 2
                options = struct();
            end
            filePath = char(filePath);
            if ~isfile(filePath)
                error('planWorkflow:postprocessing:PngViewer:MissingFile', ...
                    'PNG file does not exist: %s',filePath);
            end
            [~,name,ext] = fileparts(filePath);
            if ~strcmpi(ext,'.png')
                error('planWorkflow:postprocessing:PngViewer:InvalidFile', ...
                    'Expected a PNG file: %s',filePath);
            end

            visible = planWorkflow.postprocessing.PngViewer.optionValue( ...
                options,'Visible','on');
            [imageData,colorMap,alpha] = imread(filePath);
            if ~isempty(colorMap)
                imageData = ind2rgb(imageData,colorMap);
            end

            fig = figure('Name',strrep(name,'_',' '), ...
                'NumberTitle','off','Visible',visible);
            axisHandle = axes('Parent',fig);
            imageHandle = image(axisHandle,imageData);
            if ~isempty(alpha)
                set(imageHandle,'AlphaData',alpha);
            end
            axis(axisHandle,'image');
            axis(axisHandle,'off');
        end
    end

    methods (Static, Access = private)
        function value = optionValue(options,field,defaultValue)
            value = defaultValue;
            if isstruct(options) && isfield(options,field) && ...
                    ~isempty(options.(field))
                value = options.(field);
            end
        end
    end
end
