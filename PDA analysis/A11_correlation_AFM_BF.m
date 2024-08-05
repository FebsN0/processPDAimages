% Determination of delta fluorescence:
Delta2=minus(Tritic_Mic_Image_After_Registered,Tritic_Mic_Image_Before);
Delta2_glass=Delta2;
Delta2_glass(AFM_IO_Padded==1)=nan;
Delta2_glass(Delta2<=0)=nan;
Delta2_glass(AFM_cropped_channels_Big(POI_LD).Padded==0)=nan;
% Intensity minimum in the glass region to be subtracted:
Min_Delta2_glass=nanmin(nanmin(Delta2_glass));
Avg_Delta2_glass=nanmean(nanmean(Delta2_glass));

Delta2_ADJ=minus(Delta2,Min_Delta2_glass);
Delta2_ADJ(AFM_cropped_channels_Big(POI_LD).Padded==0)=nan;
Delta2_ADJ(Delta2_ADJ<0)=nan;
Delta2_ADJ(~isnan(Delta2_glass))=nan;

% The same as Delta2_ADJ but with the glass background:
Delta3_ADJ=minus(Delta2,Min_Delta2_glass);
Delta3_ADJ(AFM_cropped_channels_Big(POI_LD).Padded==0)=nan;
Delta3_ADJ(Delta3_ADJ<0)=nan;

% Identification of borders from the binarised Height image
AFM_IO_Padded_Borders=AFM_IO_Padded;
AFM_IO_Padded_Borders(AFM_IO_Padded_Borders<=0)=nan;
AFM_IO_Borders= edge(AFM_IO_Padded_Borders,'approxcanny');
se = strel('square',5); % this value results a border of 3! pixels in the later images(as the outer dilation (2px) is gonna be subtracted later)
AFM_IO_Borders_Grow=imdilate(AFM_IO_Borders,se); 

% Elaboration of Height to extract inner and border regions

index_ch=find(strcmp({AFM_cropped_channels.Channel_name},'Height (measured)')==1);
POI_H=index_ch(1,find(ismember(find(strcmp({AFM_cropped_channels.Channel_name},'Height (measured)')==1),find(strcmp({AFM_cropped_channels.Trace_type},'Trace')==1))));

AFM_Height_BK=AFM_cropped_channels_Big(POI_H).Padded;
AFM_Height_BK(AFM_IO_Padded==1)=nan;
AFM_Height_BK(AFM_Height_BK<=0)=nan;
AVG_BK_AFM_Height=nanmean(nanmean(AFM_Height_BK));
Min_BK_AFM_Height=nanmin(nanmin(AFM_Height_BK));

AFM_Height_Border=AFM_cropped_channels_Big(POI_H).Padded;
AFM_Height_Border(AFM_IO_Padded==0)=nan; % the outer dilation of the border gets subtracted here
AFM_Height_Border(AFM_IO_Borders_Grow==0)=nan; 
%AFM_Height_Border=minus(AFM_Height_Border,AVG_BK_AFM_Height); %can be
%removed if EL_AFM_Masked is used for the height image 23012020
AFM_Height_Border(AFM_Height_Border<=0)=nan;

AFM_Height_Inner=AFM_cropped_channels_Big(POI_H).Padded;
AFM_Height_Inner(AFM_IO_Padded==0)=nan; 
AFM_Height_Inner(AFM_IO_Borders_Grow==1)=nan;
%AFM_Height_Inner=minus(AFM_Height_Inner,AVG_BK_AFM_Height); %can be
%removed if EL_AFM_Masked is used for the height image 23012020
AFM_Height_Inner(AFM_Height_Inner<=0)=nan;

% Elaboration of LD to extract inner and border regions

AFM_LD_Border=AFM_cropped_channels_Big(POI_LD).Padded;
AFM_LD_Border(AFM_IO_Padded==0)=nan; 
AFM_LD_Border(AFM_IO_Borders_Grow==0)=nan;
AFM_LD_Border(AFM_LD_Border<=0)=nan;

