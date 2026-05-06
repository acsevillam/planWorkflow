classdef PanelScroller
    % PanelScroller Shared normalized-panel scroll behavior.

    methods (Static)
        function scrollSlider = createSlider(parentPanel)
            sliderTag = '';
            if ishandle(parentPanel)
                try
                    panelTag = get(parentPanel,'Tag');
                    if ~isempty(panelTag)
                        sliderTag = [char(panelTag) 'ScrollSlider'];
                    end
                catch
                end
            end

            scrollSlider = uicontrol('Parent',parentPanel, ...
                'Style','slider','Units','normalized', ...
                'Position',[0.972 0.02 0.020 0.94], ...
                'Min',0,'Max',1,'Value',1, ...
                'Visible','off', ...
                'Tag',sliderTag, ...
                'Callback',@(src,~) ...
                planWorkflow.gui.PanelScroller.scroll(src));
            if ishandle(parentPanel)
                setappdata(parentPanel, ...
                    'planWorkflowPanelScrollSlider',scrollSlider);
            end
        end

        function scrollSlider = panelSlider(panel)
            scrollSlider = [];
            if ~ishandle(panel) || ...
                    ~isappdata(panel,'planWorkflowPanelScrollSlider')
                return;
            end
            scrollSlider = getappdata(panel,'planWorkflowPanelScrollSlider');
            if ~ishandle(scrollSlider)
                scrollSlider = [];
            end
        end

        function configure(scrollSlider,controls,contentBottomY,preserveOffset)
            if ~ishandle(scrollSlider)
                return;
            end

            if nargin < 4
                preserveOffset = false;
            end
            previousOffset = 0;
            if preserveOffset
                previousOffset = ...
                    planWorkflow.gui.PanelScroller.currentOffset(scrollSlider);
            end
            controls = controls(:);
            controls = controls(ishandle(controls));
            bottomMargin = 0.035;
            maxOffset = max(0,bottomMargin - double(contentBottomY));
            state = struct();
            state.maxOffset = maxOffset;
            state.controls = controls;
            state.positions = ...
                planWorkflow.gui.PanelScroller.controlPositions(controls);
            set(scrollSlider,'UserData',state);

            if maxOffset > eps
                smallStep = min(1,0.08 / maxOffset);
                largeStep = min(1,0.32 / maxOffset);
                sliderValue = ...
                    planWorkflow.gui.PanelScroller.sliderValueForOffset( ...
                    maxOffset,previousOffset);
                set(scrollSlider, ...
                    'Visible','on', ...
                    'Min',0,'Max',maxOffset,'Value',sliderValue, ...
                    'SliderStep',[smallStep largeStep]);
            else
                set(scrollSlider, ...
                    'Visible','off','Min',0,'Max',1,'Value',0);
            end
            planWorkflow.gui.PanelScroller.refresh(scrollSlider);
        end

        function refresh(scrollSlider)
            if ~ishandle(scrollSlider)
                return;
            end

            state = get(scrollSlider,'UserData');
            if ~isstruct(state) || ~isfield(state,'maxOffset')
                return;
            end

            if state.maxOffset > eps
                set(scrollSlider,'Visible','on');
            else
                set(scrollSlider,'Visible','off');
            end
            planWorkflow.gui.PanelScroller.bringToFront(scrollSlider);
            planWorkflow.gui.PanelScroller.scroll(scrollSlider);
        end

        function scrollByWheel(scrollSlider,scrollCount)
            if ~ishandle(scrollSlider)
                return;
            end

            state = get(scrollSlider,'UserData');
            if ~isstruct(state) || ~isfield(state,'maxOffset') || ...
                    state.maxOffset <= eps
                return;
            end

            sliderValue = ...
                planWorkflow.gui.PanelScroller.wheelSliderValue( ...
                state.maxOffset,get(scrollSlider,'Value'),scrollCount);
            set(scrollSlider,'Value',sliderValue);
            planWorkflow.gui.PanelScroller.scroll(scrollSlider);
        end

        function scrollSlider = selectedScrollableSlider(container)
            scrollSlider = [];
            if ~ishandle(container)
                return;
            end

            childTabGroups = findall(container,'Type','uitabgroup');
            for i = 1:numel(childTabGroups)
                try
                    if ~isequal(get(childTabGroups(i),'Parent'),container)
                        continue;
                    end
                    selectedTab = get(childTabGroups(i),'SelectedTab');
                    scrollSlider = ...
                        planWorkflow.gui.PanelScroller.selectedScrollableSlider( ...
                        selectedTab);
                    if ~isempty(scrollSlider)
                        return;
                    end
                catch
                end
            end

            panels = findall(container,'Type','uipanel');
            for i = 1:numel(panels)
                try
                    if ~isequal(get(panels(i),'Parent'),container)
                        continue;
                    end
                catch
                    continue;
                end
                scrollSlider = ...
                    planWorkflow.gui.PanelScroller.panelSlider(panels(i));
                if ~isempty(scrollSlider)
                    return;
                end
            end
        end

        function bringToFront(scrollSlider)
            if ~ishandle(scrollSlider)
                return;
            end

            try
                uistack(scrollSlider,'top');
            catch
            end
        end

        function positions = controlPositions(handles)
            positions = zeros(numel(handles),4);
            for i = 1:numel(handles)
                if ishandle(handles(i))
                    positions(i,:) = get(handles(i),'Position');
                end
            end
        end

        function scroll(scrollSlider)
            if ~ishandle(scrollSlider)
                return;
            end

            state = get(scrollSlider,'UserData');
            if ~isstruct(state) || ~isfield(state,'maxOffset') || ...
                    ~isfield(state,'controls') || ~isfield(state,'positions')
                return;
            end
            offset = planWorkflow.gui.PanelScroller.scrollOffset( ...
                state.maxOffset,get(scrollSlider,'Value'));

            planWorkflow.gui.PanelScroller.applyScroll( ...
                state.controls,state.positions,offset);
        end

        function applyScroll(handles,basePositions,offset)
            for i = 1:numel(handles)
                if ~ishandle(handles(i))
                    continue;
                end
                position = basePositions(i,:);
                position(2) = position(2) + offset;
                set(handles(i),'Position',position);
            end
        end

        function offset = scrollOffset(maxOffset,sliderValue)
            maxOffset = max(0,double(maxOffset));
            if maxOffset <= eps
                offset = 0;
                return;
            end

            sliderValue = double(sliderValue);
            if ~isfinite(sliderValue)
                sliderValue = maxOffset;
            end
            sliderValue = max(0,min(maxOffset,sliderValue));
            offset = maxOffset - sliderValue;
        end

        function offset = currentOffset(scrollSlider)
            offset = 0;
            if ~ishandle(scrollSlider)
                return;
            end

            state = get(scrollSlider,'UserData');
            if ~isstruct(state) || ~isfield(state,'maxOffset')
                return;
            end
            offset = planWorkflow.gui.PanelScroller.scrollOffset( ...
                state.maxOffset,get(scrollSlider,'Value'));
        end

        function sliderValue = sliderValueForOffset(maxOffset,offset)
            maxOffset = max(0,double(maxOffset));
            if maxOffset <= eps
                sliderValue = 0;
                return;
            end

            offset = double(offset);
            if ~isfinite(offset)
                offset = 0;
            end
            offset = max(0,min(maxOffset,offset));
            sliderValue = maxOffset - offset;
        end

        function sliderValue = wheelSliderValue(maxOffset,currentValue, ...
                scrollCount)
            maxOffset = max(0,double(maxOffset));
            if maxOffset <= eps
                sliderValue = 0;
                return;
            end

            currentValue = double(currentValue);
            if ~isfinite(currentValue)
                currentValue = maxOffset;
            end
            currentValue = max(0,min(maxOffset,currentValue));

            scrollCount = double(scrollCount);
            if ~isfinite(scrollCount)
                scrollCount = 0;
            end
            scrollUnit = min(0.12,max(0.04,maxOffset / 8));
            sliderValue = currentValue - scrollCount * scrollUnit;
            sliderValue = max(0,min(maxOffset,sliderValue));
        end
    end
end
