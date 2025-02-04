% This function opens the AFM data previously created to calculate the background friction
% coefficient.
% 
%
%   method 1)  INPUT: background+PDA  ==>  masking lateral and vertical data using AFM_height_IO to ignore PDA regions
%
% The second method removes outliers considered as spike signals in correspondence with the PDA crystal's edges using
% in-built matlab function.
% Moreover, PIXEL REDUCTION is applied to make more robust the statistical calculation prior the outliers removal
% once found a segment (single background region between two PDA regions), depending on the window/pixel
% size, the edges will be "brutally" removed by zeroing (0:PDA-1:BK)
%   method 2a) INPUT: background+PDA  ==>  method 2 + REMOVAL OF OUTLIERS on single segments for each single fast
%                                          scan line
%   method 2b) INPUT: background+PDA  ==>  method 2 + REMOVAL OF OUTLIERS on connected segments for each single
%                                          fast scan line
%   method 2c) INPUT: background+PDA  ==>  method 2 + REMOVAL OF OUTLIERS on connected segments of each entire
%                                          section (in correspondence of same setpoint region)
%   
% INPUT:    1) AFM_scan (trace and retrace | height, lateral and vertical data, Hover Mode off)
%           2) metadata
%           3) AFM_height_IO (mask PDA-background 0/1 values)
%           4) secondMonitorMain
%           5) newFolder: path where store the results
%           5) choice: method 1 | method 2 | method 3 (three available options)
%
% OUTPUT:   resFrictionAllExp struct which contains
%           2) friction/slope value
%           3) offset value
%           4) force image cleared (depending on the method)
%           5) vertical force image cleared (depending on the method)
%           6) averaged values of fast scan lines of force used for the fitting
%           7) averaged values of fast scan lines of vertical force used for the fitting

