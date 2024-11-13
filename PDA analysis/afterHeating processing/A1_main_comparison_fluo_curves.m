clc, clear, close

[fileName, filePathData] = uigetfile({'*.mat'}, 'Select the file containing the heigh-fluorescence data');

match = regexp(fileName, 'dataResults(\w+)\s', 'tokens');

load(fullfile(filePathData,fileName))
% Rimuove "match" dalla lista delle variabili
vars = setdiff(who, {'fileName','filePathData','match'});
colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k','#FF00FF','#00FF00'};
fmain=figure;
legend_handles=[];

for i=1:length(vars)
    [xData, yData] = prepareCurveData(vertcat(eval(vars{i}).BinCenter),vertcat(eval(vars{i}).MeanBin));
    xData=xData*1e9;
    figure
    plot(xData,yData)
    title(vars{i},'Interpreter', 'none')
    closest_indices = selectRangeGInput(1,1,xData, yData);
    close gcf
    figure(fmain)
    hold on
    plot(xData, yData,'*','Color',colors{i})
    xData=xData(1:closest_indices);
    yData=yData(1:closest_indices);
    ft = fittype( 'poly1' ); opts = fitoptions( 'Method', 'LinearLeastSquares' ); opts.Robust = 'LAR';
    % Fit model to data.
    fitresult = fit( xData, yData, ft, opts );
    x(i,:)=linspace(min(xData),max(xData),100);
    y(i,:)=x(i,:)*fitresult.p1+fitresult.p2;
    hLine=plot(x(i,:),y(i,:),'Color',colors{i},'LineWidth',2,'DisplayName',vars{i});
    legend_handles = [legend_handles, hLine];
end
legend(legend_handles,'Interpreter', 'none','FontSize',14)
ylabel('Absolute fluorescence increase (A.U.)','FontSize',15)
xlabel('Feature height (nm)','FontSize',15)
title(sprintf('Height Vs Fluorescence and Correlation - %s',match{1}{1}),'FontSize',20,'Interpreter', 'none')

save(sprintf('%s/recap_%s',filePathData,fileName),"y","x")        

%% SECOND PART PROCESSING DIFFERENT LIPID ONLY SLOPES

clear
[fileName, filePathData] = uigetfile({'*.mat'}, 'Select the file containing the heigh-fluorescence data','MultiSelect','on');

colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k','#FF00FF','#00FF00'};
fmain=figure;
hold on
legend_handles=[];


for i=1:length(fileName)
    match = regexp(fileName{i}, 'recap_dataResults(\w+)\s', 'tokens');
    load(fullfile(filePathData,fileName{i}))
    hLine=plot(x',y','Color',colors{i},'LineWidth',2,'DisplayName',match{1}{1});
    legend_handles = [legend_handles; hLine(1)];
end

legend(legend_handles,'Interpreter', 'none','FontSize',14)
ylabel('Absolute fluorescence increase (A.U.)','FontSize',15)
xlabel('Feature height (nm)','FontSize',15)
title('Height Vs Fluorescence and Correlation - Every case','FontSize',20,'Interpreter', 'none')
