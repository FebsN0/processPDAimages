clc, clear, close all
secondMonitorMain=objInSecondMonitor;
colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k','#FF00FF','#00FF00'};


typeShow=getValidAnswer('Show one or more type of data?','',{'One type only (ex. only TRCDA different scans)','More different types (ex. TRCDA, TRCDA:DMPC,etc)'});
cnt=1;
f1=figure;
ax1=axes(f1);
hold(ax1, 'on');
while true
    mainFolderSingleCondition=uigetdir(pwd,'Select for the same type the main folder containing the subfolders ''Results Processing AFM and fluorescence images'' of different scans. Close to exit.');
    if mainFolderSingleCondition == 0
        break
    end
    nameType{cnt}=inputdlg('Enter the name of the data type (example: TRCDA or TRCDA:DMPC, etc)');
    disp(nameType{cnt}{1})
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
        filesInSubfolder = dir(fullfile(subfolderPath, 'resultsData_A10_end.mat'));
        % If the file exists, append it to the list
        if ~isempty(filesInSubfolder)
            for j = 1:length(filesInSubfolder)
                allFiles{end+1} = fullfile(filesInSubfolder(j).folder, filesInSubfolder(j).name);
            end
        end   
    end
        
    slopes=zeros(1,length(allFiles));
    xmax=zeros(length(allFiles),1);
    for i=1:length(allFiles)
        % if only one type of data, better visual using different color, but in case of more type/different
        % samples, use single color for each type/sample
        if typeShow==1
            clr=colors{i};
        else
            clr=colors{cnt};
        end
        % load only fluorescence and lateral deflection
        load(allFiles{i},"Data_finalResults")
        % extract the data fluorescene VS lateral deflection
        data_LDvsFLUO=Data_finalResults.LD_FLUO_padMask_maxVD;    
        x=cell2mat({data_LDvsFLUO.BinCenter});
        y=cell2mat({data_LDvsFLUO.MeanBin});
        ystd=cell2mat({data_LDvsFLUO.STDBin});
        % the force is expressed in Newton ==> express in nanoNewton
        x=x*1e9;
        [xData,yData,ystdData] = prepareCurveData(x,y,ystd);
        hp=plot(ax1,xData,yData,'x','Color',clr,'DisplayName','Experimental Data');
        % Fit:
        ft = fittype( 'poly1' );
        opts = fitoptions( 'Method', 'LinearLeastSquares' );
        opts.Robust = 'LAR';
        [fitresult, gof] = fit( xData, yData, ft, opts );
        xfit=linspace(xData(1),xData(end),length(xData));
        yfit=xfit*fitresult.p1+fitresult.p2;
        %yfit=xfit.^2*fitresult.p1+xfit*fitresult.p2+fitresult.p3;
        hf{cnt}= plot(ax1,xfit,yfit,'Color',clr,'DisplayName','Fitted Curve','LineWidth',3);
        % save the fit var to calc the average
        slopes(i)=fitresult.p1;
    end
    slopeAVG_type(cnt)=mean(slopes);
    slopeSTD_type(cnt)=std(slopes);
    cnt=cnt+1;
end

title('LD Vs Fluorescence','FontSize',20);
if typeShow==1
    legend([hp, hf])
else
    textH=''; textN=''; textNT=cell(1,cnt-1); 
    for n=1:cnt-1
        textNT{n} = sprintf(' %s \n - slopeAVG: = %.2e \x00B1 %.2e',nameType{n}{1},slopeAVG_type(n),slopeSTD_type(n));
        if n==1
            textN = sprintf('textNT{%d}',n);
            textH = sprintf('hf{%d}',n);
        else
            textN = sprintf('%s;textNT{%d}',textN,n);
            textH = sprintf('%s;hf{%d}',textH,n);
        end
    end
    legend(eval(sprintf('[%s]',textH)),textNT, 'Location', 'best','FontSize',15,'Interpreter','none');
end
xlim padded
ylim padded
grid on, grid minor
objInSecondMonitor(secondMonitorMain,f1);
%saveas(f1,sprintf('%s/RESULTSfinal.tif',mainFolderSingleCondition))
ylabel('Absolute fluorescence increase [A.U.]','FontSize',20)
xlabel('Lateral Force [nN]','FontSize',20)
set(ax1, 'FontSize', 23);