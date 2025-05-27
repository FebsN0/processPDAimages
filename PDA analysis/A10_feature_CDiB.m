% Function to collect data into bins

function [outputme] = A10_feature_CDiB(X_Data,Y_Data,secondMonitorMain,newFolder,varargin)

    p=inputParser();
    argName = 'setpoints';      defaultVal = [];                                        addParameter(p,argName,defaultVal);
    argName = 'NumberOfBins';   defaultVal = 100;                                       addParameter(p,argName,defaultVal);
    argName = 'xpar';           defaultVal = 1e9;                                       addParameter(p,argName,defaultVal);
    argName = 'ypar';           defaultVal = 1e9;                                       addParameter(p,argName,defaultVal);
    argName = 'YAyL';           defaultVal = 'Relative Intensity Increase (A.U.)';      addParameter(p,argName,defaultVal);
    argName = 'XAxL';           defaultVal = 'Force (N)';                               addParameter(p,argName,defaultVal);
    argName = 'FigTitle';       defaultVal = '';                                        addParameter(p,argName,defaultVal);
    argName = 'FigFilename';    defaultVal = 'AA';                                      addParameter(p,argName,defaultVal);
    argName = 'Xlimit';         defaultVal = ([]);                                      addParameter(p,argName,defaultVal);
    argName = 'Ylimit';         defaultVal = ([]);                                      addParameter(p,argName,defaultVal);
    argName = 'MType';          defaultVal = 'o';                                       addParameter(p,argName,defaultVal);
    argName = 'MCoulor';        defaultVal = 'k';                                       addParameter(p,argName,defaultVal);
    argName = 'NumFig';         defaultVal = '';                                        addParameter(p,argName,defaultVal);

    parse(p,varargin{:});
    % clean NaN
    x_clean=X_Data(~isnan(X_Data));
    y_clean=Y_Data(~isnan(Y_Data));
    % additional check. Using the original method, the pixels were not at same 2D position.
    if length(x_clean)~=length(y_clean)
        error("The two given vectors have different lengths after removing NaN values. As results, the pixels are not in the same 2D position!")
    end
    DataOI(:,1)=x_clean;
    DataOI(:,2)=y_clean;
    clearvars X_Data Y_Data varargin x_clean y_clean

    % if setpoint is declared, then manage the plot using that
    if ~isempty(p.Results.setpoints)
        setpointN=p.Results.setpoints;
        if setpointN(1)>setpointN(end)
            setpointN=flip(setpointN);
            DataOI=flip(DataOI);
        end
 
        x_bin_start=zeros(length(setpointN)+1,1);
        % first and last bin will include the first and last values instead of removing them
        x_bin_start(1)= min(DataOI(:,1));
        x_bin_start(end)=max(DataOI(:,1)); % last x_bin_end
        for i=2:length(setpointN)
            x_bin_start(i)=mean([setpointN(i-1),setpointN(i)]);
        end
    else
        % define x line based on lowest and highest values and number of bins
        x_bin_start = linspace(min(DataOI(:,1)),max(DataOI(:,1))+0.1*max(DataOI(:,1)), p.Results.NumberOfBins+1);
    end

    for i=1:length(x_bin_start)-1
        % find value above a specific element of X data
        a=find((DataOI(:,1)>x_bin_start(i)));
        b=find((DataOI(:,1)<=x_bin_start(i+1)));
        % returns the data common to both A and B, with no repetitions. The middle part
        flag_Array(:,1)=DataOI(intersect(a,b),1);
        flag_Array(:,2)=DataOI(intersect(a,b),2);
        % build the data for the barplot
        BinMean=mean(flag_Array(:,2),'omitnan');
        BinMean_Norm=BinMean/size(flag_Array,1);
        BinSTD=std(flag_Array(:,2),'omitnan');
        % use setpoint as centers
        if ~isempty(p.Results.setpoints)
            BinCenetr_V=setpointN(i);
        else
            BinCenetr_V=mean(flag_Array(:,1),'omitnan');
        end
            
        outputme(i)=struct(...
            'BinStart',...
            x_bin_start(i),...
            'BinEnd',...
            x_bin_start(i+1),...
            'BinCenter',...
            BinCenetr_V,...
            'MeanBin',...
            BinMean,...
            'MeanBinNormPixels',...
            BinMean_Norm,...
            'STDBin',...
            BinSTD,....
            'Array',...
            flag_Array); %#ok<AGROW>
        
        clearvars flag_Array a b c BinMean BinSTD BinCenetr_V BinMean_Norm
    end
    
    x_VDH_B=NaN(1,size(outputme,2));
    y_VDH_B=NaN(1,size(outputme,2));
    stde_VDH_B=NaN(1,size(outputme,2));
    
    for i=1:size(outputme,2)
        x_VDH_B(i)=outputme(i).BinCenter*p.Results.xpar;
        y_VDH_B(i)=outputme(i).MeanBin*p.Results.ypar;
        stde_VDH_B(i)=outputme(i).STDBin*p.Results.ypar;
    end
     
    ftmp=figure('Visible','off'); hold on
    try
        errorbar(x_VDH_B,y_VDH_B,stde_VDH_B,'MarkerFaceColor',sprintf('%c',p.Results.MCoulor),'MarkerEdgeColor',sprintf('%c',p.Results.MCoulor),'Marker',sprintf('%c',p.Results.MType));
    catch
        errorbar(x_VDH_B,y_VDH_B,stde_VDH_B,'ok','MarkerFaceColor',[0 0 0]);
    end
    if(~isempty(p.Results.Xlimit))
        xlim(p.Results.Xlimit)
    else
        xlim padded
    end
    if(~isempty(p.Results.Ylimit))
        xlim(p.Results.Ylimit)
    else
        xlim padded
    end    
    grid on, grid minor
    xlabel(p.Results.XAxL,'FontSize',15);
    ylabel(p.Results.YAyL,'FontSize',15);
    if (~isempty(p.Results.FigTitle))
        title(p.Results.FigTitle,'FontSize',20);
    end    
    objInSecondMonitor(secondMonitorMain,ftmp);
    saveas(ftmp,sprintf('%s/tiffImages/resultA10_end_%d_%s',newFolder,p.Results.NumFig,p.Results.FigFilename),'tif')
    saveas(ftmp,sprintf('%s/figImages/resultA10_end_%d_%s',newFolder,p.Results.NumFig,p.Results.FigFilename))
end