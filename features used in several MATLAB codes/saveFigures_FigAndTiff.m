function saveFigures_FigAndTiff(fig,nameDir,nameFig)
    fullnameFig=fullfile(nameDir,"tiffImages",nameFig);
    saveas(fig,fullnameFig,'tiff')
    fullnameFig=fullfile(nameDir,"figImages",nameFig);
    saveas(fig,fullnameFig) 
    close(fig)
end