function showData(secondMonitorMain,SeeMe,i,data,norm,titleData,labelBar,nameFig,varargin)
    if SeeMe
        eval(sprintf('f%d=figure(''Visible'',''on'');',i)) 
    else
        eval(sprintf('f%d=figure(''Visible'',''off'');',i)) 
    end

    if norm
        imshow(imadjust(data/max(max(data))))
        c = colorbar; c.Label.String = 'Normalized'; c.Label.FontSize=15;
    else
        imagesc(data)
        if ~isempty(varargin) && varargin{1}==true            
            c=colorbar;
            set(c,'YTickLabel',[]);
            if secondMonitorMain==1
                cLabel = ylabel(c,'Background                                                                                Foreground');
                c.FontSize=16;
            else
                cLabel = ylabel(c,'Background                                    Foreground');
                c.FontSize=16;
            end
            set(cLabel,'Rotation',90);
        else
            c=colorbar; c.Label.String=labelBar; c.Label.FontSize=15; 
        end
    end
    colormap parula,
    title(titleData,'FontSize',16),
    xlabel('slow scan line direction','FontSize',12), ylabel('fast scan line direction','FontSize',12)
    axis on, axis equal, xlim([0 size(data,2)]), ylim([0 size(data,1)])
    objInSecondMonitor(secondMonitorMain,eval(sprintf('f%d',i)));
    saveas(eval(sprintf('f%d',i)),nameFig)
    eval(sprintf('close(f%d)',i))
end