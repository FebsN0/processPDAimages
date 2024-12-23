% when method 3 is used, the size of the two arrays may chance when pix size increase,
% therefore, the best approach is to find the variation point in verticalData.

% vertForce_avg_fixed2,force_fixed_avg

function limsXY=feature_plotErrorBar(vertForce,latForce,idxFile,nameScan)
    [x,idx]=unique(round(vertForce));
    latForce_Blocks=cell(1,length(idx));
    for i =1:length(idx)-1
        latForce_Blocks{i}=latForce(idx(i):(idx(i+1)-1));
    end
    latForce_Blocks{end}=latForce(idx(end):end);
    y=cellfun(@mean,latForce_Blocks);
    err=cellfun(@std,latForce_Blocks);
    errorbar(x,y,err,'s','Linewidth',1.3,'capsize',15,'Color',globalColor(idxFile),...
        'markerFaceColor',globalColor(idxFile),'markerEdgeColor',globalColor(idxFile),'MarkerSize',10,...
        'DisplayName',sprintf('Experiment %s',nameScan));
    % store the max and min of each axis for a better show
    xMin=min(x); xMax=max(x);
    yMin=min(y-err); yMax=max(y+err);
    limsXY=[xMin,xMax;yMin,yMax];
end



% pseudo global variable
function col = globalColor(n)
    colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k','#FF00FF','#00FF00','#0000FF','#FF0000'};
    col=colors{n};
end

