function featureFrictionCalc6_plotClearedImages(x,y,maxSetpoint,path,name,secondMonitorMain,method,varargin)   
    if method==1
        titleText='(Mask not applied)';
        nameFileID='_1';
    else
        if nargin == 7
            titleText='(Mask applied)';
            nameFileID='_2_3';       % both method 2 and 3 use same input masked afm data
        else
            pixSize=varargin{1};
            fOutlierRemoval=varargin{2};
        % method 3 after outlier removal
            titleText=sprintf('(Mask + pixel reduction (size %d) +\noutlier removal %s)',pixSize,fOutlierRemoval);
            nameFileID='_3';

        end
    end
    f1=figure('Visible','off');
    subplot(121)
    % show the lateral data
    imagesc(y)
    clim([0 maxSetpoint*1.25])
    c= colorbar; c.Label.String = 'Force [nN]'; c.FontSize = 15;
    title({'Lateral Force in BK regions';titleText},'FontSize',20)
    ylabel(' fast direction - scan line','FontSize',15), xlabel('slow direction','FontSize',15)
    axis equal, xlim([0 size(y,2)]), ylim([0 size(y,1)])
    subplot(122)
    % show the vertical data. If method is 2 or 3, the data is already masked
    imagesc(x)
    clim([0 maxSetpoint*1.25])
    c= colorbar; c.Label.String = 'Force [nN]'; c.FontSize = 15;
    title({'Vertical Force in BK regions';titleText},'FontSize',20)
    sgtitle(sprintf('Background of %s',name),'Fontsize',20,'interpreter','none')
    ylabel(' fast direction - scan line','FontSize',15), xlabel('slow direction','FontSize',15)
    axis equal, xlim([0 size(x,2)]), ylim([0 size(x,1)])
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
    saveas(f1,fullfile(path,sprintf('lateralVerticalData_cleared_scanName_%s_method%s.tif',name,nameFileID)))
    close(f1)
end