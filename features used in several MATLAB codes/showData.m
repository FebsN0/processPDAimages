function showData(secondMonitorMain,SeeMe,i,data,norm,titleData,labelBar,nameFig)
    if SeeMe
        eval(sprintf('f%d=figure(''Visible'',''on'');',i)) 
    else
        eval(sprintf('f%d=figure(''Visible'',''off'');',i)) 
    end

    if norm
        imshow(imadjust(data/max(max(data))))
        c = colorbar; c.Label.String = 'normalized'; 
    else
        imagesc(data)
        c = colorbar; c.Label.String = labelBar; 
    end
    colormap parula, title(titleData,'FontSize',17),
    c.Label.FontSize=15;
    xlabel('slow scan line direction','FontSize',12), ylabel('fast scan line direction','FontSize',12)
    axis equal, xlim([0 size(data,2)]), ylim([0 size(data,1)])
    objInSecondMonitor(secondMonitorMain,eval(sprintf('f%d',i)));
    saveas(eval(sprintf('f%d',i)),nameFig)
end