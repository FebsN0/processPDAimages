clc, clear, close all
secondMonitorMain=objInSecondMonitor;

typeShow=getValidAnswer('Show one or more type of data?','',{'One type only (ex. only TRCDA different scans)','More different types (ex. TRCDA, TRCDA:DMPC,etc)'});
cnt=1;
f1=figure;
ax1=axes(f1);
hold(ax1, 'on');
if typeShow==1
    f2=figure;
    ax2=axes(f2);
    hold(ax2, 'on');
    f3=figure;
    ax3=axes(f3);
    hold(ax3, 'on');
end

%%
flagHeightVsFluo=false;
flagBaselineComparison=false;
while true
    mainFolderSingleCondition=uigetdir(pwd,'Select for the same type the main folder containing the subfolders ''Results Processing AFM and fluorescence images'' of different scans. Close to exit.');
    if mainFolderSingleCondition == 0
        break
    end
    nameType{cnt}=inputdlg('Enter the name of the data type (example: TRCDA or TRCDA:DMPC, etc)'); %#ok<SAGROW>
    disp(nameType{cnt}{1})
    commonPattern = 'Results Processing AFM and fluorescence images';
    % Get a list of all subfolders in the selected directory
    allSubfolders = dir(fullfile(mainFolderSingleCondition, '**', '*'));
    % Filter to only include subfolders matching the common pattern
    matchedSubfolders = allSubfolders([allSubfolders.isdir] & contains({allSubfolders.name}, commonPattern));
    % Initialize a cell array to store file paths
    allResultsData = {};
    allBaselineTXT ={};
    % Loop through the matched subfolders
    for k = 1:length(matchedSubfolders)
        % Construct the full path of the current subfolder and then search the specific file
        subfolderPath = fullfile(matchedSubfolders(k).folder, matchedSubfolders(k).name);
        if typeShow == 1
            parts=split(subfolderPath,'\');
            subfolderName{k} = parts{end-1}; %#ok<SAGROW>
        end
        filesInSubfolder = dir(fullfile(subfolderPath, 'resultsData_A10_end.mat'));
        % If the file exists, append it to the list
        if ~isempty(filesInSubfolder)
            for j = 1:length(filesInSubfolder)
                allResultsData{end+1} = fullfile(filesInSubfolder(j).folder, filesInSubfolder(j).name); %#ok<SAGROW>
            end
        end
        % if baseline.txt exist in the current folder, take it so better
        % comparison later with metaDataAFM baseline. baselineEnd useful
        % information
        pathFileBaselineTXT =fullfile(matchedSubfolders(k).folder,"baseline.txt");
        if exist(pathFileBaselineTXT,"file")
            [baselineStart_dev,baselineEnd_dev]=extractBaselineDataTXT(pathFileBaselineTXT);
            if isempty(baselineStart_dev)
                warning("Data baseline.txt not available")
            end
        end

    end
    % init
    slopes=zeros(1,length(allResultsData));
    flagNorm=zeros(1,length(allResultsData));
    for i=1:length(allResultsData)
        % if only one type of data, better visual using different color, but in case of more type/different
        % samples, use single color for each type/sample
        if typeShow==1
            clr=globalColor(i);
        else
            clr=globalColor(cnt);
        end
        % load only fluorescence and lateral deflection
        load(allResultsData{i},"Data_finalResults","metaData_AFM")
        flagNorm(i)=Data_finalResults.DeltaNormalized;
        if i>1 && flagNorm(i)~=flagNorm(1)
            if flagNorm(i) == true
                currN='normalized'; prevN='not normalized';
            else
                currN='not normalized'; prevN='normalized';
            end
            msgbox(sprintf('The current %d-th block of data is %s, whereas the first block is %s\nThe current block will be ignored and skipped to the next block',i,currN,prevN),"WARNING","warn");
            continue
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% extract the data fluorescene VS lateral deflection %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        data_LDvsFLUO=Data_finalResults.LDmaxVD_FLUO;    
        x=cell2mat({data_LDvsFLUO.BinCenter});
        y=cell2mat({data_LDvsFLUO.MeanBin});
        ystd=cell2mat({data_LDvsFLUO.STDBin});
        % the force is expressed in Newton ==> express in nanoNewton
        x=x*1e9;
        [xData,yData,~] = prepareCurveData(x,y,ystd);
        if typeShow == 1
            nameplot = sprintf('Experimental Data - %s',subfolderName{i});
        else
            nameplot = 'Experimental Data';
        end
        hp=plot(ax1,xData,yData,'x','Color',clr,'DisplayName',nameplot);
        hp.Annotation.LegendInformation.IconDisplayStyle = 'off';
        % Fit:
        ft = fittype( 'poly1' );
        opts = fitoptions( 'Method', 'LinearLeastSquares' );
        opts.Robust = 'LAR';
        [fitresult, gof] = fit( xData, yData, ft, opts );
        xfit=linspace(xData(1),xData(end),length(xData));
        yfit=xfit*fitresult.p1+fitresult.p2;
        if typeShow == 1
            nameplot = sprintf('Fitted Curve - %s',subfolderName{i});
            hf{i}= plot(ax1,xfit,yfit,'Color',clr,'DisplayName',nameplot,'LineWidth',3); %#ok<SAGROW>
        else
            nameplot = 'Fitted Curve';
            hf{cnt}= plot(ax1,xfit,yfit,'Color',clr,'DisplayName',nameplot,'LineWidth',3); %#ok<SAGROW>
        end        
        % save the fit var to calc the average
        slopes(i)=fitresult.p1;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% extract the data fluorescene VS Height %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if typeShow == 1 
            if flagHeightVsFluo || getValidAnswer('Show also the Fluorescence Vs Height comparison?','',{'Yes','No'},2)
                flagHeightVsFluo=true;
                nameplot = sprintf('Experimental Data - %s',subfolderName{i});
                data_HeightvsFLUO=Data_finalResults.Height99perc_FLUO;
                x=cell2mat({data_HeightvsFLUO.BinCenter});
                y=cell2mat({data_HeightvsFLUO.MeanBin});
                ystd=cell2mat({data_HeightvsFLUO.STDBin});
                % the space is expressed in meter ==> express in nanometer
                x=x*1e9;
                [xData,yData,ystdData] = prepareCurveData(x,y,ystd);
                hp_HeightFluo=plot(ax2,xData,yData,'-x','Color',clr,'DisplayName',nameplot);
            else
                close(f2)
            end
        end
        if typeShow == 1 
            if flagBaselineComparison || getValidAnswer('Show also the Baseline comparison among the scans?','',{'Yes','No'},2)
                flagBaselineComparison=true;
                totTimeScan = (metaData_AFM.x_scan_pixels/metaData_AFM.Scan_Rate_Hz)/60;
                totTimeSection = totTimeScan/length(metaData_AFM.SetP_N);
                % first plot the baseline given in the metadata
                arrayTime_1=0:totTimeSection:totTimeScan-totTimeSection;
                %arrayTime_2=0:totTimeSection:totTimeScan;           
                baselineN_1=metaData_AFM.Baseline_N*1e9;
                %baselineN_2=([baselineStart_dev; baselineEnd_dev]')*1e9;
                if length(baselineN_1) > 1
                    % plot the baseline trend from metadata
                    %nameplot = sprintf('From metadata - scan #%s',subfolderName{i});
                    nameplot = sprintf('Scan #%s',subfolderName{i});
                    hp_baseline_metadata=plot(ax3,arrayTime_1,baselineN_1,'-*','LineWidth',2,'MarkerSize',10,'MarkerEdgeColor',clr,'Color',clr,'DisplayName',nameplot);
                    % plot the baseline trend from baseline.txt file
                    %nameplot = sprintf('From baseline.txt - scan #%s',subfolderName{i});
                    %hp_baseline_txt=plot(ax3,arrayTime_2,baselineN_2,'--*','LineWidth',2,'MarkerSize',10,'MarkerEdgeColor',clr,'Color',clr,'DisplayName',nameplot);                           
                end
            else
                close(f3)
            end
        end
    end
    slopeAVG_type(cnt)=mean(slopes); %#ok<SAGROW>
    slopeSTD_type(cnt)=std(slopes); %#ok<SAGROW>
    if typeShow==1
        break
    end
    cnt=cnt+1;
end


if typeShow==1
    legend(ax1,'Location', 'best','FontSize',15,'Interpreter','none')
    title(ax1,{sprintf('Comparison of different scans of the same sample (%s)',nameType{1}{1}); sprintf('Slope: = %.2e \x00B1 %.2e',slopeAVG_type,slopeSTD_type)},'FontSize',20,'Interpreter','none');
else
    textH=''; textN=''; textNT=cell(1,cnt-1);  
    for n=1:cnt-1
        textNT{n} = sprintf(' %s \n - slope: = %.2e \x00B1 %.2e',nameType{n}{1},slopeAVG_type(n),slopeSTD_type(n));
        if n==1
            textN = sprintf('textNT{%d}',n);
            textH = sprintf('hf{%d}',n);
        else
            textN = sprintf('%s;textNT{%d}',textN,n);
            textH = sprintf('%s;hf{%d}',textH,n);
        end
    end
    legend(eval(sprintf('[%s]',textH)),textNT, 'Location', 'best','FontSize',15,'Interpreter','none');
    title('LD Vs Fluorescence - comparison different settings','FontSize',20);
end
figure(f1)
xlim padded
ylim padded
grid on, grid minor
objInSecondMonitor(secondMonitorMain,f1);
if all(flagNorm)
    ylabelAxis=string(sprintf('Normalised Fluorescence (%%)'));
else
    ylabelAxis='Absolute fluorescence increase (A.U.)';
end
ylabel(ylabelAxis,'FontSize',20)
xlabel('Lateral Force [nN]','FontSize',20)
set(ax1, 'FontSize', 23);

if typeShow==2
    [filename,foldername]= uiputfile('*.tif',"Where save the final results?","RESULTSfinal_LDvsFLUO");
    saveas(f1,fullfile(foldername,filename))
else
    saveas(f1,sprintf('%s/RESULTSfinal_LDvsFLUO.tif',mainFolderSingleCondition))
end

if isvalid(f2)
    figure(f2)
    xlim padded
    ylim padded
    grid on, grid minor
    objInSecondMonitor(secondMonitorMain,f2);
    ylabel(ylabelAxis,'FontSize',20)
    xlabel('Height [nm]','FontSize',20)
    legend(ax2,'Location', 'best','FontSize',15,'Interpreter','none')    
    title(ax2,sprintf('Height vs Fluorescence - comparison of different scans (sample %s)',nameType{1}{1}),'FontSize',20,'Interpreter','none');
    saveas(f2,sprintf('%s/RESULTSfinal_LDvsHeight.tif',mainFolderSingleCondition))
end

if isvalid(f3)
    figure(f3)
    xlim padded
    ylim padded
    grid on, grid minor
    objInSecondMonitor(secondMonitorMain,f3);
    ylabel('Baseline shift [nN]','FontSize',20), xlabel('Time [min]','FontSize',20)
    legend(ax3,'Location', 'best','FontSize',15,'Interpreter','none')
    title(ax3,sprintf('Baseline Shift Trend - comparison of different scans (sample %s)',nameType{1}{1}),'FontSize',20,'Interpreter','none')
    saveas(f3,sprintf('%s/RESULTSfinal_Baseline.tif',mainFolderSingleCondition))
end


function [baselineStart,baselineEnd] =extractBaselineDataTXT(filePath)
    % Read entire file as text
    fid = fopen(filePath, 'r');
    fileText = fread(fid, '*char')';
    fclose(fid);
     % Split by blocks (each starting with '# Start time')
    blockStarts = strfind(fileText, '# Start time =');
    numBlocks = numel(blockStarts);    
    if numBlocks == 0
        warning('No data blocks found in the file.');
    else    
        % Extract only the last block
        if numBlocks > 1
            lastBlockText = fileText(blockStarts(end):end);
        else
            lastBlockText = fileText;
        end
        % Extract the lines of the last block
        blockLines = strsplit(lastBlockText, '\n')';
        % Find the header line
        headerIdx = find(contains(blockLines, '# ScanIndex'), 1);       
        if isempty(headerIdx)
            error('Header line with "# ScanIndex" not found.');
        end 
        % find the BaselineStart and BaselineEnd idxs
        columnNames = strsplit(strtrim(blockLines{headerIdx}), '\t');
        baselineStartIdx = find(strcmp(columnNames, 'BaselineStart'), 1);
        baselineEndIdx = find(strcmp(columnNames, 'BaselineEnd'), 1);
          
        % Read data starting from the line after the header
        dataLines = blockLines(headerIdx+1:end);    
        % Remove any lines that start with '#' or are empty
        dataLines = dataLines(cellfun(@(l) ~isempty(l) && ~isnan(str2double(strtok(strtrim(l)))), dataLines));
        baselineStart = zeros(numel(dataLines), 1);
        baselineEnd=[];
        for i = 1:numel(dataLines)
            tokens = strsplit(dataLines{i}, '\t');              % Proper tab delimiter
            baselineStart(i) = str2double(tokens{baselineStartIdx});     % Convert all to double
            if i==numel(dataLines)
                baselineEnd= str2double(tokens{baselineEndIdx});
            end
        end
    end
end