function avg_fc=A5_featureFrictionCalc_method_1_2(AFM,metadata,mask,secondMonitorMain,newFolder,method,idxRemovedPortion,varargin)
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)
    flagWrongImage=false;
    % find the maximum setpoint
    maxSetpoint=max(metadata.SetP_N*1e9);
    % init the var where store the different coefficient frictions of any scan image and the cleared images
    % and averaged cleared vector
    resFriction=struct('slope',[],'offset',[],'metadata',[],'forceCleared',[],'vertCleared',[],'forceCleared_avg',[],'vertCleared_avg',[],'statsErrorPlot',[]);
    alpha=metadata.Alpha;
    % flip setpoint because high setpoint in the AFM data usually start from the left
    setpoints=flip(round(metadata.SetP_N*1e9));
    resFriction.metadata= metadata;
    % prepare the idx for each section depending on the size of each section stored in the metadata to better
    % distinguish and prepare the fit for each section data
    sectionSize=metadata.y_scan_pixels;
    idxSection=zeros(1,length(sectionSize));
    idxSection(1)=1; % first idx
    for i= 2:length(sectionSize)
        idxSection(i)= idxSection(i-1)+sectionSize(i);            
    end
    % extract data (lateral deflection Trace and Retrace, vertical deflection) and then mask (BK-PDA)
    % elementXelement ==> 
    %       1 (crystal)   => 0
    %       0 (BK)        => 1    
    Lateral_Trace   = (AFM(strcmpi([AFM.Channel_name],'Lateral Deflection') & strcmpi([AFM.Trace_type],'Trace')).AFM_image).*(~mask);
    Lateral_ReTrace = (AFM(strcmpi([AFM.Channel_name],'Lateral Deflection') & strcmpi([AFM.Trace_type],'ReTrace')).AFM_image).*(~mask);           
    Delta = (Lateral_Trace + Lateral_ReTrace) / 2;
    % Calc W (half-width loop)
    W = Lateral_Trace - Delta;
    vertical_Trace   = (AFM(strcmpi([AFM.Channel_name],'Vertical Deflection') & strcmpi([AFM.Trace_type],'Trace')).AFM_image).*(~mask);
    vertical_ReTrace = (AFM(strcmpi([AFM.Channel_name],'Vertical Deflection') & strcmpi([AFM.Trace_type],'ReTrace')).AFM_image).*(~mask);                                         
    % convert W into force (in Newton units) using alpha calibration factor and show results.
    force=W*alpha;
    % convert N into nN
    force=force*1e9;
    vertical_Trace=vertical_Trace*1e9;
    vertical_ReTrace=vertical_ReTrace*1e9;
        
    % apply indipently of the used method different cleaning outliers steps
    %   first clearing: filter out anomalies among vertical data by threshold betweem trace and retrace
    %   second clearing: filter out force with 20% more than the setpoint for the specific section
    %   third clearing: remove entire fast scan lines by using the idx of manually selected portions        
    % show also the lateral and vertical data after clearing
    [vertForce_clear,force_clear]=featureFrictionCalc1_clearingAndPlotData(vertical_Trace,vertical_ReTrace,setpoints,maxSetpoint,force,idxSection,idxRemovedPortion,newFolder,secondMonitorMain);
    clear vertical_ReTrace vertical_Trace force alpha W Delta mask AFM_height_IO Lateral_Trace Lateral_ReTrace
              
    % calc the friction coefficient depending on the method
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%% FIRST METHOD  %%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if method == 1
        % clean and obtain the averaged vector
        [vertForce_avg,force_avg]=featureFrictionCalc2_avgLatForce(vertForce_clear,force_clear);
        %%%%%%% check NaN elements - at least 10 elements for section %%%%%%%
        prevNumElemSections=zeros(1,length(idxSection));
        flagChange=checkNaNelements(force_avg,idxSection,10,prevNumElemSections);
        if flagChange
            uiwait(msgbox('Aware! In some section there are few elements left necessary for the fitting. Try to change the mask (maybe too "brutal") or use smaller manually removed portion.',''));
        end
        % remove NaN elements 
        force_avg_best=force_avg(~isnan(force_avg));
        vertForce_avg_best=vertForce_avg(~isnan(vertForce_avg));
        vertForce_clear_best=vertForce_clear;
        force_clear_best=force_clear;
        fOutlierRemoval_text='';
        fOutlierRemoval='';
    else
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% SECOND METHOD  %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        % prepare the settings for the pixel size reduction
        pixData=varargin{1};
        fOutlierRemoval=varargin{2};
        fOutlierRemoval_text=varargin{3};
        % show a dialog box indicating the index of fast scan line along slow direction and which pixel size is processing
        wb=waitbar(0/size(force_clear,2),sprintf('Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',fOutlierRemoval,0,pixData(1),0,0),...
                 'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
        setappdata(wb,'canceling',0);               
        
        % start the counter for removal and init variables where store all the results, in order to
        % extract the desired one
        Cnt=1;
        arrayPixSizes=0:pixData(2):pixData(1);
        % allowed min number of elements in a section for a reliable fitting
        minElements=pixData(3);
        % init
        fitResults_fc=zeros(length(arrayPixSizes),2);
        vertForce_avg_clear_AllPixelSize=cell(length(arrayPixSizes),1);
        force_avg_clear_AllPixelSizes=cell(length(arrayPixSizes),1);
        vertForce_thirdClearing_AllPixelSizes=cell(length(arrayPixSizes),1);
        force_thirdClearing_AllPixelSizes=cell(length(arrayPixSizes),1);
        fc_pix=zeros(1,length(arrayPixSizes));
        offset_pix=zeros(1,length(arrayPixSizes));
        % track changes when increasing pixel and more sections have less elements than minimum
        prevNumElemSections=zeros(1,length(idxSection));    
        f_pixelsVSfc=figure('Visible','off');
        for pix = arrayPixSizes
            % init matrix.
            force_thirdClearing = zeros(size(force_clear));
            % copy and then put zeros according to the lateral force
            vertForce_thirdClearing = vertForce_clear;
            % Delete the outliers and remove edges depending on the current iterative pixel size
            % by substitution with new zero elements along fast scan lines
            sec=1;  % counter for section
            latOriginalLine=[]; % init the entire line for 3rd option
            vertOriginalLine=[];% init the entire line for 3rd option
            for i=1:size(force_thirdClearing,2)
                % if 1 or 2 option, provide i-th single fast scan line to the outlier removal algorithm                     
                if fOutlierRemoval == 1 || fOutlierRemoval == 2
                    latOriginalLine=force_clear(:,i);
                    vertOriginalLine=vertForce_clear(:,i);
                else
                % if 3 option, build entire section as single line to make more robust the data                    
                    startIdx=idxSection(sec);
                    % when last section
                    if sec == length(idxSection)
                        lastIdx=size(force_thirdClearing,2);
                    else
                        lastIdx=idxSection(sec+1)-1;
                    end
                    if i>=startIdx && i<=lastIdx                               
                        latOriginalLine=[latOriginalLine;force_clear(:,i)]; %#ok<AGROW>
                        vertOriginalLine=[vertOriginalLine;vertForce_clear(:,i)]; %#ok<AGROW>
                        % when last idx, avoid the continue otherwise it will increase
                        if i~=lastIdx
                            continue
                        end
                    end
                    % if this line is reached, start to remove outliers.
                    % if option 1 or 2, latOriginalLine is the single fast scan line
                    % if option 3, latOriginalLine is made of single fast scan lines in a section with same setpoint 
                end
                % the output/filtered line has same size as the input line
                latTmpLine = featureFrictionCalc5_DeleteEdgeDataAndOutlierRemoval(latOriginalLine, pix, fOutlierRemoval);                                           
                % zeroing elements in vertical data at the same idx of lat data
                vertTmpLine=vertOriginalLine;
                vertTmpLine(latTmpLine==0)=0;
                % reshape in case of 3rd option, otherwise just substitute the single fast scan line if
                % 1st or 2nd option
                if fOutlierRemoval==3
                    forceSectionTmp=reshape(latTmpLine,[size(force_thirdClearing,1)],sectionSize(sec));
                    force_thirdClearing(:,startIdx:lastIdx)=forceSectionTmp;
                    vertSectionTmp=reshape(vertTmpLine,[size(force_thirdClearing,1)],sectionSize(sec));
                    vertForce_thirdClearing(:,startIdx:lastIdx)=vertSectionTmp;
                    % increase the section counter to start to assembly and remove outliers of the next section
                    sec=sec+1;
                else
                    force_thirdClearing(:,i)=latTmpLine;
                    vertForce_thirdClearing(:,i)=vertTmpLine;    
                end
                % reset
                latOriginalLine=[]; 
                vertOriginalLine=[];
            
                clear latTmpLine vertTmp
                % update dialog box and check if cancel is clicked
                if(exist('wb','var'))
                    %if cancel is clicked, stop and delete dialog
                    if getappdata(wb,'canceling')
                        error('Manually stopped the process')
                    end
                end
                waitbar(i/size(force_clear,2),wb,sprintf('Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',fOutlierRemoval,pix,max(arrayPixSizes),i,i/size(force_clear,2)*100));
            end

            % to fit, use the average of single fast scan line. In this way, it will be possible track the
            % removal of entire block. Otherwise, prepareCurve provide entire block difficult to
            % distinguish. For example, since there are vertical values higher than the setpoint, the
            % unique function won't provide number of elements equal to the number of setpoint               
            [vertForce_avg,force_avg]=featureFrictionCalc2_avgLatForce(vertForce_thirdClearing,force_thirdClearing);            
            %%%%%%%% FIRST CONSTRAINT TO STOP THE PROCESS %%%%%%%%%
            % if one of the block in lateral force is totally zeroed or very few elements are left because 
            % of the pix removal (very common for large pix size), stop the execution because few data make
            % the fitting not reliable anymore. Moreover, when few values are left, there could be a shift in vertical
            % data from the original setpoint: if so, stop the process. Ignore the NaN            
            [flagChange,numElemXsection]=checkNaNelements(force_avg,idxSection,minElements,prevNumElemSections);
            if flagChange                    
                arrayText=sprintf('%d ',flip(numElemXsection));
                displayName=sprintf('pixel size: %d\n#Elements: %s',pix,arrayText);       % flip because originally high setpoint from left
                xline(pix,LineWidth=2,Color='red',DisplayName=displayName)
                prevNumElemSections= (numElemXsection < minElements);
                if length(find(numElemXsection < minElements))>=4
                    warning(sprintf('Not enough elements for the fitting \x2192 stopped calculation!')); %#ok<SPWRN>
                    break
                end
            end
            % Prepare the data for the fitting and remove any possible NaN elements
            force_avg_clear=force_avg(~isnan(force_avg));
            vertForce_avg_clear=vertForce_avg(~isnan(vertForce_avg));
            % obtain the friction coeff as single fitting. No plot
            % fitting the lateral versus vertical data.
            [fitResults,xData,yData]=featureFrictionCalc4_fittingForceSetpoint(vertForce_avg_clear,force_avg_clear,'fitting','Yes','imageProcessing','No');
            avg_fc_tmp=fitResults(1);               
            %%%%%%%% SECOND CONSTRAINT TO STOP THE PROCESS %%%%%%%%%
            % here apparently everything is ok and there is enough data to continue, but it could happen
            % that the fitting yield anomalous slope.
            % 1) slope higher than 0.95 has no sense
            % 2) number of overall common vertical force lower than used setpoint
            if avg_fc_tmp > 0.95 || avg_fc_tmp < 0
                warning(sprintf('Slope outside the reasonable range ( 0 < m < 0.95 ) \x2192 stopped calculation!')); %#ok<SPWRN>
                break
            end
            
            % store the results of every pix size if no break occurred
            fitResults_fc(Cnt,:)=fitResults;
            vertForce_avg_clear_AllPixelSize{Cnt}=xData;
            force_avg_clear_AllPixelSizes{Cnt}=yData;
            vertForce_thirdClearing_AllPixelSizes{Cnt}=vertForce_thirdClearing;
            force_thirdClearing_AllPixelSizes{Cnt}=force_thirdClearing;
            fc_pix(Cnt) = fitResults(1); 
            offset_pix(Cnt) = fitResults(2);
            Cnt = Cnt+1;
        end
        % sometime it may happens that the image scan get totally wrong to the point that the entire image
        % is useless, so track such cases and completely ignore.
        if ~all(fc_pix)
            flagWrongImage=true;
        else          
            % prepare the end data            
            pix=arrayPixSizes(1:Cnt-1);
            fc_pix=fc_pix(1:Cnt-1);
            % change visibility of the figure
            f_pixelsVSfc.Visible = 'on';
            hold on
            %% IT CAN BE IGNORED ID THE CHOICE IS MADE IN END
            % plot all the frictions coefficient in function of pixel size and show also the point in
            % which some sections has less elements than the minimum                   
            plot(pix, fc_pix, 'x-','LineWidth',2,'MarkerSize',10,'Color','blue','DisplayName','FC with Outlier Removal'); grid on
            xlabel('Pixel size','fontsize',15); ylabel('Glass friction coefficient','fontsize',15);
            titleText=sprintf('Result Method 3 (Mask + Outliers Removal - %s)',fOutlierRemoval_text);
            title(titleText,'FontSize',20);
            leg=legend('show');
            leg.FontSize=15; leg.Location="bestoutside";        
            if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f_pixelsVSfc); end           
            % select the right friction coefficient
            uiwait(msgbox('Select the best friction coefficient'));
            idx_x=selectRangeGInput(1,1,pix,fc_pix);
            hold on            
            scatter(pix(idx_x),fc_pix(idx_x),400,'pentagram','filled', 'MarkerFaceColor', 'red','DisplayName','Selected pix size');
            resFit=fitResults_fc(idx_x,:);
            avg_fc=resFit(1);
            title({titleText,sprintf('Friction Coefficient: %0.4f',avg_fc)},'FontSize',20);
            saveas(f_pixelsVSfc,sprintf('%s/resultA5_xFrictionCalc_2_Method_2_%d_pixelVSfrictionCoeffs_%s.tif',newFolder,fOutlierRemoval,fOutlierRemoval_text))
            close(f_pixelsVSfc)
            % extract the correct　data depending on the chosen idx              
            resFit=fitResults_fc(idx_x,:);
            pixFinal=pix(idx_x);
            vertForce_clear_best=vertForce_thirdClearing_AllPixelSizes{idx_x};
            force_clear_best=force_thirdClearing_AllPixelSizes{idx_x};
            vertForce_avg_best=vertForce_avg_clear_AllPixelSize{idx_x};
            force_avg_best=force_avg_clear_AllPixelSizes{idx_x};
            % show the new data with the choosen pixel size reduction
            featureFrictionCalc6_plotClearedImages(vertForce_clear_best,force_clear_best,maxSetpoint,newFolder,secondMonitorMain,true,pixFinal)     
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% END METHOD PROCESSING %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % prepare the figure where plot the experimental data and fitted curve
    f_fcFitt=figure; hold on    
    % plot the experimental data
    stats=featureFrictionCalc3_plotErrorBar(vertForce_avg_best,force_avg_best);
    % fit the data and plot the fitted curve. By default: yes fitting and image
    % if method 2, fitting already made, so only plot the fitted curve
    if method==1
        resFit=featureFrictionCalc4_fittingForceSetpoint(vertForce_avg_best,force_avg_best);
        avg_fc=resFit(1);
        if avg_fc > 0.95 || avg_fc < 0
            flagWrongImage=true;
        end
        fileName='resultsDataFrictionCoefficient_method_1';
        id=2;
        fOutlierRemovalID='';
    else
        featureFrictionCalc4_fittingForceSetpoint(vertForce_avg_best,force_avg_best,'fitting','No','fitResults',resFit);
        fileName=sprintf('resultsDataFrictionCoefficient_method_2_%d',fOutlierRemoval);
        id=3;
        fOutlierRemovalID=sprintf('%d_',fOutlierRemoval);
    end

    % in case something happened
    if flagWrongImage
        fileNotes=sprintf('%s/NOTES_resultA5_xFrictionCalc_method2_%d_pixelVSfrictionCoeffs_%s.txt',newFolder,fOutlierRemoval,fOutlierRemoval_text);
        fID=fopen(fileNotes,'a');
        text=sprintf('Experiment %s is entirely wrong: the friction coefficient of any pixel reduction size is outside the acceptable range\n',nameScan);
        fwrite(fID,text)
        fclose(fID);
        avg_fc='';
    else
        % store the results
        resFriction.slope=resFit(1);
        resFriction.offset=resFit(2);
        resFriction.forceCleared=force_clear_best;
        resFriction.vertCleared=vertForce_clear_best;
        resFriction.forceCleared_avg=force_avg_best;
        resFriction.vertCleared_avg=vertForce_avg_best;
        resFriction.statsErrorPlot=stats;                    
        % prepare the plot for the definitive results
        xlim padded, ylim padded
        xlabel('Setpoint (nN)','Fontsize',15); ylabel('Delta Offset (nN)','Fontsize',15); grid on, grid minor
        legend('Location','northwest','FontSize',15,'Interpreter','none')
        title(sprintf('Delta Offset vs Vertical Force - Method %d %s',method,fOutlierRemoval_text),'FontSize',20);
        if ~isempty(secondMonitorMain); objInSecondMonitor(secondMonitorMain,f_fcFitt); end
        filename=fullfile(newFolder,sprintf('resultA5_xFrictionCalc_%d_Method_%d_%sDeltaOffsetVSsetpoint.tif',id,method,fOutlierRemovalID));
        saveas(f_fcFitt,filename)
        uiwait(msgbox('Click to conclude'));
        close(f_fcFitt)
        save(fullfile(newFolder,fileName),"resFriction")
    end
    if exist('wb','var')
        delete(wb)
    end 
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%% ---- FUNCTIONS ---- %%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%% PSEUDO GLOBAL VARIABLE %%%%%%%%%%
function col = globalColor(n)
    colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k','#FF00FF','#00FF00','#0000FF','#FF0000'};
    col=colors{n};
