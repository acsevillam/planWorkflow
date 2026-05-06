classdef EditorChrome
    % EditorChrome Top-level editor labels, layout and button helpers.

    methods (Static)
        function label = exportButtonLabel()
            label = 'Export';
        end

        function labels = actionButtonLabels()
            labels = struct('resume','Resume','settings','Settings');
        end

        function button = createActionTextButton(parent,position,label,callback)
            if nargin < 4
                callback = @(src,event) [];
            end
            button = uicontrol('Parent',parent,'Style','pushbutton', ...
                'String',label,'Units','normalized','Position',position, ...
                'TooltipString',label, ...
                'Callback',callback);
        end

        function value = enableText(enabled)
            if enabled
                value = 'on';
            else
                value = 'off';
            end
        end

        function color = exportStatusColor(severity)
            switch char(severity)
                case 'warning'
                    color = [0.60 0.35 0.00];
                case 'error'
                    color = [0.75 0.00 0.00];
                otherwise
                    color = [0.20 0.20 0.20];
            end
        end

        function layout = footerLayout()
            layout = struct();
            layout.progressLeft = 0.02;
            layout.progressWidth = 0.46;
            layout.statusText = [layout.progressLeft 0.155 ...
                layout.progressWidth 0.03];
            layout.progressBar = [layout.progressLeft 0.115 ...
                layout.progressWidth 0.03];
            layout.progressDetails = [layout.progressLeft 0.02 ...
                layout.progressWidth 0.085];
            buttonY = 0.115;
            buttonHeight = 0.05;
            layout.exportButton = [0.50 buttonY 0.10 buttonHeight];
            layout.calculateButton = [0.62 buttonY 0.10 buttonHeight];
            layout.stopButton = [0.74 buttonY 0.10 buttonHeight];
            layout.cancelButton = [0.86 buttonY 0.11 buttonHeight];
        end

        function style = editorWindowStyle()
            style = 'normal';
        end
    end
end
