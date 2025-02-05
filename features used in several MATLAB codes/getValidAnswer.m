function user_choice = getValidAnswer(question, title, options, default_choice)
    
    % persistent allow to store a number sequence (for example if there are more than 9 options, it is
    % necessary to store two/three/etc digits when the function is called
    persistent numericInput

    % Manage the default option. If not specified, then first option is default
    if nargin < 4 || isempty(default_choice)
        default_choice = 1; 
    end
    if ~isnumeric(default_choice) || default_choice < 1 || default_choice > numel(options) || ~ismember(options{default_choice},options)
        error('Invalid default choice!.');
    end
    
    % Default dialog box size
    base_width = 450; button_height = 40; spacing = 10;
    % Check the longest string in the question and how many rows
    max_question_length = max(cellfun(@length, strsplit(question, '\n')));
    num_lines_question = length(strsplit(question, '\n'));
    
    % if options is just Yes and No, then simple dialog box
    if length(options) == 2 && any(strcmpi(options, 'yes') | strcmpi(options, 'y')) && any(strcmpi(options, 'no') | strcmpi(options, 'n'))
        flagYesNo=1;
        max_option_length = 3;
        num_lines_options = 1;
    else
    % check how many options rows. Since the options may contains \n, check the length better
        flagYesNo=0;
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
    % check what is the longest string among question and options
    max_length = max(max_question_length, max_option_length);

    % the size depends on the fontsize too.
    FontsizeQuestion= 14;
    FontsizeOptions = 12;
    % check the best height size
    sizeRowOptions                  =  num_lines_options*FontsizeOptions;
    sizeRowDistanceBetweenOptions   = (num_lines_options)* (button_height + spacing);
    sizeRowQuestion                 = num_lines_question*FontsizeQuestion;
    % Calc height based on number of options. If too small, than take the base_height.
    dialog_height = (sizeRowQuestion + sizeRowOptions + sizeRowDistanceBetweenOptions);
    dialog_width = max(base_width, FontsizeQuestion * max_length / 1.4);

    % Locate the dialog box in the center
    screenSize = get(0, 'ScreenSize');
    screen_width = screenSize(3);
    screen_height = screenSize(4);
    dialog_x = (screen_width - dialog_width) / 2;
    dialog_y = (screen_height - dialog_height) / 2;
        
    % Open dialog box and associate the buttons and close button
    dialog_fig = figure('Name', title, 'NumberTitle', 'off', 'MenuBar', 'none', ...
        'ToolBar', 'none', 'Resize', 'off', 'Position', [dialog_x, dialog_y, dialog_width, dialog_height*1.3], ...
        'WindowStyle', 'modal','KeyPressFcn', @keyPressCallback,...
        'CloseRequestFcn',@closeRequestCallback);

    % Insert the question in the dialog box
    textHeight = sizeRowQuestion*2;
    textWidth = dialog_width - 2*spacing;
    fromLeft = spacing;
    fromBottom = dialog_height*1.3 -(spacing + textHeight);
    uicontrol('Style', 'text', 'Position', [fromLeft, fromBottom, textWidth , textHeight], ...
        'String', question, 'FontSize', FontsizeQuestion, 'HorizontalAlignment', 'center','ForegroundColor', 'red');

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
                'Position', [dialog_width/3*i-10, button_start_y, 50, 30], ...
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
        spacing = 15;
        % create buttons and texts from the bottom
        button_start_y = spacing;    
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
            button_position_y = button_start_y + (button_height+spacing)*(i-1);
            
            % Name button = first char of the given option ( 1) bla bla ==> 1              % cubic button
            button_handles(i)=uicontrol('Style', 'pushbutton',...
                'Position', [spacing, button_position_y, button_height, button_height], ...
                'String', icon, 'FontSize', FontsizeOptions,...
                'Callback', @(src, event) buttonCallback(num_lines_options-i+1));
            
            % insert label of each button with the entire text option
            uicontrol('Style', 'text',...
                'Position', [70 + spacing, button_position_y, dialog_width - 80 - 2*spacing, button_height], ...
                'String', text, 'FontSize', 12, 'HorizontalAlignment', 'left');
        end
        % flipped because the for cycle before is inverted
        button_handles=flip(button_handles);
    end
    
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
                    fprintf('\nDefinitive selection: %d\n',numPressed)                    
                end
            else
                % In case the sequence number is empty, select default option
                buttonCallback(default_choice);
                clc
                fprintf('\nDefinitive selection: %d\n',default_choice)                
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
