% when method 3 is used, the size of the two arrays may chance when pix size increase,
% therefore, the best approach is to find the variation point in verticalData.

% NOTE: the input must be a vector of elements as average of entire fast scan line
function [limsXY,stats]=featureFrictionCalc3_plotErrorBar(vertForce,latForce,idxFile,nameScan)
    if ~isvector(vertForce) || ~isvector(latForce)
        error('The input data are not vector. Each element represents the average of a i-th fast scan line, therefore the vector lenght represents the slow lines')
    end
    % find the idx of single blocks by setpoint
    [~,idx]=unique(round(vertForce,-1));
    % init
    latForce_Blocks_avg=zeros(1,length(idx));
    latForce_Blocks_std=zeros(1,length(idx));
    vertForce_Blocks_avg=zeros(1,length(idx));
    vertForce_Blocks_std=zeros(1,length(idx));
    % flip because the high setpoint is on the left
    idx=flip(idx);   
    for i=1:length(idx)-1
        % extract the lateral and vertical deflection of the single box
        latForce_Block=latForce(idx(i):(idx(i+1)-1));
        vertForce_Block=vertForce(idx(i):(idx(i+1)-1));
        % calc the avg an std of the entire block (vector portion that represent the original matrix)
        latForce_Blocks_avg(i)=mean(latForce_Block); 
        latForce_Blocks_std(i)=std(latForce_Block);
        vertForce_Blocks_avg(i)=mean(vertForce_Block); 
        vertForce_Blocks_std(i)=std(vertForce_Block);
    end
    %last block
    latForce_Block=latForce(idx(end):end);
    vertForce_Block=vertForce(idx(end):end);      
    % calc the mean and std of last block
    latForce_Blocks_avg(end)=mean(latForce_Block);
    latForce_Blocks_std(end)=std(latForce_Block);
    vertForce_Blocks_avg(end)=mean(vertForce_Block); 
    % flip to start with low value at left
    x=flip(vertForce_Blocks_avg);
    y=flip(latForce_Blocks_avg);
    err=flip(latForce_Blocks_std);
    % save the stats
    stats.vertAvgX=x; stats.forceAvgY=y; stats.forceErr=err;
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

