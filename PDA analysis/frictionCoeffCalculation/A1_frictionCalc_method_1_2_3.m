% This function opens the AFM data previously created to calculate the background friction
% coefficient.
% 
% This function uses one of three methods depending on the choice and input data
%   method 1)  INPUT: background ONLY ==>  simplest method
%   method 2)  INPUT: background+PDA  ==>  masking lateral and vertical data using AFM_height_IO to ignore PDA regions
%
% The third method removes outliers considered as spike signals in correspondence with the PDA crystal's edges using
% in-built matlab function.
% Moreover, PIXEL REDUCTION is applied to make more robust the statistical calculation prior the outliers removal
% once found a segment (single background region between two PDA regions), depending on the window/pixel
% size, the edges will be "brutally" removed by zeroing (0:PDA-1:BK)
%   method 3a) INPUT: background+PDA  ==>  method 2 + REMOVAL OF OUTLIERS on single segments for each single fast
%                                          scan line
%   method 3b) INPUT: background+PDA  ==>  method 2 + REMOVAL OF OUTLIERS on connected segments for each single
%                                          fast scan line
% WORKING PROGRESS
%   method 3c) INPUT: background+PDA  ==>  method 2 + REMOVAL OF OUTLIERS on connected segments of each entire
%                                          section (in correspondence of same setpoint region)
%   
% INPUT:    1) AFM_AllScanImages (trace and retrace | height, lateral and vertical data, Hover Mode off) of ANY SELECTED SCAN
%           2) metadata of ANY SELECTED SCAN
%           3) AFM_height_IO (mask PDA-background 0/1 values) of ANY SELECTED SCAN
%           4) secondMonitorMain
%           5) newFolder: path where store the results
%           5) choice: method 1 | method 2 | method 3 (three available options)
%
% OUTPUT:   resFrictionAllExp struct which contains
%           1) nameScan
%           2) friction/slope value
%           3) offset value
%           4) force image cleared (depending on the method)
%           5) vertical force image cleared (depending on the method)
%           6) averaged values of fast scan lines of force used for the fitting
%           7) averaged values of fast scan lines of vertical force used for the fitting

