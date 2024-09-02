% Function to collect data into bins

function [outputme] = A11_feature_CDiB(X_Data,Y_Data,secondMonitorMain,newFolder,varargin)

    p=inputParser();
    argName = 'setpoints';      defaultVal = [];                                        addParameter(p,argName,defaultVal);
    argName = 'NumberOfBins';   defaultVal = 100;                                       addParameter(p,argName,defaultVal);
    argName = 'xpar';           defaultVal = 1e9;                                       addParameter(p,argName,defaultVal);
    argName = 'ypar';           defaultVal = 1e9;                                       addParameter(p,argName,defaultVal);
    argName = 'YAyL';           defaultVal = 'Relative Intensity Increase (A.U.)';      addParameter(p,argName,defaultVal);
    argName = 'XAxL';           defaultVal = 'Force (N)';                               addParameter(p,argName,defaultVal);
    argName = 'FigTitle';       defaultVal = '';                                        addParameter(p,argName,defaultVal);
    argName = 'Xlimit';         defaultVal = ([]);                                      addParameter(p,argName,defaultVal);
    argName = 'Ylimit';         defaultVal = ([]);                                      addParameter(p,argName,defaultVal);
    argName = 'MType';          defaultVal = 'o';                                       addParameter(p,argName,defaultVal);
    argName = 'MCoulor';        defaultVal = 'k';                                       addParameter(p,argName,defaultVal);
    argName = 'NumFig';         defaultVal = '';                                        addParameter(p,argName,defaultVal);

    parse(p,varargin{:});
    
    DataOI(:,1)=X_Data;
    DataOI(:,2)=Y_Data;
    clearvars X_Data Y_Data varargin
    
    DataOI(isnan(DataOI(:,1)),:)=[];
    DataOI(DataOI(:,1)<0,:)=[];
    DataOI(DataOI(:,2)<0,:)=[];
    
    % if setpoint is declared, then manage the plot using that
    if ~isempty(p.Results.setpoints)
        setN= p.Results.setpoints';
        x_bin_centers=zeros(length(setN)+1,1);
        x_bin_centers(1)= setN(1)-((setN(2)-setN(1))/2);       
        for i=2:length(setN)
            x_bin_centers(i)=mean([setN(i-1),setN(i)]);
        end
        x_bin_centers(length(setN)+1)=setN(end)+((setN(end)-setN(end-1))/2);
    else
        % define x line based on first and last elements and number of bins
        x_bin_centers = linspace(0,max(max(DataOI(:,1)))+0.1*max(max(DataOI(:,1))), p.Results.NumberOfBins);
    end
    outputme=struct();
    for i=1:length(x_bin_centers)-1
        % find value above a specific element of X data
        a=find((DataOI(:,1)>x_bin_centers(i)));
        b=find((DataOI(:,1)<=x_bin_centers(i+1)));
        % returns the data common to both A and B, with no repetitions. The middle part
        flag_Array(:,1)=DataOI(intersect(a,b),1);
        flag_Array(:,2)=DataOI(intersect(a,b),2);
        % build the data for the barplot
        BinMean=mean(flag_Array(:,2),'omitnan');
        BinSTD=std(flag_Array(:,2),'omitnan');
        BinCenetr_V=mean(flag_Array(:,1),'omitnan');
        BinMean_Norm=BinMean/size(flag_Array,1);
    
        outputme(i)=struct(...
            'BinStart',...
            x_bin_centers(i),...
            'BinEnd',...
            x_bin_centers(i+1),...
            'BinCenter',...
            BinCenetr_V,...
            'MeanBin',...
            BinMean,...
            'MeanBinNormPixels',...
            BinMean_Norm,...
            'STDBin',...
            BinSTD,....
            'Array',...
            flag_Array);
        
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
     
    ftmp=figure; hold on
    try
        errorbar(x_VDH_B,y_VDH_B,stde_VDH_B,'MarkerFaceColor',sprintf('%c',p.Results.MCoulor),'MarkerEdgeColor',sprintf('%c',p.Results.MCoulor),'Marker',sprintf('%c',p.Results.MType));
    catch
        errorbar(x_VDH_B,y_VDH_B,stde_VDH_B,'ok','MarkerFaceColor',[0 0 0]);
    end
    if(~isempty(p.Results.Xlimit))
        xlim(p.Results.Xlimit)
    end
    if(~isempty(p.Results.Ylimit))
        xlim(p.Results.Ylimit)
    end
    
    xlabel(p.Results.XAxL,'FontSize',15);
    ylabel(p.Results.YAyL,'FontSize',15);
    if (~isempty(p.Results.FigTitle))
        title(p.Results.FigTitle,'FontSize',20);
    end
    
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,ftmp); end
    saveas(ftmp,sprintf('%s/resultA11_end_%d_%s.fig',newFolder,p.Results.NumFig,p.Results.FigTitle))
    saveas(ftmp,sprintf('%s/resultA11_end_%d_%s.tiff',newFolder,p.Results.NumFig,p.Results.FigTitle))

end