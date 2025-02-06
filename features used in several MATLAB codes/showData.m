function showData(secondMonitorMain,SeeMe,i,data1,norm,titleData1,labelBar,nameFig,varargin)
    p=inputParser();    %init instance of inputParser
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And
    %then the values
    argName = 'Binarized';          defaultVal = 'No';    addOptional(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'data2';              defaultVal = [];      addOptional(p,argName,defaultVal)
    argName = 'titleData2';         defaultVal = [];      addOptional(p,argName,defaultVal)
    argName = 'closeImmediately';   defaultVal = true;    addOptional(p,argName,defaultVal, @(x) islogical(x));

    parse(p,varargin{:});
    if strcmp(p.Results.Binarized,'No')
        bin=false;
    else
        bin=true;
    end

    if SeeMe
        eval(sprintf('f%d=figure(''Visible'',''on'');',i)) 
    else
        eval(sprintf('f%d=figure(''Visible'',''off'');',i)) 
    end

    if ~isempty(p.Results.data2)
        subplot(121)
        showSingleData(secondMonitorMain,data1, norm, titleData1, labelBar,bin)
        subplot(122)
        showSingleData(secondMonitorMain,p.Results.data2, norm, p.Results.titleData2, labelBar,bin)
    else
        showSingleData(secondMonitorMain,data1, norm, titleData1, labelBar,bin)
    end    
    objInSecondMonitor(secondMonitorMain,eval(sprintf('f%d',i)));
    saveas(eval(sprintf('f%d',i)),nameFig)
    if p.Results.closeImmediately
        eval(sprintf('close(f%d)',i))
    end
end

function showSingleData(secondMonitorMain,data, norm, titleData, labelBar,bin)
    if norm
        imshow(imadjust(data/max(max(data))))
        c = colorbar; c.Label.String = 'Normalized'; c.Label.FontSize=15;
    else
        imagesc(data)
        if bin          
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
    xlabel('slow direction','FontSize',14), ylabel('fast scan line direction','FontSize',14)
    axis on, axis equal, xlim([0 size(data,2)]), ylim([0 size(data,1)])
end
