function selectedOptions = selectOptionsDialog(question,multipleSelection,varargin)
% INPUT : 
%           - question : text printed on the figure
%           - varargin : cell or string array containing the list of which the user has to select.
%                        NOTE : more array can be provided for multiple but separate selections
% OUTPUT :  
%           - selectedOptions : cell array containing the selected option of the list
    % Create a modal UI figure depending on the lenght of varargin
    nOptionTypes=length(varargin);
    if nOptionTypes < 1
        error('At least one option type must be provided.');
    end
    baseWidthInnerWindow=260;
    EntireWidthWindow= baseWidthInnerWindow*nOptionTypes+(nOptionTypes+1)*20; % 20 (left border space) + 260 (list 1) + 20 (right border space OR space between lists) + 260 (eventually list 2) + 20 (right border space OR space between lists)
    fig = uifigure('Name',question, 'Position', [100 100 EntireWidthWindow 400], ...
                   'WindowStyle', 'modal');
    % --- Create listboxes ---
    lb = gobjects(nOptionTypes, 1);
    for i=1:nOptionTypes
        startInnerWindow=20+(i-1)*280;
        lb(i) = uilistbox(fig, ...
            'Items', varargin{i}, ...              % displayed text
            'ItemsData', 1:numel(varargin{i}), ... % underlying numeric value
            'FontSize',15, ...
            'Position', [startInnerWindow 50 260 330]);
        % multiselect ON only when allowed
        if ~multipleSelection
            lb(i).Multiselect = 'off';
            % override selection callback to enforce only one item
            lb(i).ValueChangedFcn = @(src, event) enforceSingle(src);
        else
            lb(i).Multiselect = 'on';
        end
    end
    % Create OK button
    startButton=(EntireWidthWindow/2)-50; % center entire window - half width of the button
    uibutton(fig, 'Text', 'OK', ...
        'Position', [startButton 10 100 30], ...
        'ButtonPushedFcn', @(btn,event) uiresume(fig));
      
    uiwait(fig);
    selectedOptions=cell(nOptionTypes,1);
    for i=1:nOptionTypes
        selectedOptions{i} = lb(i).Value;
    end
    close(fig);
end


% --- Helper function to enforce single choice ---
function enforceSingle(listHandle)
    % Make sure the value is always stored as a single item
    if iscell(listHandle.Value)
        % Keep only last clicked item
        listHandle.Value = listHandle.Value{end};
    end
end