end

%%%%%%%% REMOVE NAN ELEMENTS FROM THE DATA %%%%%%%%
function [flag,numElemSections]=checkNaNelements(vectorAvg,idxSection,minElements,prevLenghtMinElements)
    % In case an entire fast scan line is 0, the resulting averaged element for that fast scan line will 
    % be NaN. Therefore, easy to find and understand how many elements are left for a specific section
    numElemSections=zeros(1,length(idxSection));
    for i=1:length(idxSection)
        % last section
        if i==length(idxSection)
            numElemSections(i)=length(find(~isnan(vectorAvg(idxSection(i):end))));
        else
            numElemSections(i)=length(find(~isnan(vectorAvg(idxSection(i):idxSection(i+1)-1))));
        end                
    end
    % if a section has number of nan elements higher than the previous updated array
    if ~isequal((numElemSections < minElements), prevLenghtMinElements)
        flag=true;
    else
        flag=false;
    end
end

%%%%%%%% SHOW VERTICAL AND LATERAL CLEARED DATA %%%%%%%%
function featureFrictionCalc6_plotClearedImages(x,y,maxSetpoint,path,secondMonitorMain,postProcess,varargin) 
% show and save the lateral and vertical forces indipendtly of the method used. Data cleared with the three
% clearing methods (vertical force threshold + 20% more max setpoint + manually removed portions)
    f1=figure('Visible','off');
    subplot(121)
    % show the lateral data
    imagesc(y)
    clim([0 maxSetpoint*1.25])
    c= colorbar; c.Label.String = 'Force [nN]'; c.FontSize = 15;
    title('Lateral Force','FontSize',20)
    ylabel(' fast direction - scan line','FontSize',15), xlabel('slow direction','FontSize',15)
    axis equal, xlim([0 size(y,2)]), ylim([0 size(y,1)])
    subplot(122)
    % show the vertical data. If method is 2 or 3, the data is already masked
    imagesc(x)
    clim([0 maxSetpoint*1.25])
    c= colorbar; c.Label.String = 'Force [nN]'; c.FontSize = 15;
    title('Vertical Force','FontSize',20)
    ylabel(' fast direction - scan line','FontSize',15), xlabel('slow direction','FontSize',15)
    axis equal, xlim([0 size(x,2)]), ylim([0 size(x,1)])
    % after processed the pixel size reduction
    if postProcess
        sgTitleFigure=sprintf('BK regions with the mask, data cleared and pixel size reduction (%d)',varargin{1});
        fileName=sprintf('resultA5_xFrictionCalc_3_lateralVerticalData_pixelSizeReduction_%d_postCalcFC.tif',varargin{1});
    else
        sgTitleFigure='BK regions with the mask applied and data cleared (before process FC calculation)';
        fileName='resultA5_xFrictionCalc_1_lateralVerticalData_cleared_preCalcFC.tif';
    end
    sgtitle(sgTitleFigure,'Fontsize',20);
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
    saveas(f1,fullfile(path,fileName))
    close(f1)
