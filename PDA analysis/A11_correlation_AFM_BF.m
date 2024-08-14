function varargout = A11_correlation_AFM_BF(BF_Before,BF_After,AFM_IO_Padded,AFM_data)
    
    % find the idx of Height and Lateral/vertical Deflection in Trace Mode
    idx_LD = strcmp({AFM_data.Channel_name},'Lateral Deflection') & strcmp({AFM_data.Trace_type},'Trace');
    idx_H = strcmp({AFM_data.Channel_name},'Height (measured)');
    idx_VD =  strcmp({AFM_data.Channel_name},'Vertical Deflection') & strcmp({AFM_data.Trace_type},'Trace');
 
    % Determination of delta fluorescence:
    Delta = BF_After-BF_Before;
    % empty value in correspondence of crystal using AFM height I/O (value 1) from the previous
    % function (NOTE: AFM_IO_Padded has the same size as well the BF images original)
    Delta_glass=Delta;
    Delta_glass(AFM_IO_Padded==1)=nan;                          % remove crystal data
    Delta_glass(Delta<=0)=nan;
    Delta_glass(AFM_data(idx_LD).AFM_Padded==0)=nan;      % remove the data outise the AFM data
    % Intensity minimum in the glass region to be subtracted:
    Min_Delta_glass=min(min(Delta_glass,[],"omitnan"));
    % fix the fluorescence using the minimum value
    Delta_ADJ=Delta-Min_Delta_glass;
    Delta_ADJ(AFM_data(idx_LD).AFM_Padded==0)=nan;
    Delta_ADJ(Delta_ADJ<0 | ~isnan(Delta_glass))=nan;
    
    f1=figure('Visible','off');
    sf1=subplot(121); h=imagesc(Delta_glass); title('Tritic glass','FontSize',18)
    set(h, 'AlphaData', ~isnan(h.CData))
    c=colorbar; c.Label.String = 'Fluorescence'; c.FontSize  =15;
    axis(sf1,'equal'), xlim tight, ylim tight
    
    sf2=subplot(122); h=imagesc(Delta_ADJ); title('Tritic whole','FontSize',18)
    set(h, 'AlphaData', ~isnan(h.CData))
    c=colorbar; c.Label.String = 'Fluorescence'; c.FontSize =15;
    axis(sf2,'equal'), xlim tight, ylim tight
   
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
    saveas(f1,sprintf('%s/resultA11_1_FluorescenceGlassPDA.tif',newFolder))
    clear f1 sf1 sf2 Delta_glass
    
    % Identification of borders from the binarised Height image
    AFM_IO_Padded_Borders=AFM_IO_Padded;
    AFM_IO_Padded_Borders(AFM_IO_Padded_Borders<=0)=nan;
    AFM_IO_Borders= edge(AFM_IO_Padded_Borders,'approxcanny');
    se = strel('square',5); % this value results a border of 3! pixels in the later images(as the outer dilation (2px) is gonna be subtracted later)
    AFM_IO_Borders_Grow=imdilate(AFM_IO_Borders,se); 
    f2=figure('Visible','off');
    imagesc(AFM_IO_Borders_Grow); title('Borders','FontSize',18)
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2); end
    saveas(f2,sprintf('%s/resultA11_2_Borders.tif',newFolder))
    close all, clear f2 se

    % Elaboration of Height to extract inner and border regions
    AFM_Height_Border=AFM_data(idx_H).AFM_Padded;
    AFM_Height_Border(AFM_IO_Padded==0)=nan;
    AFM_Height_Border(AFM_IO_Borders_Grow==0)=nan; 
    AFM_Height_Border(AFM_Height_Border<=0)=nan;
    
    AFM_Height_Inner=AFM_data(idx_H).AFM_Padded;
    AFM_Height_Inner(AFM_IO_Padded==0)=nan; 
    AFM_Height_Inner(AFM_IO_Borders_Grow==1)=nan;
    AFM_Height_Inner(AFM_Height_Inner<=0)=nan;
    
    f3=figure('Visible','off');
    sf1=subplot(121); h=imagesc(AFM_Height_Border); title('AFM Height Border')
    c=colorbar; c.Label.String = 'Fluorescence'; c.FontSize =15;
    set(h, 'AlphaData', ~isnan(h.CData))
    axis(sf1,'equal'), xlim tight, ylim tight
    sf2=subplot(122); h=imagesc(AFM_Height_Inner); title('AFM Height Inner')
    c=colorbar; c.Label.String = 'Fluorescence'; c.FontSize =15;
    set(h, 'AlphaData', ~isnan(h.CData))
    axis(sf2,'equal'), xlim tight, ylim tight
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f3); end
    saveas(f3,sprintf('%s/resultA11_3_BorderAndInner_AFM_Height.tif',newFolder))
    clear f2 sf1 sf2

    % Elaboration of LD to extract inner and border regions
    AFM_LD_Border=AFM_data(idx_LD).AFM_Padded;
    AFM_LD_Border(AFM_IO_Padded==0)=nan; 
    AFM_LD_Border(AFM_IO_Borders_Grow==0)=nan;
    AFM_LD_Border(AFM_LD_Border<=0)=nan;
    

    AFM_LD_Inner=AFM_data(idx_LD).AFM_Padded;
    AFM_LD_Inner(AFM_IO_Padded==0)=nan;
    AFM_LD_Inner(AFM_IO_Borders_Grow==1)=nan;
    AFM_LD_Inner(AFM_LD_Inner<=0)=nan; 
    
    f4=figure('Visible','off');
    sf1=subplot(121); 
    h=imagesc(AFM_LD_Border); colormap parula, title('AFM LD Border')
    set(h, 'AlphaData', ~isnan(h.CData))
    c=colorbar; c.Label.String = 'Fluorescence'; c.FontSize =15;
    axis(sf1,'equal'), xlim tight, ylim tight
    sf2=subplot(122);
    h=imagesc(AFM_LD_Inner); colormap parula, title('AFM LD Inner')
    set(h, 'AlphaData', ~isnan(h.CData))
    c=colorbar; c.Label.String = 'Fluorescence'; c.FontSize =15;
    axis(sf2,'equal'), xlim tight, ylim tight
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f4); end
    saveas(f4,sprintf('%s/resultA11_4_BorderAndInner_AFM_LateralDeflection.tif',newFolder)) 

    % Elaboration of VD to extract inner and border regions
    AFM_VD_Border=AFM_data(idx_VD).AFM_Padded;
    AFM_VD_Border(AFM_IO_Padded==0)=nan; 
    AFM_VD_Border(AFM_IO_Borders_Grow==0)=nan;  
    AFM_VD_Border(AFM_VD_Border<=0)=nan;
    
    AFM_VD_Inner=AFM_data(idx_VD).AFM_Padded;
    AFM_VD_Inner(AFM_IO_Padded==0)=nan; 
    AFM_VD_Inner(AFM_IO_Borders_Grow==1)=nan;  
    AFM_VD_Inner(AFM_VD_Inner<=0)=nan;
    
    f5=figure('Visible','off');
    sf1=subplot(121); h=imagesc(AFM_VD_Border); title('AFM VD Border')
    set(h, 'AlphaData', ~isnan(h.CData))
    c=colorbar; c.Label.String = 'Fluorescence'; c.FontSize =15;
    axis(sf1,'equal'), xlim tight, ylim tight
    sf2=subplot(122); h=imagesc(AFM_VD_Inner); title('AFM VD Inner')
    set(h, 'AlphaData', ~isnan(h.CData))
    c=colorbar; c.Label.String = 'Fluorescence'; c.FontSize =15;
    axis(sf2,'equal'), xlim tight, ylim tight
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f5); end
    saveas(f5,sprintf('%s/resultA11_5_BorderAndInner_AFM_LateralDeflection.tif',newFolder)) 

    % Remove glass regions from the big AFM_Padded Height and LD and VD AFM images
    AFM_data(idx_LD).Padded_masked_glass=AFM_data(idx_LD).AFM_Padded;
    AFM_data(idx_LD).Padded_masked_glass(AFM_IO_Padded==1)=nan;
    AFM_data(idx_LD).Padded_masked_glass(AFM_data(idx_LD).AFM_Padded<=0)=nan; 
    
    AFM_data(idx_LD).Padded_masked=AFM_data(idx_LD).AFM_Padded;
    AFM_data(idx_LD).Padded_masked(~isnan(AFM_data(idx_LD).Padded_masked_glass))=nan; % opposite of masked_glass
    AFM_data(idx_LD).Padded_masked(AFM_data(idx_LD).AFM_Padded<=0)=nan;
    
    AFM_data(idx_H).Padded_masked_glass=AFM_data(idx_H).AFM_Padded;
    AFM_data(idx_H).Padded_masked_glass(AFM_IO_Padded==1)=nan;
    AFM_data(idx_H).Padded_masked_glass(AFM_data(idx_H).AFM_Padded<=0)=nan;
    
    AFM_data(idx_H).Padded_masked=AFM_data(idx_H).AFM_Padded;
    AFM_data(idx_H).Padded_masked(~isnan(AFM_data(idx_H).Padded_masked_glass))=nan;
    AFM_data(idx_H).Padded_masked(AFM_data(idx_H).AFM_Padded<=0)=nan;
    
    AFM_data(idx_VD).Padded_masked_glass=AFM_data(idx_VD).AFM_Padded;
    AFM_data(idx_VD).Padded_masked_glass(AFM_IO_Padded==1)=nan;
    AFM_data(idx_VD).Padded_masked_glass(AFM_data(idx_VD).AFM_Padded<=0)=nan; 
    
    AFM_data(idx_VD).Padded_masked=AFM_data(idx_VD).AFM_Padded;
    AFM_data(idx_VD).Padded_masked(~isnan(AFM_data(idx_VD).Padded_masked_glass))=nan;
    AFM_data(idx_VD).Padded_masked(AFM_data(idx_VD).AFM_Padded<=0)=nan;    

    % Elaboration of Fluorescent Images to extract inner and border regions
    TRITIC_Border_Delta=Delta_ADJ; 
    TRITIC_Border_Delta(isnan(AFM_LD_Border))=nan; 
    TRITIC_Inner_Delta=Delta_ADJ; 
    TRITIC_Inner_Delta(isnan(AFM_LD_Inner))=nan;
    
    f6=figure('Visible','off');
    sf1=subplot(121); h=imagesc(TRITIC_Border_Delta); title('Tritic Border Delta')
    set(h, 'AlphaData', ~isnan(h.CData))
    c=colorbar; c.Label.String = 'Fluorescence'; c.FontSize =15;
    axis(sf1,'equal'), xlim tight, ylim tight
    sf2=subplot(122); h=imagesc(TRITIC_Inner_Delta); title('Tritic Inner Delta')
    set(h, 'AlphaData', ~isnan(h.CData))
    c=colorbar; c.Label.String = 'Fluorescence'; c.FontSize =15;
    axis(sf2,'equal'), xlim tight, ylim tight
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f6); end
    saveas(f6,sprintf('%s/resultA11_6_BorderAndInner_AFM_LateralDeflection.tif',newFolder)) 



    % CONTINUE
    % HEIGHT VS LATERAL FORCE
    [~]=A11_feature_CDiB(AFM_data(idx_H).Padded_masked(:),AFM_data(idx_LD).AFM_Padded(:),'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Feature height (nm)','FigTitle','LD Vs Height');
    %[BC_H_Vs_LD_Border]=A11_feature_CDiB(AFM_Height_Border(:),AFM_LD_Border(:),'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Feature height (nm)','FigTitle','LD Vs Height Border');
    %[BC_H_Vs_LD_Inner]=A11_feature_CDiB(AFM_Height_Inner(:),AFM_LD_Inner(:),'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Feature height (nm)','FigTitle','LD Vs Height Inner');
    
    % HEIGHT VS FLUORESCENCE INCREASE
    [~]=A11_feature_CDiB(AFM_data(idx_H).Padded_masked(:),Delta_ADJ(:),'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Feature height (nm)','FigTitle','Height Vs Fluorescence increase');
    %[BC_Height_Border_Vs_Delta2ADJ_Border]=A11_feature_CDiB(AFM_Height_Border(:),TRITIC_Border_Delta(:),'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Feature height (nm)','FigTitle','Height Vs Fluorescence increase (borders)');
    %[BC_Height_Inner_Vs_Delta2ADJ_Inner]=A11_feature_CDiB(AFM_Height_Inner(:),TRITIC_Inner_Delta(:),'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Feature height (nm)','FigTitle','Height Vs Fluorescence increase (inner regions)');
    
    [BC_LD_masked_Vs_Delta2ADJ]=A11_feature_CDiB(AFM_data(idx_LD).Padded_masked(:),Delta_ADJ(:),'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Lateral Force (only PDA) (nN)','FigTitle','LD (PDA) Vs Fluorescence increase');
    [BC_LD_Vs_Delta2ADJ]=A11_feature_CDiB(AFM_data(idx_LD).AFM_Padded(:),Delta_ADJ(:),'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Lateral Force (nN)','FigTitle','LD Vs Fluorescence increase');
    %[BC_LD_Vs_Delta2ADJ_Border]=A11_feature_CDiB(AFM_LD_Border(:),TRITIC_Border_Delta(:),'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Lateral Force (nN)','FigTitle','LD Vs Fluorescence increase (borders)');
    %[BC_LD_Vs_Delta2ADJ_Inner]=A11_feature_CDiB(AFM_LD_Inner(:),TRITIC_Inner_Delta(:),'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Lateral Force (nN)','FigTitle','LD Vs Fluorescence increase (inner regions)');
    
    [BC_VD_Vs_LD]=A11_feature_CDiB(AFM_data(idx_VD).Padded_masked(:),AFM_data(idx_LD).AFM_Padded(:),'setpoints',setpoints,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Vertical Force (nN)','FigTitle','LD Vs VD');
    %[BC_VD_Vs_LD_Border]=A11_feature_CDiB(AFM_VD_Border(:),AFM_LD_Border(:),'setpoints',setpoints,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Vertical Force (nN)','FigTitle','LD Vs VD Border');
    %[BC_VD_Vs_LD_Inner]=A11_feature_CDiB(AFM_VD_Inner(:),AFM_LD_Inner(:),'setpoints',setpoints,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Vertical Force (nN)','FigTitle','LD Vs VD Inner');
    
    [BC_VD_Vs_Delta2ADJ]=A11_feature_CDiB(AFM_data(idx_VD).AFM_Padded(:),Delta_ADJ(:),'setpoints',setpoints,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Vertical Force (nN)','FigTitle','VD Vs Fluorescence increase'); % added on 10.12.2019
    %[BC_VD_Vs_Delta2ADJ_Border]=A11_feature_CDiB(AFM_VD_Border(:),TRITIC_Border_Delta(:),'setpoints',setpoints,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Vertical Force (nN)','FigTitle','VD Vs Fluorescence increase (borders)');
    %[BC_VD_Vs_Delta2ADJ_Inner]=A11_feature_CDiB(AFM_VD_Inner(:),TRITIC_Inner_Delta(:),'setpoints',setpoints,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Vertical Force (nN)','FigTitle','VD Vs Fluorescence increase (inner regions)');

    varargout={};
end