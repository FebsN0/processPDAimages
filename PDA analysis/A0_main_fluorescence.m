%%%%%%%%%%%%%%%
%%%     CODE TO EXTRACT THE SLOPE OF HEIGHT-FLUORESCENCE DEPENDENCY FOR DIFFERENT SCANS
%%%%%%%%%%%%%%
%
%
% 
    % USE A SPECIFIC TIME EXPOSURE %

clc, clear, close all
colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k','#FF00FF','#00FF00'};

secondMonitorMain=objInSecondMonitor;
fmain=figure;
% upload .jpk files. If more than one and if from same experiment in which setpoint is changed, then assembly.
m=1;
maxScans=str2double(cell2mat(inputdlg('How many scans?')));
results_Height_fluo_allScans=cell(1,maxScans);
fitresult_allScans=cell(1,maxScans);
nameData=cell(1,maxScans);
answer=getValidAnswer('Choose an option','',{'Compare same AFM with different TRITIC exposure time','Compare different AFM with same TRITIC exposure time'});
if answer==1
    flagDifferentExposTime=true;
else
    flagDifferentExposTime=false;
end

while true
    [AFM_A4_HeightFittedMasked,AFM_height_IO,metaData_AFM,newFolder,setpoints]=A1_openANDassembly_JPK(secondMonitorMain,'saveFig','No');
    % Open Brightfield image and the TRITIC after sample heating and AFM scanning 
    [fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the BrightField image');
    [BF_Mic_Image,~,metaData_BF]=A7_open_ND2(fullfile(filePathData,fileName)); 
    f1=figure('Visible','off');
    imshow(imadjust(BF_Mic_Image)), title('BrightField - original','FontSize',17)
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
    saveas(f1,sprintf('%s/resultA8_0_BrightField.tif',newFolder))
    close(f1), clear f1


    while flagDifferentExposTime
        [fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the TRITIC after heating',filePathData);
        [Tritic_Mic_Image,~,metadataTRITIC]=A7_open_ND2(fullfile(filePathData,fileName));
        % extract time exposure information so the pictures will be properly tracked
        nameData{m}=sprintf('%dms',round(double(metadataTRITIC.ExposureTime)));
        f2=figure('Visible','off');
        imshow(imadjust(Tritic_Mic_Image))
        disp(char(nameData{m}))
        title(sprintf('TRITIC after heating - %s',char(nameData{m})),'FontSize',17)
        if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2); end
        saveas(f2,sprintf('%s/resultA8_0_TRITIC_after_heating_%s.tif',newFolder,char(nameData{m})))
        close(f2), clear f2
        
        % Align the Brightfield to TRITIC
        while true
            BF_Mic_Image_aligned=A8_limited_registration(BF_Mic_Image,Tritic_Mic_Image,newFolder,secondMonitorMain,'Brightfield','Yes','Moving','Yes','saveFig','No');
            answer=getValidAnswer('Satisfied of the alignment?','',{'y','n'});
            close gcf
            if answer
                break
            end      
        end
        % Produce the binary IO of Brightfield
        [BF_Mic_Image_IO,~,Tritic_Mic_Image_postA9,~]=A9_Mic_to_Binary(BF_Mic_Image_aligned,secondMonitorMain,newFolder,'TRITIC_after',Tritic_Mic_Image,'saveFig','No','Silent','Yes'); 
        
        % Align AFM to BF and extract the coordinates for alighnment to be transferred to the other data
        while true
            [~,AFM_A10_IO_padded_sizeBF,AFM_A10_data_optAlignment,~]=A10_alignment_AFM_Microscope(BF_Mic_Image_IO,metaData_BF,AFM_height_IO,metaData_AFM,AFM_A4_HeightFittedMasked,newFolder,secondMonitorMain,'Margin',70,'saveFig','No','Silent','Yes');
            if getValidAnswer('Satisfied of the alignment or restart?','',{'y','n'}) == 1
                break
            end
        end     
        
        % correlation FLUORESCENCE AND AFM DATA
        [~,~,results_Height_fluo,~,~,~,~,deltaADJ]=A11_correlation_AFM_BF(AFM_A10_data_optAlignment,AFM_A10_IO_padded_sizeBF,setpoints,secondMonitorMain,newFolder,'TRITIC_after',Tritic_Mic_Image_postA9,'afterHeating','Yes','TRITIC_expTime',char(nameData{m}));
        results_Height_fluo_allScans{m}=results_Height_fluo;

        % select the end point in which create the curve fitting
        [xData, yData] = prepareCurveData(vertcat(results_Height_fluo.BinCenter),vertcat(results_Height_fluo.MeanBin)); 
        uiwait(msgbox('Click on the plot to select the index for which the underlying values are considered',''));
        closest_indices = selectRangeGInput(1,1,xData*1e9, yData);

        close gcf
        
        % show distribution of delta to check saturation (last bar very high)
        deltaADJ=deltaADJ(:); deltaADJ=deltaADJ(~isnan(deltaADJ));
        fh=figure('Visible','off');
        histogram(deltaADJ)
        xlabel('Absolute fluorescence increase (A.U.)','FontSize',15)
        title(sprintf('Distribution Delta Fluorescence - %s',nameData{m}),'FontSize',15)
        objInSecondMonitor(secondMonitorMain,fh);
        saveas(fh,sprintf('%s/A12_deltaFluorescenceDistribution - %s.tiff',newFolder,char(nameData{m})))
        close(fh)

        figure(fmain)
        hold on
        plot(xData, yData,'*','Color',colors{m},'DisplayName',sprintf('Exp - %s',nameData{m}))
        xData=xData(1:closest_indices);
        yData=yData(1:closest_indices);
        
        % Set up fittype and options.
        ft = fittype( 'poly1' ); opts = fitoptions( 'Method', 'LinearLeastSquares' ); opts.Robust = 'LAR';
        % Fit model to data.
        fitresult = fit( xData, yData, ft, opts );
        fitresult_allScans{m}=fitresult;
        hold on
        x=linspace(min(xData),max(xData),100);
        plot(x,x*fitresult.p1+fitresult.p2,'Color',colors{m},'LineWidth',2,'DisplayName',sprintf('Fit   - %s',nameData{m}))
        m=m+1;
    
        if m>maxScans || ~strcmp(questdlg('Continue by changing only time exposure of fluorescence?','','Yes'),'Yes')
            break
        end
    end
    if flagDifferentExposTime
        break
    end    
end
%%
objInSecondMonitor(secondMonitorMain,fmain);

ylabel('Absolute fluorescence increase (A.U.)','FontSize',15)
xlabel('Feature height (nm)','FontSize',15)
title('Height Vs Fluorescence and Correlation ','FontSize',20)

% Create legend
legend1 = legend('Location','bestoutside','Fontsize',15);
saveas(fmain,sprintf('%s/A13_end_heighVSfluorescenceCorrelation.tiff',newFolder))

maxFluor=max(yData);
save(sprintf('%s\\dataResultsAfterHeating.mat',newFolder))