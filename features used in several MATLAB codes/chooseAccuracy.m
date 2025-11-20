function accuracy=chooseAccuracy(question)
    options={'Low (1-3)','Medium (1-6)','High (1-9)'};
    answer=getValidAnswer(question,'',options);
    switch answer
        case 1
            accuracy= 'Low';
        case 2
            accuracy= 'Medium';
        case 3
            accuracy= 'High';
    end      
end