AFM_LD_Inner=AFM_cropped_channels_Big(POI_LD).Padded;
AFM_LD_Inner(AFM_IO_Padded==0)=nan;
AFM_LD_Inner(AFM_IO_Borders_Grow==1)=nan;
AFM_LD_Inner(AFM_LD_Inner<=0)=nan; 

% Remove glass regions from the big padded Height and LD AFM images

AFM_cropped_channels_Big(POI_LD).Padded_masked_glass=AFM_cropped_channels_Big(POI_LD).Padded;
AFM_cropped_channels_Big(POI_LD).Padded_masked_glass(AFM_IO_Padded==1)=nan;
AFM_cropped_channels_Big(POI_LD).Padded_masked_glass(AFM_cropped_channels_Big(POI_LD).Padded<=0)=nan; 

AFM_cropped_channels_Big(POI_LD).Padded_masked=AFM_cropped_channels_Big(POI_LD).Padded;
AFM_cropped_channels_Big(POI_LD).Padded_masked(~isnan(AFM_cropped_channels_Big(POI_LD).Padded_masked_glass))=nan;
AFM_cropped_channels_Big(POI_LD).Padded_masked(AFM_cropped_channels_Big(POI_LD).Padded<=0)=nan;

AFM_cropped_channels_Big(POI_H).Padded_masked_glass=AFM_cropped_channels_Big(POI_H).Padded;
AFM_cropped_channels_Big(POI_H).Padded_masked_glass(AFM_IO_Padded==1)=nan;
AFM_cropped_channels_Big(POI_H).Padded_masked_glass(AFM_cropped_channels_Big(POI_H).Padded<=0)=nan;

AFM_cropped_channels_Big(POI_H).Padded_masked=AFM_cropped_channels_Big(POI_H).Padded;
AFM_cropped_channels_Big(POI_H).Padded_masked(~isnan(AFM_cropped_channels_Big(POI_H).Padded_masked_glass))=nan;
AFM_cropped_channels_Big(POI_H).Padded_masked(AFM_cropped_channels_Big(POI_H).Padded<=0)=nan;

%AFM_cropped_channels_Big(POI_H).Padded_bgsub=minus(AFM_cropped_channels_Big(POI_H).Padded_masked,AVG_BK_AFM_Height);
%%removed on 23012020, no need with masked EL AFM heights
%AFM_cropped_channels_Big(POI_H).Padded_whole_bgsub=minus(AFM_cropped_channels_Big(POI_H).Padded,AVG_BK_AFM_Height);

AVG_Height_PDA=nanmean(nanmean(AFM_cropped_channels_Big(POI_H).Padded_masked)); 
AVG_Height_PDA_stdev=nanstd(nanstd(AFM_cropped_channels_Big(POI_H).Padded_masked));

index_ch=find(strcmp({AFM_cropped_channels.Channel_name},'Vertical Deflection')==1);
POI_VD=index_ch(1,find(ismember(find(strcmp({AFM_cropped_channels.Channel_name},'Vertical Deflection')==1),find(strcmp({AFM_cropped_channels.Trace_type},'Trace')==1))));

AFM_cropped_channels_Big(POI_VD).Padded_masked_glass=AFM_cropped_channels_Big(POI_VD).Padded;
AFM_cropped_channels_Big(POI_VD).Padded_masked_glass(AFM_IO_Padded==1)=nan;
AFM_cropped_channels_Big(POI_VD).Padded_masked_glass(AFM_cropped_channels_Big(POI_VD).Padded<=0)=nan; 

AFM_cropped_channels_Big(POI_VD).Padded_masked=AFM_cropped_channels_Big(POI_VD).Padded;
AFM_cropped_channels_Big(POI_VD).Padded_masked(~isnan(AFM_cropped_channels_Big(POI_VD).Padded_masked_glass))=nan;
AFM_cropped_channels_Big(POI_VD).Padded_masked(AFM_cropped_channels_Big(POI_VD).Padded<=0)=nan;


% Elaboration of VD to extract inner and border regions

index_ch=find(strcmp({AFM_cropped_channels.Channel_name},'Vertical Deflection')==1);
POI_VD=index_ch(1,find(ismember(find(strcmp({AFM_cropped_channels.Channel_name},'Vertical Deflection')==1),find(strcmp({AFM_cropped_channels.Trace_type},'Trace')==1))));

