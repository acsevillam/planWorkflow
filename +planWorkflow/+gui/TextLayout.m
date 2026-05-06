classdef TextLayout
    % TextLayout Shared GUI text layout helpers.

    methods (Static)
        function fontSize = helpTextFontSize()
            fontSize = 7;
        end

        function width = helpTextWidth()
            width = 0.27;
        end

        function wrapColumn = parameterHelpTextWrapColumn()
            wrapColumn = 48;
        end

        function wrapColumn = wideHelpTextWrapColumn()
            wrapColumn = 112;
        end

        function wrapColumn = objectiveHelpTextWrapColumn()
            wrapColumn = 180;
        end

        function height = helpTextHeightForDisplay(text,wrapColumn)
            if nargin < 2
                wrapColumn = 84;
            end
            lineCount = planWorkflow.gui.TextLayout.helpTextLineCount( ...
                text,wrapColumn);
            if lineCount == 0
                height = 0.026;
            else
                height = max(0.026,0.022 * lineCount);
            end
        end

        function height = wideHelpTextHeightForDisplay(text)
            lineCount = planWorkflow.gui.TextLayout.helpTextLineCount( ...
                text,planWorkflow.gui.TextLayout.objectiveHelpTextWrapColumn());
            if lineCount == 0
                height = 0.042;
            else
                height = max(0.042,0.031 * lineCount);
            end
        end

        function text = helpTextForDisplay(text,wrapColumn)
            if nargin < 2
                wrapColumn = 84;
            end
            text = char(text);
            if isempty(strtrim(text))
                text = '';
                return;
            end

            paragraphs = regexp(strtrim(text),'\r\n|\n|\r','split');
            lines = {};
            for paragraphIx = 1:numel(paragraphs)
                words = regexp(strtrim(paragraphs{paragraphIx}), ...
                    '\s+','split');
                currentLine = '';
                for wordIx = 1:numel(words)
                    word = words{wordIx};
                    if isempty(currentLine)
                        currentLine = word;
                    elseif numel(currentLine) + 1 + numel(word) <= ...
                            wrapColumn
                        currentLine = [currentLine ' ' word]; %#ok<AGROW>
                    else
                        lines{end + 1} = currentLine; %#ok<AGROW>
                        currentLine = word;
                    end
                end
                if ~isempty(currentLine)
                    lines{end + 1} = currentLine; %#ok<AGROW>
                end
                if paragraphIx < numel(paragraphs)
                    lines{end + 1} = ''; %#ok<AGROW>
                end
            end
            text = strjoin(lines,sprintf('\n'));
        end

        function lineCount = helpTextLineCount(text,wrapColumn)
            if nargin < 2
                wrapColumn = 84;
            end
            text = planWorkflow.gui.TextLayout.helpTextForDisplay( ...
                text,wrapColumn);
            if isempty(text)
                lineCount = 0;
            else
                lineCount = numel(regexp(text,'\n','split'));
            end
        end
    end
end