end

%%%%%%%% CLEARING STEPS %%%%%%%%      
function [vertForce_thirdClearing,force_thirdClearing]=featureFrictionCalc1_clearingAndPlotData(vertical_Trace,vertical_ReTrace,setpoints,maxSetpoints,force,idxSection,idxRemovedPortion,newFolder,secondMonitorMain)
% NOTE: doesnt matter the used method. Its just the mask applying and removal of common outliers
% Remove outliers among Vertical Deflection data using a defined threshold of 4nN 
% ==> trace and retrace in vertical deflection should be almost the same.
% This threshold is used as max acceptable difference between trace and retrace of vertical data      
    %%%%%% FIRST CLEARING %%%%%%%
    Th = 2;
    % average of each single fast line
    vertTrace_avg = mean(vertical_Trace);
    vertReTrace_avg = mean(vertical_ReTrace);
    % find the idx (slow direction) for which the difference 
    % of average vertical force between trace and retrace is acceptable
    Idx = abs(vertTrace_avg - vertReTrace_avg) < Th;
    if ~all(Idx)
        warning('Performed First clearing - presence of outliers among vertical fast scan lines')
    end        
    % using this idx (1 ok, 0 not ok), substitute entire lines in the lateral data with zero
    force_firstClearing = force;    force_firstClearing(:,Idx==0)=0;
    % using this idx (1 ok, 0 not ok), substitute entire lines in the vertical data with zero and average
    % trace and retrace vertical data
    vertForceT=vertical_Trace;      vertForceT(:,Idx==0)=0;
    vertForceR=vertical_ReTrace;    vertForceR(:,Idx==0)=0;
    vertForce_firstClearing = (vertForceT + vertForceR) / 2;
    
    %%%%%% SECOND CLEARING %%%%%%%
    % remove from lateral data those values 20% higher than the setpoint
    perc=6/5; % 20% more than the value
    force_secondClearing=force_firstClearing;
    vertForce_secondClearing=vertForce_firstClearing;
    for i=1:length(idxSection)
        startIdx=idxSection(i);
        % when last section
        if i == length(idxSection)
            lastIdx=size(force_secondClearing,2);
        else
            lastIdx=idxSection(i+1)-1;
        end
        maxlimit=setpoints(i)*perc;
        force_tmp=force_secondClearing(:,startIdx:lastIdx);
        force_tmp(force_tmp>maxlimit)=0;
        force_secondClearing(:,startIdx:lastIdx)=force_tmp;     
    end
    vertForce_secondClearing(force_secondClearing==0)=0;
    
    %%%%%% THIRD CLEARING %%%%%%%
    % build 1-dimensional array which contain 0 or 1 according to the idx of regions manually removed 
    % ( 0 = removed slow line)
    vertForce_thirdClearing=vertForce_secondClearing;
    force_thirdClearing=force_secondClearing;
    if ~isempty(idxRemovedPortion)
    %array01RemovedRegion=ones(1,size(force_firstClearing,2));
        for n=1:size(idxRemovedPortion,1)
            if isnan(idxRemovedPortion(n,3)) 
                % remove entire fast scan lines
                vertForce_thirdClearing(:,idxRemovedPortion(n,1):idxRemovedPortion(n,2))=0;
                force_thirdClearing(:,idxRemovedPortion(n,1):idxRemovedPortion(n,2))=0;
            else
                % remove portions
                vertForce_thirdClearing(idxRemovedPortion(n,3):idxRemovedPortion(n,4),idxRemovedPortion(n,1):idxRemovedPortion(n,2))=0;
                force_thirdClearing(idxRemovedPortion(n,3):idxRemovedPortion(n,4),idxRemovedPortion(n,1):idxRemovedPortion(n,2))=0;
            end
        end
    end
    % plot lateral (masked force, N) and vertical data (masked force, N). Not show up but save fig
    featureFrictionCalc6_plotClearedImages(vertForce_thirdClearing,force_thirdClearing,maxSetpoints,newFolder,secondMonitorMain,false)
