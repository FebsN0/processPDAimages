function user_choice = getValidAnswer(question, title, options)
    % old version        
    %while true
        %userInput = input([question, ' '], 's');
        % if any(strcmpi(userInput, possibleAnswers))
        %     answer = userInput;
        %     break;
        % else
        %     fprintf('\nInvalid answer. Please try again.\n\n');
        % end
    %end

    % Default dialog box size
    base_width = 450; base_height = 150; button_height = 40; spacing = 10;
    
    % Check the longest string in the question and how many rows
    max_question_length = max(cellfun(@length, strsplit(question, '\n')));
    num_lines_question = length(strsplit(question, '\n'));

    % check how many options rows. Since the options may contains \n, check the length better
    num_lines_options = length(options);
    num_lines_options_split = 0;
    lengthRow=[];
    for i=1:length(options)
        splittedCell = strsplit(options{i},'\n');
        num_lines_options_split = num_lines_options_split + length(splittedCell);
        for j=1:length(splittedCell)
            lengthRow(i,j)= cellfun(@length, splittedCell(j));
        end
    end
    max_option_length = max(max(lengthRow));
    % check what is the longest string among question and options
    max_length = max(max_question_length, max_option_length);

    % the size depends on the fontsize too.
    FontsizeQuestion= 14;
    FontsizeOptions = 12;
    % check the best height size
    sizeRowOptions                  =  num_lines_options_split*FontsizeOptions;
    sizeRowDistanceBetweenOptions   = (num_lines_options)* (button_height + spacing);
    sizeRowQuestion                 = num_lines_question*FontsizeQuestion;
    
    if  num_lines_options <= 2 && num_lines_question <= 1 % minimal condition
        sizeRowQuestionOptions = 50;
    elseif num_lines_options <= 2 && num_lines_question == 2
        sizeRowQuestionOptions = 70;
    else
        sizeRowQuestionOptions = sizeRowQuestion+sizeRowOptions;
    end
    % Calc width based on length of every texts
    dialog_width = max(base_width, FontsizeQuestion * max_length);
    
    % Calc height based on number of options. If too small, than take the base_height
    dialog_height = max(base_height,sizeRowQuestionOptions + sizeRowDistanceBetweenOptions);
 
    % Locate the dialog box in the center
    screenSize = get(0, 'ScreenSize');
    screen_width = screenSize(3);
    screen_height = screenSize(4);
    dialog_x = (screen_width - dialog_width) / 2;
    dialog_y = (screen_height - dialog_height) / 2;
    
    % Open dialog box
    dialog_fig = figure('Name', title, 'NumberTitle', 'off', 'MenuBar', 'none', ...
        'ToolBar', 'none', 'Resize', 'off', 'Position', [dialog_x, dialog_y, dialog_width, dialog_height], ...
        'WindowStyle', 'modal');
 
    % Insert the question in the dialog box
    uicontrol('Style', 'text', 'Position', [spacing, dialog_height - 80, dialog_width - 2*spacing, 40 + num_lines_question * 20], ...
        'String', question, 'FontSize', FontsizeQuestion, 'HorizontalAlignment', 'center','ForegroundColor', 'red');
    
    % bottons positions
    button_start_y = dialog_height - 80 - num_lines_question * 10;
   
    user_choice = 0;
    % buttons Callback
    function buttonCallback(choice)
        user_choice = choice;
        uiresume(dialog_fig);
    end

    % create buttons and texts
    for i = 1:num_lines_options
        % Calc button vertical position 
        button_position_y = button_start_y - (i - 1) * (button_height + spacing);
        
        % Name button = first char of the given option ( 1) bla bla ==> 1, Yes ==> Y
        uicontrol('Style', 'pushbutton', 'Position', [spacing, button_position_y, 50, button_height], ...
            'String', options{i}(1), 'FontSize', FontsizeOptions, 'Callback', @(src, event) buttonCallback(i));
        
        % insert label of each button with the entire text option
        uicontrol('Style', 'text', 'Position', [70 + spacing, button_position_y, dialog_width - 80 - 2*spacing, button_height], ...
            'String', options{i}, 'FontSize', 12, 'HorizontalAlignment', 'left');
    end
    %wait until user make a choice
    uiwait(dialog_fig);
    close(dialog_fig);
end