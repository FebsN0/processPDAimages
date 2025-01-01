function resFrictionAllExp=A1_frictionGlassCalc_method_2_3(AFM_AllScanImages,metadata_AllScan,AFM_AllScan_height_IO,secondMonitorMain,newFolder,choice,nameScan_AllScan,idxRemovedPortion_onlyBK,varargin)

% This function opens the AFM data previously created to calculate the background friction
% coefficient. This method should be more accurated than the method 1.
% 
% This function uses one of two methods depending on the choice
%   2) PDA masking only
%   3) PDA masking + REMOVAL OF OUTLIERS (= spike signal in correspondence with the PDA crystal's edges) line by line
% 
% INPUT:    1) AFM_AllScanImages (trace and retrace | height, lateral and vertical data, Hover Mode off) of ANY SELECTED SCAN
%           2) metadata of ANY SELECTED SCAN
%           3) AFM_height_IO (mask PDA-background 0/1 values) of ANY SELECTED SCAN
%           4) secondMonitorMain
%           5) newFolder: path where store the results
%           5) choice: method 2 or method 3
%               if 3 is applied, two possible approaches:
%                   1: Apply outlier removal to each segment after pixel reduction.
%                   2: Apply outlier removal to one large connected segment after pixel reduction.

    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)

    p=inputParser(); 
    argName = 'Silent';     defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    parse(p,varargin{:});

    clearvars argName defaultVal

    numFiles=length(AFM_AllScanImages);
    limitsXYdata=zeros(2,2,numFiles);
    % init the var where store the different coefficient frictions of any scan image
    resFrictionAllExp=struct('nameScan',[],'slope',[],'offset',[]);
    % open a new figure where plot the fitting curves of all the uploaded friction experiments.
    % if method 2: just forceVSsetpoint of each experiment
    % if method 3: frictionVSpix of each experiment
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
        Lateral_Trace_masked    = (dataSingle(strcmpi([dataSingle.Channel_name],'Lateral Deflection') & strcmpi([dataSingle.Trace_type],'Trace')).AFM_image).*(~AFM_height_IO);
        Lateral_ReTrace_masked  = (dataSingle(strcmpi([dataSingle.Channel_name],'Lateral Deflection') & strcmpi([dataSingle.Trace_type],'ReTrace')).AFM_image).*(~AFM_height_IO);
        vertical_Trace   = (dataSingle(strcmpi([dataSingle.Channel_name],'Vertical Deflection') & strcmpi([dataSingle.Trace_type],'Trace')).AFM_image);
        vertical_ReTrace = (dataSingle(strcmpi([dataSingle.Channel_name],'Vertical Deflection') & strcmpi([dataSingle.Trace_type],'ReTrace')).AFM_image);
        % note: in case of portions previously removed, a specific check is required to not consider the
        % values in corrispondence of removed portions
        for i=1:size(Lateral_Trace_masked,2)
            for n=1:size(idxRemovedPortion,1)
                if i >= idxRemovedPortion(n,1) && i <= idxRemovedPortion(n,2)
                    Lateral_Trace_masked(:,i)=0;
                    Lateral_ReTrace_masked(:,i)=0;
                    vertical_Trace(:,i)=0;
                    vertical_ReTrace(:,i)=0;
                end
            end
        end
        alpha=metadataSingle.Alpha;
        % Calc Delta (offset loop) in BK only
        Delta = (Lateral_Trace_masked + Lateral_ReTrace_masked) / 2;
        % Calc W (half-width loop)
        W = Lateral_Trace_masked - Delta;            
        % convert W into force (in Newton units) using alpha calibration factor and show results.
        force=W*alpha;
        % convert N into nN
        force=force*1e9;
        vertical_Trace=vertical_Trace*1e9;
        vertical_ReTrace=vertical_ReTrace*1e9;

        % plot lateral (masked force, N) and vertical data (masked force, N). Not show up but save fig        
        f1=figure('Visible','off');
        subplot(121)
        imagesc(force)
        c= colorbar; c.Label.String = 'Force [nN]'; c.FontSize = 15;
        title({'Lateral Force in BK regions';'(PDA masked out)'},'FontSize',20)
        xlabel(' fast direction - scan line','FontSize',15), ylabel('slow direction','FontSize',15)
        axis equal, xlim([0 size(force,2)]), ylim([0 size(force,1)])
        subplot(122)
        imagesc(vertical_Trace.*(~AFM_height_IO))
        c= colorbar; c.Label.String = 'Force [nN]'; c.FontSize = 15;
        title({'Vertical Force in BK regions';'(PDA masked out)'},'FontSize',20)
        sgtitle(sprintf('Background of %s',nameScan),'Fontsize',20,'interpreter','none')
        xlabel(' fast direction - scan line','FontSize',15), ylabel('slow direction','FontSize',15)
        axis equal, xlim([0 size(force,2)]), ylim([0 size(force,1)])
        if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
        saveas(f1,fullfile(newFolder,sprintf('resultMethod_mask_2_3_Lat_Vert_ForceInBKregions_scan_%s.tif',nameScan)))
        close(f1)

        %%%%%%% FIRST CLEARING %%%%%%%
        % Remove outliers among Vertical Deflection data using a defined threshold of 4nN 
        % ==> trace and retrace in vertical deflection should be almost the same.
        % This threshold is used as max acceptable difference between trace and retrace of vertical data        
        Th = 4;
        % average of each single fast line
        vertTrace_avg = mean(vertical_Trace);
        vertReTrace_avg = mean(vertical_ReTrace);
        % find the idx (slow direction) for which the difference 
        % of average vertical force between trace and retrace is acceptable
        Idx = abs(vertTrace_avg - vertReTrace_avg) < Th;
        % using this idx, remove strong outliers in entire lines in the lateral force
        force_firstClearing = force(:,Idx==1);
        % prepare the x data for the fitting
        vertForce_firstClearing = (vertical_Trace(:,Idx==1) + vertical_Trace(:,Idx==1)) / 2;

        %%%%%% SECOND CLEARING %%%%%%%
        % build 1-dimensional array which contain 0 or 1 according to the idx of regions manually removed 
        % (0 = removed slow line)
        array01RemovedRegion=ones(1,size(force_firstClearing,2));
        if ~isempty(idxRemovedPortion)
            for n=1:size(idxRemovedPortion,1)
                array01RemovedRegion(idxRemovedPortion(n,1):idxRemovedPortion(n,2))=0;         
            end
        end
        % remove the values in corrispondence of removed regions
        vertForce_secondClearing=vertForce_firstClearing(:,array01RemovedRegion==1);
        force_secondClearing=force_firstClearing(:,array01RemovedRegion==1);

        % depending on the choosen method
        if choice == 2
            figure(f_fcAll)
            % put zero in those element of vertical data in correspondence of zero element of lateral data
            vertForce_secondClearing(force_secondClearing==0)=0;
            [vertForce_avg,force_avg]=feature_avgLatForce(vertForce_secondClearing,force_secondClearing);
            % plot experimental values (avg and std)            
            limitsXYdata(:,:,j)=feature_plotErrorBar(vertForce_avg,force_avg,j,nameScan);
            resFit=feature_fittingForceSetpoint(vertForce_avg,force_avg,j,'fitting','Yes','image','Yes');
            fOutlierRemoval_text='';
        else
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
                wb=waitbar(0/size(force_secondClearing,2),sprintf('Image %d - Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',j,fOutlierRemoval,0,pixData(1),0,0),...
                         'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
                setappdata(wb,'canceling',0);               
            else
                % reset the bar
                waitbar(0/size(force_secondClearing,2),wb,sprintf('Image %d - Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',j,fOutlierRemoval,0,pixData(1),0,0));
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
                force_thirdClearing = zeros(size(force_secondClearing));
                % copy and then put zeros according to the lateral force
                vertForce_thirdClearing = vertForce_secondClearing;
                % process the single fast scan line with a given pixel size. Delete the outliers
                for i=1:size(force_thirdClearing,2)
                    % provide i-th single fast scan line and obtain new processed fast line with new zero
                    % elements
                    latTmp = A1_method3feature_DeleteEdgeDataAndOutlierRemoval(force_secondClearing(:,i), pix, fOutlierRemoval);                                           
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
                    waitbar(i/size(force_secondClearing,2),wb,sprintf('Image %d - Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',j,fOutlierRemoval,pix,max(arrayPixSizes),i,i/size(force_firstClearing,2)*100));
                end
                % to fit, use the average of single fast scan line. In this way, it will be possible track the
                % removal of entire block. Otherwise, prepareCurve provide entire block difficult to
                % distinguish. For example, since there are vertical values higher than the setpoint, the
                % unique function won't provide number of elements equal to the number of setpoint               
                [vertForce_avg,force_avg]=feature_avgLatForce(vertForce_thirdClearing,force_thirdClearing);
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
                [fitResults,xData,yData]=feature_fittingForceSetpoint(vertForce_avg,force_avg,j,'fitting','Yes','imageProcessing','No');
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
            limitsXYdata(:,:,j)=feature_plotErrorBar(vertForce_avg_best,force_avg_best,j,nameScan);
            feature_fittingForceSetpoint(vertForce_avg_best,force_avg_best,j,'fitting','No','imageProcessing','Yes','fitResults',resFit);
        end
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
    title(sprintf('Delta Offset vs Vertical Force - Method %d %s',choice,fOutlierRemoval_text(2:end)),'FontSize',20);
    if ~isempty(secondMonitorMain); objInSecondMonitor(secondMonitorMain,f_fcAll); end
    saveas(f_fcAll,sprintf('%s/resultMethod_%d_DeltaOffsetVSsetpoint%s.tif',newFolder,choice,fOutlierRemoval_text))
    uiwait(msgbox('Click to conclude'));
    close(f_fcAll)
    if exist('wb','var')
        delete(wb)
    end     
end