end

%%%%%%%% AVERAGE FAST SCAN LINES %%%%%%%%
function [x_avg,y_avg]=featureFrictionCalc2_avgLatForce(x,y)    
% the function remove zeros values for the given fast scan line and then average
% INPUT: the data as entire matric with both fast and slow scan lines
    % init
    x_avg = zeros(1, size(x,2));
    y_avg = zeros(1, size(y,2));
    % average fast line of lateral force ignoring zero values
    for i=1:size(x,2)
        tmp1 = x(:,i);
        tmp2 = y(:,i);
        x_avg(i) = mean(tmp1(tmp1~=0));
        y_avg(i) = mean(tmp2(tmp2~=0));        
    end
end

%%%%%%%% FOR METHOD 1 PLOT ERROR BAR TO SHOW POINTS OF EACH AVERAGED ELEMENT %%%%%%%%
function stats=featureFrictionCalc3_plotErrorBar(vertForce,latForce)
% NOTE: the input must be a vector of elements as average of entire fast scan line
    if ~isvector(vertForce) || ~isvector(latForce)
        error('The input data are not vector. Each element represents the average of a i-th fast scan line, therefore the vector lenght represents the slow lines')
    end
    % find the idx of single blocks by setpoint
    [~,idx]=unique(round(vertForce,-1),'stable');
    % init
    latForce_Blocks_avg=zeros(1,length(idx));
    latForce_Blocks_std=zeros(1,length(idx));
    vertForce_Blocks_avg=zeros(1,length(idx));
    vertForce_Blocks_std=zeros(1,length(idx));
    % flip because the high setpoint is on the left
    %idx=flip(idx);   
    for i=1:length(idx)-1
        % extract the lateral and vertical deflection of the single box
        latForce_Block=latForce(idx(i):(idx(i+1)-1));
        vertForce_Block=vertForce(idx(i):(idx(i+1)-1));
        % calc the avg an std of the entire block (vector portion that represent the original matrix)
        latForce_Blocks_avg(i)=mean(latForce_Block); 
        latForce_Blocks_std(i)=std(latForce_Block);
        vertForce_Blocks_avg(i)=mean(vertForce_Block);
        vertForce_Blocks_std(i)=std(vertForce_Block);
    end
    %last block
    latForce_Block=latForce(idx(end):end);
    vertForce_Block=vertForce(idx(end):end);      
    % calc the mean and std of last block
    latForce_Blocks_avg(end)=mean(latForce_Block);
    latForce_Blocks_std(end)=std(latForce_Block);
    vertForce_Blocks_avg(end)=mean(vertForce_Block); 
    % flip to start with low value at left
    x=flip(vertForce_Blocks_avg);
    y=flip(latForce_Blocks_avg);
    err=flip(latForce_Blocks_std);
    % save the stats
    stats.vertAvgX=x; stats.forceAvgY=y; stats.forceErr=err;
    % plot the data
    errorbar(x,y,err,'s','Linewidth',1.3,'capsize',15,'Color',globalColor(2),...
        'markerFaceColor',globalColor(2),'markerEdgeColor',globalColor(2),'MarkerSize',10,...
        'DisplayName','Experimental data');
