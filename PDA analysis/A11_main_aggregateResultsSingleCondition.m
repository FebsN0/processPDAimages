clc, clear, close all
secondMonitorMain=objInSecondMonitor;
colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k','#FF00FF','#00FF00'};

mainFolderSingleCondition=uigetdir(pwd,'Select the main folder containing the subfolders ''Results Processing AFM and fluorescence images''');
if mainFolderSingleCondition == 0
    error('No folder selected');
end
commonPattern = 'Results Processing AFM and fluorescence images';
% Get a list of all subfolders in the selected directory
allSubfolders = dir(fullfile(mainFolderSingleCondition, '**', '*'));
% Filter to only include subfolders matching the common pattern
matchedSubfolders = allSubfolders([allSubfolders.isdir] & contains({allSubfolders.name}, commonPattern));
% Initialize a cell array to store file paths
allFiles = {};
% Loop through the matched subfolders
for k = 1:length(matchedSubfolders)
    % Construct the full path of the current subfolder and then search the specific file
    subfolderPath = fullfile(matchedSubfolders(k).folder, matchedSubfolders(k).name);
    filesInSubfolder = dir(fullfile(subfolderPath, 'dataResults.mat'));
    % If the file exists, append it to the list
    if ~isempty(filesInSubfolder)
        for j = 1:length(filesInSubfolder)
            allFiles{end+1} = fullfile(filesInSubfolder(j).folder, filesInSubfolder(j).name);
        end
    end   
end

%%
maxForce=120; % expressed in nanoNewton
f1=figure; hold on; grid on
slopes=zeros(1,length(allFiles));
for i=1:length(allFiles)
    % load only fluorescence and lateral deflection
    load(allFiles{i},"dataPlot_LD_FLUO_padMask_maxVD")
    x=cell2mat({dataPlot_LD_FLUO_padMask_maxVD.BinCenter});
    y=cell2mat({dataPlot_LD_FLUO_padMask_maxVD.MeanBin});
    % the force is expressed in Newton ==> express in nanoNewton
    x=x*1e9;
    [xData,yData] = prepareCurveData(x,y);
    %ystd=cell2mat({data_LD_FLUO_padMask.STDBin});
    %[xData,yData,ystdData] = prepareCurveData(x,y,ystd);
    
    % old version in which all lateral force data was given
    % idxEnd=find(floor(xData)==maxForce,1);
    % xData=xData(1:idxEnd); yData=yData(1:idxEnd);
    %ystdDat=ystdData(1:idxEnd);

    hp=plot(xData,yData,'x','Color',colors{i},'DisplayName','Experimental Data');
    % Fit:
    ft = fittype( 'poly1' );
    opts = fitoptions( 'Method', 'LinearLeastSquares' );
    opts.Robust = 'LAR';
    [fitresult, gof] = fit( xData, yData, ft, opts );
    xfit=linspace(xData(1),xData(end),length(xData));
    yfit=xfit*fitresult.p1+fitresult.p2;
    hf= plot(xfit,yfit,'Color',colors{i},'DisplayName','Fitted Curve','LineWidth',3);
    % save the fit var to calc the average
    slopes(i)=fitresult.p1;
end

nameCondition=inputdlg('Enter the name of molecule condition');
set(gca, 'FontSize', 25);
ylabel('Absolute fluorescence increase [A.U.]','FontSize',20)
xlabel('Lateral Force [nN]','FontSize',20)

title(sprintf('LD Vs Fluorescence increase - %s',nameCondition{1}));
legend([hp, hf])
xlim([-3 130])
ylim([-5e-5 3.2e-3])

slopeAVG=mean(slopes);
slopeSTD=std(slopes);
fprintf('SlopeAVG: %d     SlopeSTD: %d\n',slopeAVG,slopeSTD)
objInSecondMonitor(secondMonitorMain,f1);
%saveas(f1,sprintf('%s/RESULTSfinal.tif',mainFolderSingleCondition))
