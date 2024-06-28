function answer = getValidAnswer(question, possibleAnswers)
    while true
        userInput = input([question, ' '], 's');
        if any(strcmpi(userInput, possibleAnswers))
            answer = userInput;
            break;
        else
            fprintf('\nInvalid answer. Please try again.\n\n');
        end
    end
end
