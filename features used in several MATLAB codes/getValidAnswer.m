function user_choice = getValidAnswer(question, title, options, default_choice)
% adaptive window which ask the user which option want to be selected
% INPUT:        question : text of the question
%               title : name of the window. You can leave blank as ''
%               options : list of the possible options to be select (NOTE: if options contains 2 strings like "yes" OR "y" OR "1" and "no" OR "n" OR "0" ==> outcomes will be just 0 or 1 (logical))
%               default_choice : by default the option is first. Just click Enter keyboard button instead of point with the mouse.
% OUTPUT:       user_choice : give the idx of the choosen option (if option 2 ==> user_choice = 2)
%
% NOTE: the script is perfectly working but there are some aesthetic issues.

    
    % persistent allow to store a number sequence (for example if there are more than 9 options, it is
    % necessary to store two/three/etc digits when the function is called
    persistent numericInput

    % Manage the default option. If not specified, then first option is default
    if nargin < 4 || isempty(default_choice)
        default_choice = 1; 
    end
    if ~isnumeric(default_choice) || default_choice < 1 || default_choice > numel(options) 
        error('Invalid default choice!.');
    end
    % Normalize options to strings for comparison
    try
        optionStrs = cellfun(@(x) lower(string(x)), options, 'UniformOutput', false);
    catch
        error('Options must be either strings or scalar numeric values.');
    end
    % the size depends on the fontsize too.
    FontsizeQuestion= 14;
    FontsizeOptions = 12;

    % Default dialog box size
    button_height = 40; spacing = 15; spacingBorders=20;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% PREPARE THE SIZE OF THE QUESTION DIALOG %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Check the longest string in the question and how many rows
    [lines, num_lines_question, max_question_length] = splitLines(question);
    % Compute results
    widthQuestion  = max_question_length*FontsizeQuestion*0.9;    
    heightQuestion = (num_lines_question*FontsizeQuestion)*1.2;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% PREPARE THE SIZE OF THE OPTION DIALOG %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % First, need to check how many options rows and measure the length of each string line.
    % In case of options different from Yes/No, there may be options containing \n, therefore, check the length better

    % Check if it's a yes/no dialog
    yesStrings = ["yes", "y", "1","true"];
    noStrings = ["no", "n", "0","false"];    
    % if options is just Yes and No, then simple dialog box
    flagYesNo=zeros(1,2);
    if length(options) == 2        
        for i=1:2
            singleOption=optionStrs{i};
            if any(ismember(singleOption,yesStrings))
                flagYesNo(i)=1;
                continue
            else            
                flagYesNo(i)=any(ismember(singleOption,noStrings));
                continue
            end
        end
    end
    if all(flagYesNo)
        flagYesNo=1;
        max_option_length = 3; % Yes = 3 chars, longer than No = 2 chars
        num_lines_options = 1; % for more compact visual, just put the two options in a line instead of multiple rows
    else
        flagYesNo=0;
    end
    if ~flagYesNo
        num_lines_options = length(options);
        num_lines_options_split = 0;
        lengthRow=[];
        for i=1:length(options)
            splittedCell = strsplit(options{i},'\n');
            num_lines_options_split = num_lines_options_split + length(splittedCell);
            % for now, each button has the size for two rows for a single option
            if num_lines_options_split == 2
                num_lines_options_split = 1;
            end
            for j=1:length(splittedCell)
                lengthRow(i,j)= cellfun(@length, splittedCell(j)); %#ok<AGROW>
            end
        end
        max_option_length = max(max(lengthRow));
    end
    
    % calc the definitive option dialog size
    
    if flagYesNo
        widthOption  =   2*button_height + spacing;
        heightOption =   button_height;
    else
        % width of the longest Option string + button size + space between string and button
        widthOption  =   (FontsizeOptions*max_option_length)+ button_height + spacing;
        % height of entire option section
        heightOption =   (num_lines_options)*max(button_height,FontsizeOptions) + spacing*(num_lines_options-1); 
    end
    % check what is the longest width between question and option sections,
    % considering space for RIGHT/LEFT borders
    maxWidth = max(widthQuestion, widthOption);

    % TOT HEIGHT: UP/BOTTOM SPACING BORDERS + questionDialogSize + spacing
    % between question and option dialogs + optionDialogSize
    tot_height = heightQuestion + heightOption + 2*spacingBorders + spacing;
    % TOT WIDTH: LEFT/RIGHT SPACING BORDERS + biggest size between option and question dialogs
    tot_width = maxWidth+2*spacingBorders;

    % Locate the dialog box in the center
    screenSize = get(0, 'ScreenSize');
    center_screen_width = screenSize(3)/2;
    center_screen_height = screenSize(4)/2;
    dialog_x = (center_screen_width - tot_width/2);
    dialog_y = (center_screen_height - tot_height/2);
        
    % Open dialog box and associate the buttons and close button
    dialog_fig = figure('Name', title, 'NumberTitle', 'off', 'MenuBar', 'none', ...
        'ToolBar', 'none', 'Resize', 'off', 'Position', [dialog_x, dialog_y, tot_width, tot_height], ...
        'KeyPressFcn', @keyPressCallback,...
        'CloseRequestFcn',@closeRequestCallback);
  
    figPos = dialog_fig.Position;
    % store the user choice
    user_choice = 0;
    % create object for each button
    button_handles = gobjects(1, numel(options));
    if flagYesNo
        % fixed in y, moving in x
        button_start_y = 15;
        opts = {'Yes','No'};
        for i=1:2
         % Name button = first char of the given option ( 1) bla bla ==> 1, Yes ==> Y
            button_handles(i)= uicontrol('Style', 'pushbutton',...
                'Position', [tot_width/3*i-10, button_start_y, 50, 30], ...
                'String', opts{i}, 'FontSize', FontsizeOptions,...
                'Callback', @(src, event) buttonCallback(i));
        end
   else
        % pattern to find in the options (especially those having like (<number>)
        % ^expression indicate to check at the beginning of the input text
        pattern = {'^\(\d+\)\s', ...        % (<number>)
            '^\d+\)\s', ...                 % <number>)
            '^\s\(\d+\)\s', ...             % <whiteSpace>(<number>)
            '^\s\d+\)\s'};                  % <whiteSpace><number>)
        % create buttons and texts from the bottom        
        fromLeft_button=spacingBorders;
        fromLeft_textOption=fromLeft_button+button_height+spacing;        

        for i = num_lines_options:-1:1
            % find the pattern           
            [startIdx,endIdx]=regexp(options{num_lines_options-i+1}, pattern);
            % in case the options does not contain any pattern, just show 1 or 2 etc.
            if all(cellfun(@isempty, startIdx))
                icon= num2str(num_lines_options-i+1);
                text= options{num_lines_options-i+1};
            else
            % in case there is a pattern, take the pattern to show as icon and display the text option
            % identify the index where pattern start and finish. Then start the number inside the pattern
                startIdx= startIdx{find(~cellfun(@isempty, startIdx), 1)};
                endIdx= endIdx{find(~cellfun(@isempty, endIdx), 1)};
                patternNumber = '\d';
                [startIdxNum,endIdxNum] = regexp(options{num_lines_options-i+1}(startIdx:endIdx), patternNumber);
                icon=str2double(options{num_lines_options-i+1}(startIdxNum:endIdxNum));
                text= options{num_lines_options-i+1}(endIdx+1:end);
            end
            % Calc button vertical position 
            fromBottom = spacingBorders + (button_height+spacing)*(i-1);
            
            % Name button = first char of the given option ( 1) bla bla ==> 1              % cubic button
            button_handles(i)=uicontrol('Style', 'pushbutton',...
                'Position', [fromLeft_button, fromBottom, button_height, button_height], ...
                'String', icon, 'FontSize', FontsizeOptions,...
                'Callback', @(src, event) buttonCallback(num_lines_options-i+1));
            % add 1.1 margin in the width
            textWidth=length(text)*FontsizeOptions*1.1;
            textHeight=button_height;
            % insert label of each button with the entire text option
            nx = fromLeft_textOption / figPos(3);
            ny = fromBottom / figPos(4);
            nw = textWidth / figPos(3);
            nh = textHeight / figPos(4);
            % NOTE: annotation position is always normalized
            annotation('textbox','Units','normalized','Position', [nx, ny, nw, nh], 'String', text,'FontSize', FontsizeOptions, ...
                'HorizontalAlignment', 'left','VerticalAlignment', 'middle','EdgeColor', 'none','FitBoxToText', 'on');
        end
        % flipped because the for cycle before is inverted
        button_handles=flip(button_handles);
    end
    
    % PREPARE THE QUESTION DIALOG
    fromLeft = spacingBorders;
    fromBottom = tot_height -(spacingBorders+heightQuestion);
    textWidth = widthQuestion;
    textHeight = heightQuestion;
    % Convert absolute pixel coordinates -> normalized coordinates   
    nx = fromLeft / figPos(3);
    ny = fromBottom / figPos(4);
    nw = textWidth / figPos(3);
    nh = textHeight / figPos(4);
    % NOTE: annotation position is always normalized
    annotation('textbox','Units', 'normalized','Position', [nx, ny, nw, nh*1.4], 'String', lines, 'FontWeight','bold','interpreter','none','FontSize', FontsizeQuestion, ...
        'HorizontalAlignment', 'center','VerticalAlignment', 'middle', 'Color', 'red','EdgeColor', 'none');
    % Make bold the default button
    set(button_handles(default_choice), 'FontWeight', 'bold');

    % Wait user choice selection before continuing
    uiwait(dialog_fig);
    % Check if the user closed the window without making a choice
    if isnan(user_choice)
        error('Closed window. Stopped the process.')
    end

    % create the Button Callback function
    function buttonCallback(choice)
        if flagYesNo
            if choice == 2
                user_choice = false;
            else
                user_choice = true;
            end
        else
            user_choice = choice;
        end
        uiresume(dialog_fig);
        delete(dialog_fig);
    end    

    % create the keyboard buttons Callback function. It allows to select the possible option by clicking the
    % specific related button on the keyboard
    % i.e. if the desired option is 2, then click 2 on keyboard   
    function keyPressCallback(~, event)
        % init. The first time will be empty
        if isempty(numericInput)
            numericInput = '';
        end
        % if escape\Esc is clicked, close and stop
        if strcmp(event.Key, 'escape')
            closeRequestCallback
        % click by return/enter to end the selection.
        elseif strcmp(event.Key, 'return') || strcmp(event.Key, 'enter')
            if ~isempty(numericInput)
                % if there is a sequence, convert it to a number
                numPressed = str2double(numericInput);
                % reset to restart next time
                numericInput = '';
                if numPressed >= 0 && numPressed <= numel(options)
                    buttonCallback(numPressed);
                    clc
                    fprintf('\nDefinitive selection: %s\n',string(options{numPressed})) 
                end
            else
                % In case the sequence number is empty, select default option
                buttonCallback(default_choice);
                clc
                fprintf('\nDefinitive selection: %s\n',string(options{default_choice}))                
            end       
        elseif ismember(event.Key, {'1','2','3','4','5','6','7','8','9','0'})
            % check if the clicked button is a number button. If so, add to the sequence number
            numericInput = strcat(numericInput, event.Key);
            % if the sequence number is a number higher than the number of possible options
            if str2double(numericInput) > numel(options)
                % Reset to the last pressed number
                numericInput = event.Key; 
            end
        elseif strcmp(event.Key, 'backspace') && ~isempty(numericInput)
            % Remove the last number by clicking Backspace button
            numericInput = numericInput(1:end-1);
        elseif strcmpi(event.Key, 'y') && flagYesNo
            % if click y ==> then yes. Note: it should be guaranted that the first option is always yes
            clc
            fprintf('\nDefinitive selection: Yes\n')
            buttonCallback(1);
        elseif strcmpi(event.Key, 'n') && flagYesNo
            % if click n ==> then no
            clc
            fprintf('\nDefinitive selection: No\n')            
            buttonCallback(2);
        else
            % Reset the sequence number with any else button
            numericInput = '';
        end
    end

    function closeRequestCallback(~, ~)
        % Handle the window being closed without a selection
        uiresume(dialog_fig);
        delete(dialog_fig);
        user_choice = NaN;        
    end
end



% Robust splitting of 'question' into individual lines (handles cells, string arrays, char arrays,
% literal '\n' sequences and actual newline characters).
function [lines, num_lines_question, max_question_length] = splitLines(question)

    lines = string.empty(0,1);  % will collect all lines as a column string array

    if iscell(question)
        for i = 1:numel(question)
            elem = question{i};
            sarr = string(elem);   % convert char / string / string-array -> string array
            for k = 1:numel(sarr)
                % split on literal backslash-n OR real newline(s) (handle CRLF too)
                parts = regexp(char(sarr(k)), '\\n|\r\n|\n', 'split');
                % convert parts to string array and append
                lines = [lines; string(parts(:))];
            end
        end

    else
        % question is not a cell (could be char, string, numeric)
        sarr = string(question);    % convert to string array
        for k = 1:numel(sarr)
            parts = regexp(char(sarr(k)), '\\n|\r\n|\n', 'split');
            lines = [lines; string(parts(:))];
        end
    end

    % remove possible empty lines (optional)
    lines = lines(strlength(strtrim(lines)) > 0);

    % final metrics
    num_lines_question = numel(lines);
    if num_lines_question == 0
        max_question_length = 0;
    else
        max_question_length = max(strlength(lines));
    end
end