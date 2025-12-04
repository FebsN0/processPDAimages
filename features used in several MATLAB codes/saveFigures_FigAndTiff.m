function saveFigures_FigAndTiff(fig,nameDir,nameFig,varargin)
    p=inputParser();    %init instance of inputParser
    % Add required parameters
    argName = 'closeImmediately';         defaultVal = true;        addParameter(p,argName,defaultVal,@(x) islogical(x)); 
    parse(p,varargin{:});
    fullnameFig=fullfile(nameDir,"tiffImages",nameFig);
    saveas(fig,fullnameFig,'tiff')
    fullnameFig=fullfile(nameDir,"figImages",nameFig);
    saveas(fig,fullnameFig)
    if p.Results.closeImmediately
        close(fig)
    end
end