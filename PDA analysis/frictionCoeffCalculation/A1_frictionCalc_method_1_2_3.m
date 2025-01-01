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
% OUTPUT:   1) friction value

function resFrictionAllExp=A1_frictionCalc_method_1_2_3(AFM_AllScanImages,metadata_AllScan,AFM_AllScan_height_IO,secondMonitorMain,newFolder,method,nameScan_AllScan,idxRemovedPortion_onlyBK)
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)

    numFiles=length(AFM_AllScanImages);
    limitsXYdata=zeros(2,2,numFiles);
    % init the var where store the different coefficient frictions of any scan image
    resFrictionAllExp=struct('nameScan',[],'slope',[],'offset',[]);
    % open a new figure where plot the fitting curves of all the uploaded friction experiments.
    % if method 2: forceVSsetpoint of each experiment
    % if method 3: frictionVSpix + forceVSsetpoint of each experiment
    f_fcAll=figure; hold on
    
    for j=1:numFiles
        % extract the needed data
        dataSingle=AFM_AllScanImages{j};
        metadataSingle=metadata_AllScan{j};
        Setpoint=round((metadataSingle.SetP_N)*1e9);
        AFM_height_IO=AFM_AllScan_height_IO{j};
        nameScan=nameScan_AllScan{j};
        resFrictionAllExp(j).nameScan = nameScan;
        idxRemovedPortion=idxRemovedPortion_onlyBK{j};
        % extract data (lateral deflection Trace and Retrace, vertical deflection) and then mask (BK-PDA)
        % elementXelement ==> 
        %       1 (crystal)   => 0
        %       0 (BK)        => 1
        % method 1: no mask because the code supposes the AFM images are made of background only 
        %   ==> original AFM_height01 : 1=PDA ==> 0 | 0=BK ==> 1
        % method 2 and 3: yes mask because PDA+background
        if method == 1
            mask=zeros(size(dataSingle(1).AFM_image));
        else
            mask=AFM_height_IO;
        end
        Lateral_Trace   = (dataSingle(strcmpi([dataSingle.Channel_name],'Lateral Deflection') & strcmpi([dataSingle.Trace_type],'Trace')).AFM_image).*(~mask);
        Lateral_ReTrace = (dataSingle(strcmpi([dataSingle.Channel_name],'Lateral Deflection') & strcmpi([dataSingle.Trace_type],'ReTrace')).AFM_image).*(~mask);           
        Delta = (Lateral_Trace + Lateral_ReTrace) / 2;
        % Calc W (half-width loop)
        W = Lateral_Trace - Delta;
        vertical_Trace   = (dataSingle(strcmpi([dataSingle.Channel_name],'Vertical Deflection') & strcmpi([dataSingle.Trace_type],'Trace')).AFM_image).*(~mask);
        vertical_ReTrace = (dataSingle(strcmpi([dataSingle.Channel_name],'Vertical Deflection') & strcmpi([dataSingle.Trace_type],'ReTrace')).AFM_image).*(~mask);
        
        alpha=metadataSingle.Alpha;                           
        % convert W into force (in Newton units) using alpha calibration factor and show results.
        force=W*alpha;
        % convert N into nN
        force=force*1e9;
        vertical_Trace=vertical_Trace*1e9;
        vertical_ReTrace=vertical_ReTrace*1e9;
        
        % apply
        %   first clearing: filter out anomalies among vertical data by threshold betweem trace and retrace
        %   second clearing: remove entire fast scan lines by using the idx of manually selected portions        
        % show also the lateral and vertical data after clearing
        [vertForce_clear,force_clear]=featureFrictionCalc1_clearingAndPlotData(vertical_Trace,vertical_ReTrace,force,idxRemovedPortion,AFM_height_IO,newFolder,nameScan,secondMonitorMain,method);

        figure(f_fcAll)
        % calc the friction coefficient depending on the method
        if method == 1
            % clean and obtain the averaged vector
            [vertForce_avg,force_avg]=featureFrictionCalc2_avgLatForce(vertForce_clear,force_clear);
            % plot the experimental data
            limitsXYdata(:,:,j)=featureFrictionCalc3_plotErrorBar(vertForce_avg,force_avg,j,nameScan);
            % fit the data and plot the fitted curve
            resFit=featureFrictionCalc4_fittingForceSetpoint(vertForce_avg,force_avg,j);
            fOutlierRemoval_text='';
        elseif method == 2
            % put zero in those element of vertical data in correspondence of zero element of lateral data to
            % consider the mask used in lateral data
            vertForce_clear(force_clear==0)=0;
            [vertForce_avg,force_avg]=featureFrictionCalc2_avgLatForce(vertForce_clear,force_clear);
            % plot experimental values (avg and std)            
            limitsXYdata(:,:,j)=featureFrictionCalc3_plotErrorBar(vertForce_avg,force_avg,j,nameScan);
            resFit=featureFrictionCalc4_fittingForceSetpoint(vertForce_avg,force_avg,j,'fitting','Yes','image','Yes');
            fOutlierRemoval_text='';
        else
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%% THIRD CLEARING %%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%------- SETTING PARAMETERS FOR THE EDGE REMOVAL -------%%%%%%%%%%%
            % the user has to choose:
            % 1) the number of points to remove in from a single edge BK-crystal, which contains the spike values
            % 2) the step size (i.e. in each iteration, the size pixel increases until the desired number of point
            
            % ask modalities only once, at the first iterated file
            if j==1
                pixData=zeros(2,1);
                question ={'Maximum pixels to remove from both edges of a segment? ' ...
                    'Enter the step size of pixel loop: '};
                while true
                    pixData = str2double(inputdlg(question,'SETTING PARAMETERS FOR THE EDGE REMOVAL',[1 90]));
                    if any(isnan(pixData)), questdlg('Invalid input! Please enter a numeric value','','OK','OK');
                    else, break
                    end
                end
                % choose the removal modality    
                question= 'Choose the modality of removal outliers';
                options={ ...
                sprintf('1) Apply outlier removal to each segment after pixel reduction.'), ...
                sprintf('2) Apply outlier removal to one large connected segment after pixel reduction.')};                
                fOutlierRemoval = getValidAnswer(question, '', options);
                if fOutlierRemoval==1
                    fOutlierRemoval_text='_SingleSegmentsProcess';
                else
                    fOutlierRemoval_text='_EntireSegmentProcess';                                   
                end

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
            fitResults_fc=zeros(length(arrayPixSizes),2);
            xDataAllPixelSizes=cell(length(arrayPixSizes),1);
            yDataAllPixelSizes=cell(length(arrayPixSizes),1);
            avg_fc_pix=zeros(1,length(arrayPixSizes));
            for pix = arrayPixSizes
                % init matrix.
                force_thirdClearing = zeros(size(force_clear));
                % copy and then put zeros according to the lateral force
                vertForce_thirdClearing = vertForce_clear;
                % process the single fast scan line with a given pixel size. Delete the outliers
                for i=1:size(force_thirdClearing,2)
                    % provide i-th single fast scan line and obtain new processed fast line with new zero
                    % elements
                    latTmp = A1_method3feature_DeleteEdgeDataAndOutlierRemoval(force_clear(:,i), pix, fOutlierRemoval);                                           
                    force_thirdClearing(:,i)=latTmp;
                    % remove the elements in the vertical data where there are zero values in lateral data                    
                    vertTmp=vertForce_thirdClearing(:,i);
                    vertTmp(latTmp==0)=0;
                    vertForce_thirdClearing(:,i)=vertTmp;                    
                    % update dialog box and check if cancel is clicked
                    if(exist('wb','var'))
                        %if cancel is clicked, stop and delete dialog
                        if getappdata(wb,'canceling')
                            error('Manually stopped the process')
                        end
                    end
                    waitbar(i/size(force_clear,2),wb,sprintf('Image %d - Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',j,fOutlierRemoval,pix,max(arrayPixSizes),i,i/size(force_firstClearing,2)*100));
                end
                % to fit, use the average of single fast scan line. In this way, it will be possible track the
                % removal of entire block. Otherwise, prepareCurve provide entire block difficult to
                % distinguish. For example, since there are vertical values higher than the setpoint, the
                % unique function won't provide number of elements equal to the number of setpoint               
                [vertForce_avg,force_avg]=featureFrictionCalc2_avgLatForce(vertForce_thirdClearing,force_thirdClearing);
                % if one of the block in lateral force is totally zeroed because of the pix removal 
                % (very common for large pix size), stop the execution. Since the zeroing is simultaneous to
                % vertical data too, use the latter to easy reference.
                % Moreover, it could happen that by removing edges, the average of vertical data shift away
                % because there is another spike. Stop the calcultion also in this case because low
                % reliability
                SetpFit=unique(round(vertForce_avg,-1));
                if ~isequal(SetpFit,Setpoint)
                    uiwait(msgbox(sprintf('Missing data in the fitting \x2192 stopped calculation!'),''));
                    break
                end
                % obtain the friction coeff as single fitting. No plot
                % fitting the lateral versus vertical data.
                [fitResults,xData,yData]=featureFrictionCalc4_fittingForceSetpoint(vertForce_avg,force_avg,j,'fitting','Yes','imageProcessing','No');
                avg_fc_tmp=fitResults(1);               

                % two way to stop the removal code
                % 1) slope higher than 0.95 has no sense
                % 2) number of overall common vertical force lower than used setpoint
                if avg_fc_tmp > 0.95 %%|| p(1) < 0
                    uiwait(msgbox(sprintf('Slope outside the reasonable range ( 0 < m < 0.95 ) \x2192 stopped calculation!'),''));
                    break
                end
                
                % store the results of every pix size if no break occurred
                fitResults_fc(Cnt,:)=fitResults;
                xDataAllPixelSizes{Cnt}=xData;
                yDataAllPixelSizes{Cnt}=yData;
                avg_fc_pix(Cnt) = fitResults(1);                
                Cnt = Cnt+1;
            end
            % prepare the end data
            pix=arrayPixSizes(1:Cnt-1);
            avg_fc_pix=avg_fc_pix(1:Cnt-1);
            % plot all the frictions coefficient in function of pixel size          
            f2=figure;         
            plot(pix, avg_fc_pix, 'x-','LineWidth',2,'MarkerSize',10,'Color','blue'); grid on
            xlabel('Pixel size','fontsize',15); ylabel('Glass friction coefficient','fontsize',15);
            title(sprintf('Result Method 3 (Mask + Outliers Removal - %s)',fOutlierRemoval_text(2:end)),'FontSize',20);
            if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2); end
            % select the right friction coefficient
            uiwait(msgbox('Click on the plot'));
            idx_x=selectRangeGInput(1,1,0:pixData(2):pixData(1),avg_fc_pix);
            hold on
            scatter(pixData(2)*idx_x-pixData(2),avg_fc_pix(idx_x),400,'pentagram','filled', 'MarkerFaceColor', 'red');
            
            % extract the correct　data depending on the chosen idx              
            resFit=fitResults_fc(idx_x,:);
            vertForce_avg_best=xDataAllPixelSizes{idx_x};
            force_avg_best=yDataAllPixelSizes{idx_x};
            % finish the plot and save
            mainText=sprintf('Result Method 3 (Mask + Outliers Removal - %s) - %s',fOutlierRemoval_text(2:end),nameScan);
            resultChoice= sprintf('Friction coefficient: %0.3g',avg_fc_pix(idx_x));
            title({mainText; resultChoice},'FontSize',20,'interpreter','none');            
            saveas(f2,sprintf('%s/resultMethod3_1_pixelVSfrictionCoeffs_%s%s.tif',newFolder,nameScan,fOutlierRemoval_text))
            close(f2)
            % return to the main general figure where compare all the scans.
            % Plot the errorbar and the fitted curve and take the min max XY values to better figure limits
            figure(f_fcAll)
            limitsXYdata(:,:,j)=featureFrictionCalc3_plotErrorBar(vertForce_avg_best,force_avg_best,j,nameScan);
            featureFrictionCalc4_fittingForceSetpoint(vertForce_avg_best,force_avg_best,j,'fitting','No','imageProcessing','Yes','fitResults',resFit);
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% END METHOD PROCESSING %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % store the results
        resFrictionAllExp(j).slope=resFit(1);
        resFrictionAllExp(j).offset=resFit(2);       
    end    
    
    % find the absolute minimum and maximum in all the data to better show the final results
    absMinX=min(limitsXYdata(1,1,:)); absMaxX=max(limitsXYdata(1,2,:));
    absMinY=min(limitsXYdata(2,1,:)); absMaxY=max(limitsXYdata(2,2,:));
    % prepare the plot for the definitive results
    xlim([absMinX*0.7 absMaxX*1.1]), ylim([absMinY*0.7 absMaxY*1.1])
    xlabel('Setpoint (nN)','Fontsize',15); ylabel('Delta Offset (nN)','Fontsize',15); grid on, grid minor
    legend('Location','northwest','FontSize',15,'Interpreter','none')
    title(sprintf('Delta Offset vs Vertical Force - Method %d %s',method,fOutlierRemoval_text(2:end)),'FontSize',20);
    if ~isempty(secondMonitorMain); objInSecondMonitor(secondMonitorMain,f_fcAll); end
    saveas(f_fcAll,sprintf('%s/resultMethod_%d_DeltaOffsetVSsetpoint%s.tif',newFolder,method,fOutlierRemoval_text))
    uiwait(msgbox('Click to conclude'));
    close(f_fcAll)
    if exist('wb','var')
        delete(wb)
    end     
end