end

%%%%%%%% FITTING VERTICAL VS LATERAL DATA (NanoNewton) %%%%%%%%
function [pfit,xData,yData]=featureFrictionCalc4_fittingForceSetpoint(x,y,varargin)
% Input: x and y are the data to fit or the fitted curve in case of plot only.
% Output = fitting results. 
% in case of method 1, fit and plot the relation of a given experiment.
% in case of method 2:
%    FIRST CALL, for each pixel size reduction
%       'imageProcessing' = 'No'
%   SECOND CALL, once the right pixel reduction size has been choosen
%       'fitting' = 'No'
%       'fitResults' = <provide the fit parameters>
    p=inputParser(); 
    argName = 'fitting';            defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'imageProcessing';    defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'fitResults';         defaultVal = [];        addParameter(p,argName,defaultVal)
    parse(p,varargin{:});
    % suppress the warning for the fitting
    id='curvefit:fit:iterationLimitReached';
    warning('off',id)
    if strcmpi(p.Results.fitting,'Yes'), fitting=true; else, fitting=false; end
    if strcmpi(p.Results.imageProcessing,'Yes'), imageProcessing=true; else, imageProcessing=false; end
    if ~(imageProcessing || fitting)
        error('Operation not allowed. At least one operation must be ''Yes''')
    end
    pfit=p.Results.fitResults;        
    % Linear fitting
    if fitting
        % prepare the data
        [xData, yData] = prepareCurveData(x,y);
        % Set up fittype and options.
        ft = fittype( 'poly1' ); opts = fitoptions( 'Method', 'LinearLeastSquares'); opts.Robust = 'LAR';
        % Fit model to data.
        fitresult = fit( xData, yData, ft, opts);       
        x=xData;
        pfit(1)=fitresult.p1;
        pfit(2)=fitresult.p2;
    end
    
    if imageProcessing
        xfit=linspace(min(x),max(x),100);
        yfit=xfit*pfit(1)+pfit(2);
        if pfit(2) < 0
            signM='-';
        else
            signM='+';
        end
        plot(xfit, yfit, '-.','color',globalColor(1),'DisplayName',sprintf('Fitted data: %0.3g x %s %0.3g',pfit(1),signM,abs(pfit(2))),'LineWidth',2);    
    end
