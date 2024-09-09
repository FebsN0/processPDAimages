function varargout=A11_correlation_AFM_BF(AFM_data,AFM_IO_Padded,setpoints,secondMonitorMain,newFolder,varargin)
    close all
    
    p=inputParser();
    addRequired(p,'AFM_data');
    addRequired(p,'AFM_IO_Padded')
    argName = 'TRITIC_before';      defaultVal = [];     addParameter(p,argName,defaultVal, @(x) ismatrix(x));
    argName = 'TRITIC_after';       defaultVal = [];     addParameter(p,argName,defaultVal, @(x) ismatrix(x));
    argName = 'Silent';             defaultVal = 'Yes';  addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'afterHeating';             defaultVal = 'No';  addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));

    parse(p,AFM_data,AFM_IO_Padded,varargin{:});
    clearvars argName defaultVal
    
    if(strcmp(p.Results.Silent,'Yes')); SeeMe=0; else, SeeMe=1; end
    % in case one of the two is missing, substract by min value
    if strcmp(p.Results.afterHeating,'Yes')
        flag_heat=true;
    else
        flag_heat=false;
    end
    
    flag_onlyAFM=false;
    if ~flag_heat && (~isempty(p.Results.TRITIC_before) && ~isempty(p.Results.TRITIC_after))
        % process data before heating : show the pre and post AFM/Fluorescence
        BF_Before=p.Results.TRITIC_before;
        BF_After=p.Results.TRITIC_after;
        % Determination of delta fluorescence:
        Delta = BF_After-BF_Before;
    elseif flag_heat && (xor(isempty(p.Results.TRITIC_before),isempty(p.Results.TRITIC_after)))     % at least one of the two fluorescence data must be provided
        % Calc the fluorescence delta by removing the minimum value
        if isempty(p.Results.TRITIC_before)
            BF_After=p.Results.TRITIC_after;
            Delta=BF_After-min(min(BF_After));
        else            
            BF_Before=p.Results.TRITIC_before;
            Delta=BF_Before-min(min(BF_Before));
        end
    else
        % show anything except those related with fluorescence. I.e. only AFM data
        flag_onlyAFM=true;
    end



    % find the idx of Height and Lateral/vertical Deflection in Trace Mode
    idx_LD = strcmp({AFM_data.Channel_name},'Lateral Deflection') & strcmp({AFM_data.Trace_type},'Trace');
    idx_H = strcmp({AFM_data.Channel_name},'Height (measured)');
    idx_VD =  strcmp({AFM_data.Channel_name},'Vertical Deflection') & strcmp({AFM_data.Trace_type},'Trace');
 

    if ~flag_onlyAFM
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
    
        plotSave2(SeeMe,Delta_glass,Delta_ADJ,'Tritic glass','Tritic whole','Fluorescence emission','resultA11_1_FluorescenceGlassPDA.tif',secondMonitorMain,newFolder)
    end
    % Identification of borders from the binarised Height image
    AFM_IO_Padded_Borders=AFM_IO_Padded;
    AFM_IO_Padded_Borders(AFM_IO_Padded_Borders<=0)=nan;
    AFM_IO_Borders= edge(AFM_IO_Padded_Borders,'approxcanny');
    se = strel('square',5); % this value results a border of 3! pixels in the later images(as the outer dilation (2px) is gonna be subtracted later)
    AFM_IO_Borders_Grow=imdilate(AFM_IO_Borders,se); 
    
    plotSave1(SeeMe,AFM_IO_Borders_Grow,'Borders','resultA11_2_Borders.tif',secondMonitorMain,newFolder)

    % Elaboration of Height to extract inner and border regions
    AFM_Height_Border=AFM_data(idx_H).AFM_Padded;
    AFM_Height_Border(AFM_IO_Padded==0)=nan;
    AFM_Height_Border(AFM_IO_Borders_Grow==0)=nan; 
    AFM_Height_Border(AFM_Height_Border<=0)=nan;
    
    AFM_Height_Inner=AFM_data(idx_H).AFM_Padded;
    AFM_Height_Inner(AFM_IO_Padded==0)=nan; 
    AFM_Height_Inner(AFM_IO_Borders_Grow==1)=nan;
    AFM_Height_Inner(AFM_Height_Inner<=0)=nan;
    
    plotSave2(SeeMe,AFM_Height_Border*1e6,AFM_Height_Inner*1e6,'AFM Height Border','AFM Height Inner',sprintf('height (\x03bcm)'),'resultA11_3_BorderAndInner_AFM_Height.tif',secondMonitorMain,newFolder)

    % Elaboration of LD to extract inner and border regions
    AFM_LD_Border=AFM_data(idx_LD).AFM_Padded;
    AFM_LD_Border(AFM_IO_Padded==0)=nan; 
    AFM_LD_Border(AFM_IO_Borders_Grow==0)=nan;
    AFM_LD_Border(AFM_LD_Border<=0)=nan;

    AFM_LD_Inner=AFM_data(idx_LD).AFM_Padded;
    AFM_LD_Inner(AFM_IO_Padded==0)=nan;
    AFM_LD_Inner(AFM_IO_Borders_Grow==1)=nan;
    AFM_LD_Inner(AFM_LD_Inner<=0)=nan; 

    plotSave2(SeeMe,AFM_LD_Border*1e9,AFM_LD_Inner*1e9,'AFM LD Border','AFM LD Inner','Force [nN]','resultA11_4_BorderAndInner_AFM_LateralDeflection.tif',secondMonitorMain,newFolder)

    % Elaboration of VD to extract inner and border regions
    AFM_VD_Border=AFM_data(idx_VD).AFM_Padded;
    AFM_VD_Border(AFM_IO_Padded==0)=nan; 
    AFM_VD_Border(AFM_IO_Borders_Grow==0)=nan;  
    AFM_VD_Border(AFM_VD_Border<=0)=nan;
    
    AFM_VD_Inner=AFM_data(idx_VD).AFM_Padded;
    AFM_VD_Inner(AFM_IO_Padded==0)=nan; 
    AFM_VD_Inner(AFM_IO_Borders_Grow==1)=nan;  
    AFM_VD_Inner(AFM_VD_Inner<=0)=nan;

    plotSave2(SeeMe,AFM_VD_Border*1e9,AFM_VD_Inner*1e9,'AFM VD Border','AFM VD Inner','Force [nN]','resultA11_5_BorderAndInner_AFM_VerticalDeflection.tif',secondMonitorMain,newFolder)

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
    if ~flag_heat
        TRITIC_Border_Delta=Delta_ADJ; 
        TRITIC_Border_Delta(isnan(AFM_LD_Border))=nan; 
        TRITIC_Inner_Delta=Delta_ADJ; 
        TRITIC_Inner_Delta(isnan(AFM_LD_Inner))=nan;
        plotSave2(SeeMe,TRITIC_Border_Delta,TRITIC_Inner_Delta,'Tritic Border Delta','Tritic Inner Delta','Fluorescence emission','resultA11_6_BorderAndInner_TRITIC_DELTA.tif',secondMonitorMain,newFolder)
    end
    close all   

        
    
    if ~flag_heat
        % 7 - HEIGHT VS LATERAL FORCE
        dataPlot_Height_LD=A11_feature_CDiB(AFM_data(idx_H).Padded_masked(:),AFM_data(idx_LD).AFM_Padded(:),secondMonitorMain,newFolder,'xpar',1e6,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL',sprintf('Feature height (\x03bcm)'),'FigTitle','Height VS Lateral Deflection','NumFig',1);
        %[BC_H_Vs_LD_Border]=A11_feature_CDiB(AFM_Height_Border(:),AFM_LD_Border(:),secondMonitorMain,newFolder,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Feature height (nm)','FigTitle','LD Vs Height Border','NumFig',1);
        %[BC_H_Vs_LD_Inner]=A11_feature_CDiB(AFM_Height_Inner(:),AFM_LD_Inner(:),secondMonitorMain,newFolder,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Feature height (nm)','FigTitle','LD Vs Height Inner','NumFig',1);
        varargout{1}=dataPlot_Height_LD;
    end

    if ~flag_onlyAFM
        % 8 - HEIGHT VS FLUORESCENCE INCREASE
        dataPlot_Height_FLUO=A11_feature_CDiB(AFM_data(idx_H).Padded_masked(:),Delta_ADJ(:),secondMonitorMain,newFolder,'xpar',1e6,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL',sprintf('Feature height (\x03bcm)'),'FigTitle','Height Vs Fluorescence increase','NumFig',2);
        %[BC_Height_Border_Vs_Delta2ADJ_Border]=A11_feature_CDiB(AFM_Height_Border(:),TRITIC_Border_Delta(:),secondMonitorMain,newFolder,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Feature height (nm)','FigTitle','Height Vs Fluorescence increase (borders)','NumFig',2);
        %[BC_Height_Inner_Vs_Delta2ADJ_Inner]=A11_feature_CDiB(AFM_Height_Inner(:),TRITIC_Inner_Delta(:),secondMonitorMain,newFolder,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Feature height (nm)','FigTitle','Height Vs Fluorescence increase (inner regions)','NumFig',2);
        varargout{2}=dataPlot_Height_FLUO;
        
        if ~flag_heat
            % 9 - LATERAL DEFLECTION VS FLUORESCENCE INCREASE
            dataPlot_LD_FLUO_padMask=A11_feature_CDiB(AFM_data(idx_LD).Padded_masked(:),Delta_ADJ(:),secondMonitorMain,newFolder,'NumberOfBins',2500,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Lateral Force (only PDA) (nN)','FigTitle','LD (PDA) Vs Fluorescence increase','NumFig',3);
            %A11_feature_fittingResults(AFM_data(idx_LD).Padded_masked(:),Delta_ADJ(:),secondMonitorMain,newFolder)
            %LDmasked_VS_delta
            varargout{3}=dataPlot_LD_FLUO_padMask;
        
            dataPlot_LD_FLUO=A11_feature_CDiB(AFM_data(idx_LD).AFM_Padded(:),Delta_ADJ(:),secondMonitorMain,newFolder,'NumberOfBins',2500,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Lateral Force (nN)','FigTitle','LD Vs Fluorescence increase','NumFig',3);
            %[BC_LD_Vs_Delta2ADJ_Border]=A11_feature_CDiB(AFM_LD_Border(:),TRITIC_Border_Delta(:),secondMonitorMain,newFolder,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Lateral Force (nN)','FigTitle','LD Vs Fluorescence increase (borders)','NumFig',3);
            %[BC_LD_Vs_Delta2ADJ_Inner]=A11_feature_CDiB(AFM_LD_Inner(:),TRITIC_Inner_Delta(:),secondMonitorMain,newFolder,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Lateral Force (nN)','FigTitle','LD Vs Fluorescence increase (inner regions)','NumFig',3);
            varargout{4}=dataPlot_LD_FLUO;
                   
            % VERTICAL FORCE VS FLUORESCENCE INCREASE
            dataPlot_VD_FLUO=A11_feature_CDiB(AFM_data(idx_VD).AFM_Padded(:),Delta_ADJ(:),secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','(Measured) Vertical Force (nN)','FigTitle','VD Vs Fluorescence increase','NumFig',5); 
            %[BC_VD_Vs_Delta2ADJ_Border]=A11_feature_CDiB(AFM_VD_Border(:),TRITIC_Border_Delta(:),secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Vertical Force (nN)','FigTitle','VD Vs Fluorescence increase (borders)','NumFig',5);
            %[BC_VD_Vs_Delta2ADJ_Inner]=A11_feature_CDiB(AFM_VD_Inner(:),TRITIC_Inner_Delta(:),secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'ypar',1,'YAyL','Absolute fluorescence increase (A.U.)','XAxL','Vertical Force (nN)','FigTitle','VD Vs Fluorescence increase (inner regions)','NumFig',5);
            varargout{5}=dataPlot_VD_FLUO;
        end
    end
    if ~flag_heat
        % VERTICAL FORCE VS LATERAL FORCE
        dataPlot_VD_LD=A11_feature_CDiB(AFM_data(idx_VD).AFM_Padded(:),AFM_data(idx_LD).AFM_Padded(:),secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','(Measured) Vertical Force (nN)','FigTitle','LD Vs VD','NumFig',4);
        %[BC_VD_Vs_LD_Border]=A11_feature_CDiB(AFM_VD_Border(:),AFM_LD_Border(:),secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Vertical Force (nN)','FigTitle','LD Vs VD Border','NumFig',4);
        %[BC_VD_Vs_LD_Inner]=A11_feature_CDiB(AFM_VD_Inner(:),AFM_LD_Inner(:),secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Vertical Force (nN)','FigTitle','LD Vs VD Inner','NumFig',4);
        varargout{6}=dataPlot_VD_LD;
    end
end


function plotSave1(SeeMe,dataIMG,nameTitle,nameFigure,secondMonitorMain,newFolder)
    if SeeMe
        ftmp=figure('Visible','on');
    else
        ftmp=figure('Visible','off');
    end
    imagesc(dataIMG); title(nameTitle,'FontSize',18)
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,ftmp); end
    saveas(ftmp,sprintf('%s/%s',newFolder,nameFigure))
end

function plotSave2(SeeMe,dataIMG1,dataIMG2,nameTitle1,nameTitle2,nameColBar,nameFigure,secondMonitorMain,newFolder)
    if SeeMe
        ftmp=figure('Visible','on');
    else
        ftmp=figure('Visible','off');
    end
    sf1=subplot(121); h=imagesc(dataIMG1); title(nameTitle1,'FontSize',18)
    set(h, 'AlphaData', ~isnan(h.CData))
    c=colorbar; c.Label.String = nameColBar; c.FontSize  =15;
    axis(sf1,'equal'), xlim tight, ylim tight
    
    sf2=subplot(122); h=imagesc(dataIMG2); title(nameTitle2,'FontSize',18)
    set(h, 'AlphaData', ~isnan(h.CData))
    c=colorbar; c.Label.String = nameColBar; c.FontSize =15;
    axis(sf2,'equal'), xlim tight, ylim tight

    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,ftmp); end
    saveas(ftmp,sprintf('%s/%s.tif',newFolder,nameFigure))
end