AFM_VD_Border=AFM_cropped_channels_Big(POI_VD).Padded;
AFM_VD_Border(AFM_IO_Padded==0)=nan; 
AFM_VD_Border(AFM_IO_Borders_Grow==0)=nan;  
AFM_VD_Border(AFM_VD_Border<=0)=nan;

AFM_VD_Inner=AFM_cropped_channels_Big(POI_VD).Padded;
AFM_VD_Inner(AFM_IO_Padded==0)=nan; 
AFM_VD_Inner(AFM_IO_Borders_Grow==1)=nan;  
AFM_VD_Inner(AFM_VD_Inner<=0)=nan;

% Elaboration of Fluorescent Images to extract inner and border regions

%TRITIC_Border_Percentage=Perc_ADJ;
%TRITIC_Border_Percentage(isnan(AFM_LD_Border))=nan; % modified to LD_border instead of Height_border
%TRITIC_Inner_Percentage=Perc_ADJ;
%TRITIC_Inner_Percentage(isnan(AFM_LD_Inner))=nan;

TRITIC_Border_Delta=Delta2_ADJ; 
TRITIC_Border_Delta(isnan(AFM_LD_Border))=nan; 
TRITIC_Inner_Delta=Delta2_ADJ; 
TRITIC_Inner_Delta(isnan(AFM_LD_Inner))=nan;

AFM_LD_Border2=AFM_LD_Border;
AFM_LD_Border2(isnan(AFM_LD_Border))=0;
AFM_LD_Inner2=AFM_LD_Inner;
AFM_LD_Inner2(isnan(AFM_LD_Inner))=0;

LD_All=plus(AFM_LD_Inner2,AFM_LD_Border2);
LD_All(LD_All==0)=nan;

% Display all images that are going to be used for plotting + need to be
% checked
figure,imagesc(Delta2_ADJ), title('Tritic whole'),colorbar 
figure,imagesc(Delta3_ADJ), title('Tritic whole with glass'),colorbar 
figure,imagesc(Delta2_glass), title('Tritic glass'),colorbar 
 
figure,imagesc(TRITIC_Border_Delta), title('Tritic Border Delta'),colorbar
figure,imagesc(TRITIC_Inner_Delta), title('Tritic Inner Delta'),colorbar

figure,imagesc(AFM_cropped_channels_Big(POI_LD).Padded), title ('AFM LD whole'),colorbar
figure,imagesc(AFM_cropped_channels_Big(POI_LD).Padded_masked), title ('AFM LD whole, no glass'),colorbar
figure,imagesc(AFM_cropped_channels_Big(POI_LD).Padded_masked_glass), title ('AFM LD glass'),colorbar

figure,imagesc(AFM_cropped_channels_Big(POI_H).Padded_masked), title ('AFM Height whole, no glass'),colorbar 
figure,imagesc(AFM_cropped_channels_Big(POI_VD).Padded_masked), title ('AFM VD whole, no glass'),colorbar
figure,imagesc(AFM_cropped_channels_Big(POI_VD).Padded), title ('AFM VD whole'),colorbar 

figure,imagesc(LD_All), title('LD All(inner+border)'),colorbar

figure,imagesc(AFM_LD_Border), title('AFM LD Border'),colorbar
figure,imagesc(AFM_LD_Inner), title('AFM LD Inner'),colorbar

figure,imagesc(AFM_VD_Border), title('AFM VD Border'),colorbar
figure,imagesc(AFM_VD_Inner), title('AFM VD Inner'),colorbar

figure,imagesc(AFM_Height_Border), title('AFM Height Border'),colorbar
figure,imagesc(AFM_Height_Inner), title('AFM Height Inner'),colorbar

% Correlation of entire AFM LD,VD and Height images with Fluorescence
% increase, the data is collected in bins 

