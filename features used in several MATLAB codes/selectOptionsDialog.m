function selectedOptions = selectOptionsDialog(question,multipleSelection,varargin)
% INPUT : 
%           - question : text printed on the figure
%           - varargin : cell or string array containing the list of which the user has to select.
%                        NOTE : more array can be provided for multiple but separate selections
%           % OPTIONAL NAME–VALUE PAIR:
%           - 'Titles' : cell array of titles to show above each listbox
% OUTPUT :  
%           - selectedOptions : cell array containing the selected option of the list

    % ---- Parse inputs ----
    % Check if the last argument is a name-value pair for Titles
    Titles = [];
    if ~isempty(varargin) && ischar(varargin{end})
        error('Titles must be passed using: ''Titles'', {title1,title2,...}');
    end
     % Detect optional 'Titles' argument
    if numel(varargin) >= 2 && ischar(varargin{end-1}) && strcmp(varargin{end-1}, 'Titles')
        Titles = varargin{end};
        varargin(end-1:end) = []; % Remove Titles arguments
    end
    % ---- Validate list inputs ----
    nOptionTypes = length(varargin);
    if nOptionTypes < 1
        error('At least one option list must be provided.');
    end

    if ~isempty(Titles) && numel(Titles) ~= nOptionTypes
        error('Number of Titles must match the number of option lists.');
    end
    % ---- Create the main modal figure ----
    baseWidthInnerWindow=260;
    % 20 (left border space) + 260 (list 1) + 20 (right border space OR space between lists) + 260 (eventually list 2) + 20 (right border space OR space between lists)
    EntireWidthWindow= baseWidthInnerWindow*nOptionTypes+(nOptionTypes+1)*20; 
    fig = uifigure('Name',question, 'Position', [100 100 EntireWidthWindow 450]);
    % --- Create listboxes ---
    lb = gobjects(nOptionTypes, 1);
    for i=1:nOptionTypes
        startInnerWindow = 20 + (i-1)*280;
        % Create label only if titles exist 
        if ~isempty(Titles)
            uilabel(fig, ...
                'Text', Titles{i}, ...
                'FontSize', 15, ...
                'HorizontalAlignment', 'center', ...
                'Position', [startInnerWindow 390 260 30]);
            listY = 50;   % lower listbox placement
        else
            listY = 50;   % same as original code
        end       
        % Create listbox
        lb(i) = uilistbox(fig, ...
            'Items', varargin{i}, ...              % displayed text
            'ItemsData', 1:numel(varargin{i}), ... % underlying numeric value
            'FontSize',15, ...
            'Position', [startInnerWindow listY 260 330]);
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