end       

%%%%%%%% OUTLIER REMOVAL FOR THE GIVEN FAST SCAN LINE %%%%%%%%
function LineDataFilt = featureFrictionCalc5_DeleteEdgeDataAndOutlierRemoval(LineData, pix, fOutlierRemoval)
% Delete edge data by searching non-zero data area (segmentLineDataFilt) and put zero in edge of segment (last part of the segment)
% INPUT:    1) single fast scan line (force, N)
%           2) dimension window filter
%           3) Mode of outlier removal:
%               0: No outlier removal.
%               1: Apply outlier removal to each segment after pixel reduction.
%               2: Apply outlier removal to one large connected segment after pixel reduction.
    % Initialize connected one large segment
    SegPosList_StartPos = [];
    SegPosList_EndPos = [];
    ConnectedSegment = [];
    Cnt = 1;
    LineDataFilt = LineData;
    % for each element
    %   1) if ~= 0 ==> DETECTION NEW SEGMENT 
    %           ==> update StartPos
    %           ==> find the end of the segment (first zero value)
    %           ==> build the segment and remove outliers
    %           ==> skip to end+1 element which is zero and detect a new segment
    %   2) if == 0 ==> nothing happens, skip to next iteration    
    processSingleSegment=true; i=1;
    while processSingleSegment
        % DETECTION NEW SEGMENT
        if LineData(i) ~= 0
            StartPos = i;
            % find the idx of the only first zero element from startpos idx. Then the result is the idx of the nonzero
            % element just before the previously found idx of zero element
            EndPos=StartPos+find(LineData(StartPos:end)==0,1)-2;
            % the previous operation will return NaN when the last element is non-zero, thus manage it
            if isempty(EndPos)
                EndPos=length(LineData);
                processSingleSegment=false;                
            end
            % Extract the segment (note: it is BACKGROUND data)
            Segment = LineData(StartPos:EndPos);
            % if the length of segment is less than 4, it is very likely to be a random artefact. 
            % Also, not really realiable when filloutliers is used because few sample
            % remove such values and put 0
            if length(Segment)<4
                LineDataFilt(StartPos:EndPos) = zeros(1,length(Segment));
            else
                % save the indexes of start and end segment
                SegPosList_StartPos(Cnt) = StartPos;                    %#ok<AGROW>
                SegPosList_EndPos(Cnt) = EndPos;                        %#ok<AGROW>
                Cnt = Cnt + 1;
                % if first iteration, do nothing and use as reference
                if pix > 0
                    % if the half-segment is longer than pix window, then reset first and last part with size = pix
                    % in order to remove edges in both sides (the tip encounters the edges of a single PDA crystal 
                    % twice: trace and in retrace)
                    if ceil(length(Segment)/2) >=pix
                        Segment(1:pix) = 0;                
                        Segment(end-pix+1:end) = 0;
                    else
                    % if the segment is shorter, then reset entire segment
                        Segment(:) = 0;
                    end
                end                
                % MANAGE THE SEGMENT WITH TWO METHODS
                % method 1: Detect and replace outliers in data with 0. Median findmethod is default
                % Outliers are defined as elements more than three scaled MAD from the median
                if fOutlierRemoval == 1
                    Segment = filloutliers(Segment, 0);
                    % Replace segment
                    LineDataFilt(StartPos:EndPos) = Segment;
                else
                % method 2 or 3: Find the i-th segment and attach to the previous found one to build a single large
                % connected segment and track the idx
                    ConnectedSegment = [ConnectedSegment; Segment];          %#ok<AGROW>
                    %idxConnectedSegment(Cnt)=length(ConnectedSegment)+1
                end   
            end
            % skip to find the next segment
            i=EndPos+1;
        else
            % if the last element is zero, break the while loop 
            if i==length(LineData), break, end    
            % if the element is zero, do nothing and move to the next element
            i=i+1;
        end
    end    
    % Process one large connected segment. Note that if mode = 2 or 3, connected segment lacks of resetted edges
    % of the previous part.
    % Here, ConnectedSegment is just the concatenation of each nonFiltered segments previously found .
    % in this way, the function filloutliers has more data to process so the result should be more consistent
    if fOutlierRemoval == 2 || fOutlierRemoval == 3
        ConnectedSegment2 = filloutliers(ConnectedSegment, 0);
        % substitute the pieces of connectedSegment2 with the corresponding part of original fast scan line
        Cnt2 = 1;
        for i=1:length(SegPosList_StartPos)
            % coincide with the number of elements of original segment
            Len = SegPosList_EndPos(i) - SegPosList_StartPos(i) +1;
            LineDataFilt(SegPosList_StartPos(i):SegPosList_EndPos(i)) = ConnectedSegment2(Cnt2:Cnt2+Len-1);
            % start with the next segment
            Cnt2 = Cnt2 + Len;  
        end
    end
end

