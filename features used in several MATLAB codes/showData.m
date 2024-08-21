function showData(secondMonitorMain,SeeMe,i,data,titleData,labelBar,nameFig)
    if SeeMe
        eval(sprintf('f%d=figure(''Visible'',''on'');',i)) 
    else
        eval(sprintf('f%d=figure(''Visible'',''off'');',i)) 
    end
    imagesc(data)
    colormap parula, title(titleData,'FontSize',17),
    c = colorbar; c.Label.String = labelBar; c.Label.FontSize=15;
    ylabel('slow scan line direction','FontSize',12), xlabel('fast scan line direction','FontSize',12)
    axis equal, xlim([0 size(data,2)]), ylim([0 size(data,1)])
    if ~isempty(secondMonitorMain),objInSecondMonitor(secondMonitorMain,eval(sprintf('f%d',i))); end
    saveas(eval(sprintf('f%d',i)),nameFig)
end