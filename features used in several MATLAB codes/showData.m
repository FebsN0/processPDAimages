% show the data with proper title and etc etc
% INPUT:    secondMonitorMain = 0 / 1
%           SeeMe = true / false
%           i = number of the plot for the correct image file enumeration (if there are many plots in the same function which call this function)
%           data1 = matrix which contains the data to show
%           norm = true / false ==> normalize the data
%           titleData1 = title to show in the plot
%           labelBar = text to show in the label (in case norm = true, the text will be just 'normalized'
%           nameFig = name of the generating file
%           varargin =      Data2 and titleData2 for a figure with two subplots
%                           Binarized = true / false
%                           closeImmediately = true / false
function showData(secondMonitorMain,SeeMe,i,data1,norm,titleData1,labelBar,nameDir,nameFig,varargin)
    p=inputParser();    %init instance of inputParser
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And
    %then the values
    argName = 'Binarized';          defaultVal = false;   addOptional(p,argName,defaultVal, @(x) islogical(x));
    argName = 'data2';              defaultVal = [];      addOptional(p,argName,defaultVal)
    argName = 'titleData2';         defaultVal = [];      addOptional(p,argName,defaultVal)
    argName = 'closeImmediately';   defaultVal = true;    addOptional(p,argName,defaultVal, @(x) islogical(x));
    argName = 'background';         defaultVal = false;   addOptional(p,argName,defaultVal, @(x) islogical(x));

    parse(p,varargin{:});
    if p.Results.Binarized, bin=true; else, bin=false; end
    if p.Results.background, bk=true; else, bk=false; end

    if SeeMe
        eval(sprintf('f%d=figure(''Visible'',''on'');',i)) 
    else
        eval(sprintf('f%d=figure(''Visible'',''off'');',i)) 
    end   

    if ~isempty(p.Results.data2)
        subplot(121)
        showSingleData(secondMonitorMain,data1, norm, titleData1, labelBar,bin,bk)       
        subplot(122)
        showSingleData(secondMonitorMain,p.Results.data2, norm, p.Results.titleData2, labelBar,bin,bk)
    else
        showSingleData(secondMonitorMain,data1, norm, titleData1, labelBar,bin,bk)
    end    
    objInSecondMonitor(secondMonitorMain,eval(sprintf('f%d',i)));
    
    if ~exist(sprintf('%s/tiffImages',nameDir),"dir") 
        mkdir(sprintf('%s/tiffImages',nameDir))
        mkdir(sprintf('%s/figImages',nameDir))
    end
    % save both fig (eventually for post modification) and tiff
    fullnameFig=fullfile(nameDir,"tiffImages",nameFig);
    saveas(eval(sprintf('f%d',i)),fullnameFig,'tiff')
    fullnameFig=fullfile(nameDir,"figImages",nameFig);
    saveas(eval(sprintf('f%d',i)),fullnameFig)
    if p.Results.closeImmediately
        eval(sprintf('close(f%d)',i))
    end
end

function showSingleData(secondMonitorMain,data, norm, titleData, labelBar,bin,bk)
    if norm
        imshow(imadjust(data/max(max(data))))
        c = colorbar; c.Label.String = 'Normalized'; c.Label.FontSize=15;
    else
        h=imagesc(data);
        if bk
            % make white the nan data for better visual
            set(h, 'AlphaData', ~isnan(h.CData))
        end
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
