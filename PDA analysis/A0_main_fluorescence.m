%%%%%%%%%%%%%%%
%%%     CODE TO EXTRACT THE SLOPE OF HEIGHT-FLUORESCENCE DEPENDENCY
%%%%%%%%%%%%%%


clc, clear, close all

secondMonitorMain=objInSecondMonitor;
m=1;
while true
    % upload .jpk files. If more than one and if from same experiment in which setpoint is changed, then assembly.
    [AFM_A4_HeightFittedMasked,AFM_height_IO,metaData_AFM,newFolder,setpoints]=A1_openANDassembly_JPK(secondMonitorMain);
    
    % Open Brightfield image and the TRITIC after sample heating and AFM scanning 
    [fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the BrightField image');
    [BF_Mic_Image,~,metaData_BF]=A7_open_ND2(fullfile(filePathData,fileName)); 
    f1=figure;
    imshow(imadjust(BF_Mic_Image)), title('BrightField - original','FontSize',17)
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
    saveas(f1,sprintf('%s/resultA8_0_BrightField.tif',newFolder))
    
    [fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the TRITIC after heating',filePathData);
    [Tritic_Mic_Image]=A7_open_ND2(fullfile(filePathData,fileName)); 
    f2=figure;
    imshow(imadjust(Tritic_Mic_Image)), title('TRITIC after heating','FontSize',17)
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2); end
    saveas(f2,sprintf('%s/resultA8_0_TRITIC_after_heating.tif',newFolder))
    close all
    
    % Align the Brightfield to TRITIC
    while true
        BF_Mic_Image_aligned=A8_limited_registration(BF_Mic_Image,Tritic_Mic_Image,newFolder,secondMonitorMain,'Brightfield','Yes','Moving','Yes');
        if getValidAnswer('Satisfied of the alignment?','',{'y','n'}) == 1
            break
        end
    end
    
    uiwait(msgbox('Click to continue',''));
    close all
    clear f1 f2 question options choice fileName BF_Mic_Image
    
    
    % Produce the binary IO of Brightfield
    [BF_Mic_Image_IO,~,Tritic_Mic_Image,~]=A9_Mic_to_Binary(BF_Mic_Image_aligned,secondMonitorMain,newFolder,'TRITIC_after',Tritic_Mic_Image); 
    clear BF_Mic_Image_aligned
    
    % Align AFM to BF and extract the coordinates for alighnment to be transferred to the other data
    [AFM_IO_sizeOpt,AFM_A10_IO_padded_sizeBF,AFM_A10_data_optAlignment,results_AFM_BF_aligment]=A10_alignment_AFM_Microscope(BF_Mic_Image_IO,metaData_BF,AFM_height_IO,metaData_AFM,AFM_A4_HeightFittedMasked,newFolder,secondMonitorMain,'Margin',70);
    clear AFM_height_IO AFM_LatDeflecFitted
    
    % correlation FLUORESCENCE AND AFM DATA
    [~,results_Height_fluo]=A11_correlation_AFM_BF(AFM_A10_data_optAlignment,AFM_A10_IO_padded_sizeBF,setpoints,secondMonitorMain,newFolder,'TRITIC_after',Tritic_Mic_Image,'afterHeating','Yes');
    close all
    % select the end point in which create the curve fitting
    [xData_1, yData_1] = prepareCurveData( vertcat(results_Height_fluo.BinCenter) , vertcat(results_Height_fluo.MeanBin) );
    plot(xData_1, yData_1)
    closest_indices = selectRangeGInput(1,1,xData_1, yData_1);
    xData_1=xData_1(1:closest_indices);
    yData_1=yData_1(1:closest_indices);
    
    % Set up fittype and options.
    ft = fittype( 'poly1' ); opts = fitoptions( 'Method', 'LinearLeastSquares' ); opts.Robust = 'LAR';
    % Fit model to data.
    fitresult = fit( xData_1, yData_1, ft, opts );
    hold on
    x=linspace(min(xData_1),max(xData_1),100);
    plot(x,x*fitresult.p1+fitresult.p2,'r')
    
    fitResults[1,m]=fitresult.p1;
    fitResults[2,m]=fitresult.p2;

title('Height VS Fluorescence')
ftmp= gcf;
objInSecondMonitor(secondMonitorMain,ftmp);
saveas(ftmp,sprintf('%s/A11_end_fluorescenceCorrelation',newFolder))

maxFluor=max(yData_1);


save(sprintf('%s\\dataResultsAfterHeating.mat',newFolder))