[BC_Height_Vs_LD]=CDiB(AFM_cropped_channels_Big(POI_H).Padded_masked(:),AFM_cropped_channels_Big(POI_LD).Padded(:),'NumberOfBins',p.Results.NBins,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Feature height (nm)','FigTitle','LD Vs Height')
[BC_H_Vs_LD_Border]=CDiB(AFM_Height_Border(:),AFM_LD_Border(:),'NumberOfBins',p.Results.NBins,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Feature height (nm)','FigTitle','LD Vs Height Border');
[BC_H_Vs_LD_Inner]=CDiB(AFM_Height_Inner(:),AFM_LD_Inner(:),'NumberOfBins',p.Results.NBins,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Feature height (nm)','FigTitle','LD Vs Height Inner');

[BC_Height_Vs_Delta2ADJ]=CDiB(AFM_cropped_channels_Big(POI_H).Padded_masked(:),Delta2_ADJ(:),'NumberOfBins',p.Results.NBins,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Feature height (nm)','FigTitle','Height Vs Fluorescence increase');
[BC_Height_Border_Vs_Delta2ADJ_Border]=CDiB(AFM_Height_Border(:),TRITIC_Border_Delta(:),'NumberOfBins',p.Results.NBins,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Feature height (nm)','FigTitle','Height Vs Fluorescence increase (borders)');
[BC_Height_Inner_Vs_Delta2ADJ_Inner]=CDiB(AFM_Height_Inner(:),TRITIC_Inner_Delta(:),'NumberOfBins',p.Results.NBins,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Feature height (nm)','FigTitle','Height Vs Fluorescence increase (inner regions)');

[BC_LD_masked_Vs_Delta2ADJ]=CDiB(AFM_cropped_channels_Big(POI_LD).Padded_masked(:),Delta2_ADJ(:),'NumberOfBins',p.Results.NBins,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Lateral Force (only PDA) (nN)','FigTitle','LD (PDA) Vs Fluorescence increase');
[BC_LD_Vs_Delta2ADJ]=CDiB(AFM_cropped_channels_Big(POI_LD).Padded(:),Delta2_ADJ(:),'NumberOfBins',p.Results.NBins,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Lateral Force (nN)','FigTitle','LD Vs Fluorescence increase');
[BC_LD_Vs_Delta2ADJ_Border]=CDiB(AFM_LD_Border(:),TRITIC_Border_Delta(:),'NumberOfBins',p.Results.NBins,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Lateral Force (nN)','FigTitle','LD Vs Fluorescence increase (borders)');
[BC_LD_Vs_Delta2ADJ_Inner]=CDiB(AFM_LD_Inner(:),TRITIC_Inner_Delta(:),'NumberOfBins',p.Results.NBins,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Lateral Force (nN)','FigTitle','LD Vs Fluorescence increase (inner regions)');

[BC_VD_Vs_LD]=CDiB_VD(AFM_cropped_channels_Big(POI_VD).Padded_masked(:),AFM_cropped_channels_Big(POI_LD).Padded(:),'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Vertical Force (nN)','FigTitle','LD Vs VD');
[BC_VD_Vs_LD_Border]=CDiB_VD(AFM_VD_Border(:),AFM_LD_Border(:),'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Vertical Force (nN)','FigTitle','LD Vs VD Border');
[BC_VD_Vs_LD_Inner]=CDiB_VD(AFM_VD_Inner(:),AFM_LD_Inner(:),'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Vertical Force (nN)','FigTitle','LD Vs VD Inner');

[BC_VD_Vs_Delta2ADJ]=CDiB_VD(AFM_cropped_channels_Big(POI_VD).Padded(:),Delta2_ADJ(:),'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Vertical Force (nN)','FigTitle','VD Vs Fluorescence increase'); % added on 10.12.2019
[BC_VD_Vs_Delta2ADJ_Border]=CDiB_VD(AFM_VD_Border(:),TRITIC_Border_Delta(:),'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Vertical Force (nN)','FigTitle','VD Vs Fluorescence increase (borders)');
[BC_VD_Vs_Delta2ADJ_Inner]=CDiB_VD(AFM_VD_Inner(:),TRITIC_Inner_Delta(:),'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Vertical Force (nN)','FigTitle','VD Vs Fluorescence increase (inner regions)');
