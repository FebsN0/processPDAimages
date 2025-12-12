function accuracy=chooseAccuracy(question)
    options={sprintf('Low       (LineFit = 1, PlaneFit = 1-3)'),'Medium (LineFit = 1-2, PlaneFit = 1-6)','High      (LineFit = 1-3, PlaneFit = 1-9)'};
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