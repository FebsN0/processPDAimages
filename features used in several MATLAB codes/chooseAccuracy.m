function accuracy=chooseAccuracy(question)
    options={'Max FitOrder: 1','Max FitOrder: 2','Max FitOrder: 3'};
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