function [resFrictionAllExp,varargout]=A1_frictionCalc_method_1_2_3(AFM_AllScanImages,metadata_AllScan,AFM_AllScan_height_IO,secondMonitorMain,newFolder,method,nameScan_AllScan,idxRemovedPortion_onlyBK,varargin)
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)
    numFiles=length(AFM_AllScanImages);
    limitsXYdata=zeros(2,2,numFiles);
    % find the maximum setpoint among the files
    for i=1:length(metadata_AllScan)
        maxSetpointFile(i)=max(metadata_AllScan{i}.SetP_N*1e9); %#ok<AGROW>
    end
    maxSetpointAllFile=max(maxSetpointFile); clear maxSetpointFile
    % init the var where store the different coefficient frictions of any scan image and the cleared images
    % and averaged cleared vector
    resFrictionAllExp=struct('nameScan',[],'slope',[],'offset',[],'metadata',[],'forceCleared',[],'vertCleared',[],'forceCleared_avg',[],'vertCleared_avg',[],'statsErrorPlot',[]);

    if method~=3
        % open a new figure where plot the fitting curves of all the uploaded friction experiments.
    % if method 2: forceVSsetpoint of each experiment
    % if method 3: frictionVSpix + forceVSsetpoint of each experiment
        f_fcAll=figure; hold on
    end

    for j=1:numFiles
        % extract the needed data
        dataSingle=AFM_AllScanImages{j};
        metadataSingle=metadata_AllScan{j};
        alpha=metadataSingle.Alpha;
        % flip setpoint because high setpoint start from the left
        setpoints=flip(round(metadataSingle.SetP_N*1e9));
        AFM_height_IO=AFM_AllScan_height_IO{j};
        nameScan=nameScan_AllScan{j};
        resFrictionAllExp(j).nameScan = nameScan;
        resFrictionAllExp(j).metadata= metadataSingle;
        idxRemovedPortion=idxRemovedPortion_onlyBK{j};      
        % prepare the idx for each section depending on the size of each section stored in the metadata
        sectionSize=metadataSingle.y_scan_pixels;
        idxSection=zeros(1,length(sectionSize));
        idxSection(1)=1; % first idx
        for i= 2:length(sectionSize)
            idxSection(i)= idxSection(i-1)+sectionSize(i);            
        end
        % extract data (lateral deflection Trace and Retrace, vertical deflection) and then mask (BK-PDA)
        % elementXelement ==> 
        %       1 (crystal)   => 0
        %       0 (BK)        => 1
        % method 1: no mask because the code supposes the AFM images are made of background only 
        %   ==> original AFM_height01 : 1=PDA ==> 0 | 0=BK ==> 1        
        if method == 1
            mask=zeros(size(dataSingle(1).AFM_image));
        else
        % method 2 and 3: yes mask because PDA+background
            mask=AFM_height_IO;
        end
        Lateral_Trace   = (dataSingle(strcmpi([dataSingle.Channel_name],'Lateral Deflection') & strcmpi([dataSingle.Trace_type],'Trace')).AFM_image).*(~mask);
        Lateral_ReTrace = (dataSingle(strcmpi([dataSingle.Channel_name],'Lateral Deflection') & strcmpi([dataSingle.Trace_type],'ReTrace')).AFM_image).*(~mask);           
        Delta = (Lateral_Trace + Lateral_ReTrace) / 2;
        % Calc W (half-width loop)
        W = Lateral_Trace - Delta;
        vertical_Trace   = (dataSingle(strcmpi([dataSingle.Channel_name],'Vertical Deflection') & strcmpi([dataSingle.Trace_type],'Trace')).AFM_image).*(~mask);
        vertical_ReTrace = (dataSingle(strcmpi([dataSingle.Channel_name],'Vertical Deflection') & strcmpi([dataSingle.Trace_type],'ReTrace')).AFM_image).*(~mask);                                         
        % convert W into force (in Newton units) using alpha calibration factor and show results.
        force=W*alpha;
        % convert N into nN
        force=force*1e9;
        vertical_Trace=vertical_Trace*1e9;
        vertical_ReTrace=vertical_ReTrace*1e9;
        
        % apply
        %   first clearing: filter out anomalies among vertical data by threshold betweem trace and retrace
        %   second clearing: filter out force with 20% more than the setpoint for the specific section
        %   third clearing: remove entire fast scan lines by using the idx of manually selected portions        
        % show also the lateral and vertical data after clearing
        [vertForce_clear,force_clear]=featureFrictionCalc1_clearingAndPlotData(vertical_Trace,vertical_ReTrace,setpoints,maxSetpointAllFile,force,idxSection,idxRemovedPortion,newFolder,nameScan,secondMonitorMain,method);
        clear vertical_ReTrace vertical_Trace force alpha W Delta mask AFM_height_IO Lateral_Trace Lateral_ReTrace
        if method ~=3
            figure(f_fcAll)      
        end        
        % calc the friction coefficient depending on the method
        % method 1 and 2 are technically identical. Only the AFM data change (method 2 use masked images)
        if method == 1 || method == 2
            % clean and obtain the averaged vector
            [vertForce_avg,force_avg]=featureFrictionCalc2_avgLatForce(vertForce_clear,force_clear);
            %%%%%%% check NaN elements - at least 10 elements for section %%%%%%%
            prevNumElemSections=zeros(1,length(idxSection));
            flagChange=checkNaNelements(force_avg,idxSection,10,prevNumElemSections);
            if flagChange
                uiwait(msgbox('Aware! In some section there are few elements left necessary for the fitting. Try to change the mask (maybe too "brutal") or use smaller manually removed portion.',''));
            end
            % remove NaN elements 
            force_avg_clear=force_avg(~isnan(force_avg));
            vertForce_avg_clear=vertForce_avg(~isnan(vertForce_avg));
            % plot the experimental data
            [limitsXYdata(:,:,j),stats]=featureFrictionCalc3_plotErrorBar(vertForce_avg_clear,force_avg_clear,j,nameScan);
            % fit the data and plot the fitted curve. By default: yes fitting and image
            resFit=featureFrictionCalc4_fittingForceSetpoint(vertForce_avg_clear,force_avg_clear,j);
            fOutlierRemoval_text='';
            % store the results
            resFrictionAllExp(j).slope=resFit(1);
            resFrictionAllExp(j).offset=resFit(2);
            resFrictionAllExp(j).forceCleared=force_clear;
            resFrictionAllExp(j).vertCleared=vertForce_clear;
            resFrictionAllExp(j).forceCleared_avg=force_avg_clear;
            resFrictionAllExp(j).vertCleared_avg=vertForce_avg_clear;
            resFrictionAllExp(j).statsErrorPlot=stats;
        else
            %%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%% THIRD METHOD  %%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%
            f_pixelsVSfc=figure('Visible','off');
            % ask modalities only once, at the first iterated file
            if j==1  
                % extract the parameters for the pixel size reduction
                pixData=varargin{1};
                fOutlierRemoval=varargin{2};
                fOutlierRemoval_text=varargin{3};
                % show a dialog box indicating the index of fast scan line along slow direction and which pixel size is processing
                wb=waitbar(0/size(force_clear,2),sprintf('Image %d - Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',j,fOutlierRemoval,0,pixData(1),0,0),...
                         'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
                setappdata(wb,'canceling',0);               
            else
                % reset the bar
                waitbar(0/size(force_clear,2),wb,sprintf('Image %d - Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',j,fOutlierRemoval,0,pixData(1),0,0));
            end
            
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
                    waitbar(i/size(force_clear,2),wb,sprintf('Image %d - Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',j,fOutlierRemoval,pix,max(arrayPixSizes),i,i/size(force_clear,2)*100));
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
                [fitResults,xData,yData]=featureFrictionCalc4_fittingForceSetpoint(vertForce_avg_clear,force_avg_clear,j,'fitting','Yes','imageProcessing','No');
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
            % prepare the end data
            pix=arrayPixSizes(1:Cnt-1);
            fc_pix=fc_pix(1:Cnt-1);
            offset_pix=offset_pix(1:Cnt-1);
            hold on
            %% IT CAN BE IGNORED ID THE CHOICE IS MADE IN END
            % plot all the frictions coefficient in function of pixel size and show also the point in
            % which some sections has less elements than the minimum       
            h1=plot(pix, fc_pix, 'x-','LineWidth',2,'MarkerSize',10,'Color','blue'); grid on
            h1.Annotation.LegendInformation.IconDisplayStyle = 'off'; % dont show name in the legend
            xlabel('Pixel size','fontsize',15); ylabel('Glass friction coefficient','fontsize',15);
            title(sprintf('Result Method 3 (Mask + Outliers Removal - %s)',fOutlierRemoval_text),'FontSize',20);
            leg=legend('show');
            leg.FontSize=12; leg.Location="bestoutside";
            if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f_pixelsVSfc); end
            % select the right friction coefficient
            % uiwait(msgbox('Click on the plot'));
            % idx_x=selectRangeGInput(1,1,0:pixData(2):pixData(1),avg_fc_pix);
            % hold on
            % scatter(pixData(2)*idx_x-pixData(2),avg_fc_pix(idx_x),400,'pentagram','filled', 'MarkerFaceColor', 'red','DisplayName','Selected pix size');
            % pixFinal=pix(idx_x);
            % % extract the correct　data depending on the chosen idx              
            % resFit=fitResults_fc(idx_x,:);
            % vertForce_thirdClearing_best=vertForce_thirdClearing_AllPixelSizes{idx_x};
            % force_thirdClearing_best=force_thirdClearing_AllPixelSizes{idx_x};
            % vertForce_avg_best=vertForce_avg_clear_AllPixelSize{idx_x};
            % force_avg_best=force_avg_clear_AllPixelSizes{idx_x};

            % plot the data after cleared
            %featureFrictionCalc6_plotClearedImages(vertForce_thirdClearing_best,maxSetpointAllFile,force_thirdClearing_best,newFolder,nameScan,secondMonitorMain,method,pixFinal,fOutlierRemoval_text)  

            % finish the plot and save
            % mainText=sprintf('Result Method 3 (Mask + Outliers Removal - %s) - %s',fOutlierRemoval_text,nameScan);
            % resultChoice= sprintf('Friction coefficient: %0.3g',avg_fc_pix(idx_x));
            % title({mainText; resultChoice},'FontSize',20,'interpreter','none');            
            saveas(f_pixelsVSfc,sprintf('%s/resultMethod3_1_pixelVSfrictionCoeffs_%s_%s.tif',newFolder,nameScan,fOutlierRemoval_text))
            close(f_pixelsVSfc)
            % return to the main general figure where compare all the scans.
            % Plot the errorbar and the fitted curve and take the min max XY values to better figure limits
            %figure(f_fcAll)
            %limitsXYdata(:,:,j)=featureFrictionCalc3_plotErrorBar(vertForce_avg_best,force_avg_best,j,nameScan);
            %featureFrictionCalc4_fittingForceSetpoint(vertForce_avg_best,force_avg_best,j,'fitting','No','imageProcessing','Yes','fitResults',resFit);

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%% END METHOD PROCESSING %%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % store the results and cleared images         
            resFrictionAllExp(j).slope=fc_pix;
            resFrictionAllExp(j).offset=offset_pix;
            resFrictionAllExp(j).forceCleared=force_thirdClearing_AllPixelSizes;
            resFrictionAllExp(j).vertCleared=vertForce_thirdClearing_AllPixelSizes;
            resFrictionAllExp(j).forceCleared_avg=force_avg_clear_AllPixelSizes;
            resFrictionAllExp(j).vertCleared_avg=vertForce_avg_clear_AllPixelSize;            
        end
    end    
    
    if method == 1 || method == 2
        % find the absolute minimum and maximum in all the data to better show the final results
        absMinX=min(limitsXYdata(1,1,:)); absMaxX=max(limitsXYdata(1,2,:));
        absMinY=min(limitsXYdata(2,1,:)); absMaxY=max(limitsXYdata(2,2,:));
        % prepare the plot for the definitive results
        xlim([absMinX*0.7 absMaxX*1.1]), ylim([absMinY*0.7 absMaxY*1.1])
        xlabel('Setpoint (nN)','Fontsize',15); ylabel('Delta Offset (nN)','Fontsize',15); grid on, grid minor
        legend('Location','northwest','FontSize',15,'Interpreter','none')
        title(sprintf('Delta Offset vs Vertical Force - Method %d %s',method,fOutlierRemoval_text),'FontSize',20);
        if ~isempty(secondMonitorMain); objInSecondMonitor(secondMonitorMain,f_fcAll); end
        saveas(f_fcAll,sprintf('%s/resultMethod_%d_DeltaOffsetVSsetpoint%s.tif',newFolder,method,fOutlierRemoval_text))
        uiwait(msgbox('Click to conclude'));
        close(f_fcAll)
    else
        % plot the distribution of all the calculated friction coefficients        
        definitiveFc=featureFrictionCalc7_distributionFc_allScansAllPixels({resFrictionAllExp(:).slope},nameScan_AllScan,secondMonitorMain,newFolder,pixData,fOutlierRemoval);
        varargout{1}=definitiveFc;
    end
    if exist('wb','var')
        delete(wb)
    end 
end

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