function definitiveFc=featureFrictionCalc7_distributionFc_allScansAllPixels(frictionCoefficients,nameAllScans,idxMon,newFolder,varargin)
% make the cell array containing all the fc as array to generate the edges       
    allFcVsPix_Array = [frictionCoefficients{:}];
    % create the edges in which count the values
    edges=linspace(0,1,51);
    % init
    countsMatrix = zeros(length(edges)-1, length(frictionCoefficients));
    % count for each cell
    for i = 1:length(frictionCoefficients)
        data = frictionCoefficients{i};                        
        countsMatrix(:, i) = histcounts(data, edges)';
    end
    binCenters = edges(1:end-1) + diff(edges)/2;
    % Plot con bar stacked
    f_fcAll=figure;
    b=bar(binCenters, countsMatrix, 'stacked','BarWidth', 1); grid on
    % Allinea le larghezze dei bar con gli edges
    for i = 1:length(b)
        b(i).BarWidth = 1; % Imposta larghezza al 100% dello spazio disponibile
        b(i).DisplayName=sprintf('scan %s',nameAllScans{i});
    end
    ylim([0 round(max(countsMatrix(:))*1.2)]), xlim([0 1])
    xlabel('Friction coefficient','FontSize',15)
    ylabel('Frequency','FontSize',15)
    % if varargin has two elements, then the data is from method 3
    if length(varargin)==2
        pixData=varargin{1};
        fOutlierRemoval=varargin{2};
        mainTitle=sprintf('Distribution of FC of any pixel size reduction (sz: %d, step: %d) and any scan - method 3 option %d',pixData(1),pixData(2),fOutlierRemoval);
    else
    % if varargin has one element, then the data is from method 1 or 2
        method=varargin{1};
        mainTitle=sprintf('Distribution of FC of any scan - method %d',method);
    end
    title(mainTitle,'Fontsize',20)
    objInSecondMonitor(f_fcAll,idxMon);
    legend('Interpreter','none','FontSize',15,'Location','northeast')
    uiwait(msgbox('Click twice on the distribution to select the range to consider the friction coefficients required for the averaging.'));
    idx_x=selectRangeGInput(2,1,edges);
    range=[edges(idx_x(1)),edges(idx_x(2))];
    range=sort(range);
    x1=xline(range(1),'r--','LineWidth',1.5); xline(range(2),'r--','LineWidth',1.5,'DisplayName','Selected Range')
    x1.Annotation.LegendInformation.IconDisplayStyle = 'off'; % dont show name in the legend
    selectedRangeFc= allFcVsPix_Array(allFcVsPix_Array > range(1) & allFcVsPix_Array < range(2));
    definitiveFc=round(mean(selectedRangeFc),3);
    definitiveFc_std=round(std(selectedRangeFc),3);
    resultChoice= sprintf('Friction Coefficient in the selected range: %0.3f ± %0.3f',definitiveFc,definitiveFc_std);
    title({mainTitle; resultChoice},'FontSize',18,'interpreter','none');            
    saveas(f_fcAll,sprintf('%s/resultMethod3_frictionCoeffsDistribution_option%d.tif',newFolder,fOutlierRemoval))           
    uiwait(msgbox('Click to conclude'));
    close(f_fcAll)
end