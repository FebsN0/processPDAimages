% Function to collect data into bins

function [outputme] = A11_feature_CDiB(X_Data,Y_Data,varargin)

if(~isempty(varargin))
    if(size(varargin,2)==1)
        if(iscell(varargin{1,1}))
            varargin=vertcat(varargin{:});
        end
    end
end

p=inputParser();
argName = 'NumberOfBins';
defaultVal = 1000;
addOptional(p,argName,defaultVal);

argName = 'xpar'; %added on 12122019
defaultVal = 2e9;
addOptional(p,argName,defaultVal);

argName = 'ypar'; %added on 12122019
defaultVal = 2e9;
addOptional(p,argName,defaultVal);

argName = 'YAyL';
defaultVal = 'Relative Intensity Increase (A.U.)';
addOptional(p,argName,defaultVal);

argName = 'XAxL';
defaultVal = 'Force (N)';
addOptional(p,argName,defaultVal);

argName = 'FigTitle';
defaultVal = '';
addOptional(p,argName,defaultVal);

argName = 'Xlimit';
defaultVal = ([]);
addOptional(p,argName,defaultVal);

argName = 'Ylimit';
defaultVal = ([]);
addOptional(p,argName,defaultVal);

argName = 'MType';
defaultVal = 'o';
addOptional(p,argName,defaultVal);

argName = 'MCoulor';
defaultVal = 'k';
addOptional(p,argName,defaultVal);

parse(p,varargin{:});

DataOI(:,1)=X_Data;
DataOI(:,2)=Y_Data;

clearvars X_Data Y_Data varargin

DataOI(isnan(DataOI(:,1)),:)=[];
DataOI(DataOI(:,1)<0,:)=[];
DataOI(DataOI(:,2)<0,:)=[];

x_bin_centers = linspace(0,max(max(DataOI(:,1)))+0.1*max(max(DataOI(:,1))), p.Results.NumberOfBins);


% figure,hold on,...
%     haxb=gca;
for i=1:size(x_bin_centers,2)-1
    
    a=find((DataOI(:,1)>x_bin_centers(1,i)));
    b=find((DataOI(:,1)<=x_bin_centers(1,i+1)));
    c=intersect(a,b);
    flag_Array(:,1)=DataOI(intersect(a,b),1);
    flag_Array(:,2)=DataOI(intersect(a,b),2);
    BinMean=nanmean(flag_Array(:,2));
    BinSTD=nanstd(flag_Array(:,2));
    BinCenetr_V=nanmean([x_bin_centers(1,i);x_bin_centers(1,i+1)]);
    BinMean_Norm=BinMean/size(flag_Array,1);
    
    outputme(i)=struct(...
        'BinStart',...
        x_bin_centers(1,i),...
        'BinEnd',...
        x_bin_centers(1,i+1),...
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
    
%     plot(haxa,BinCenetr_V,BinMean,'or');
    %     errorbar(haxa,BinCenetr_V,BinMean,BinMean-BinSTD,BinMean+BinSTD,BinCenetr_V-x_bin_centers(1,i),x_bin_centers(1,i+1)-BinCenetr_V);
    

    
    %     plot(haxb,BinCenetr_V,BinMean_Norm,'ob');
    
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


figure,hold on,...
    haxa=gca;
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
xlabel(p.Results.XAxL);
ylabel(p.Results.YAyL);
if (~isempty(p.Results.FigTitle))
    title(p.Results.FigTitle);
end



end


% argName = 'Xlimit';
% defaultVal = ([]);
% addOptional(p,argName,defaultVal);
% 
% argName = 'Ylimit';
% defaultVal = ([]);
% addOptional(p,argName,defaultVal);
% 
% argName = 'MType';
% defaultVal = 'o';
% addOptional(p,argName,defaultVal);
% 
% argName = 'MColour';
% defaultVal = 'k';
% addOptional(p,argName,defaultVal);