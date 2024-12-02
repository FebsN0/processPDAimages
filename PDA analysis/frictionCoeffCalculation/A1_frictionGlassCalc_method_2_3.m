function resFit_friction=A1_frictionGlassCalc_method_2_3(AFM_AllScanImages,metadata_AllScan,AFM_AllScan_height_IO,secondMonitorMain,newFolder,choice,nameScan_AllScan,varargin)

% This function opens the AFM data previously created to calculate the background friction
% coefficient. This method should be more accurated than the method 1.
% 
% This function uses one of two methods depending on the choice
%   2) PDA masking only
%   3) PDA masking + REMOVAL OF OUTLIERS (= spike signal in correspondence with the PDA crystal's edges) line by line
% 
% Author: Bratati Das, Zheng Jianlu
% University of Tokyo
% 
% Author modifications: Altieri F.
% University of Tokyo
%
% Last update 28/11/2024
%
% INPUT:    1) AFM_AllScanImages (trace and retrace | height, lateral and vertical data, Hover Mode off) of ANY SELECTED SCAN
%           2) metadata of ANY SELECTED SCAN
%           3) AFM_height_IO (mask PDA-background 0/1 values) of ANY SELECTED SCAN
%           4) secondMonitorMain
%           5) newFolder: path where store the results
%           5) choice of OutlierRemoval application
%               if applied, two possible approaches:
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
    
    resFit_friction=zeros(numFiles,2);
    % open a new figure where plot the fitting curves of all the uploaded friction experiments.
    % if method 2: just forceVSsetpoint of each experiment
    % if method 3: frictionVSpix of each experiment
    f_fcAll=figure; hold on

    
    for j=1:numFiles
        % extract the needed data
        dataSingle=AFM_AllScanImages{j};
        metadataSingle=metadata_AllScan{j};
        numSetpoint=length(metadataSingle.SetP_N);
        AFM_height_IO=AFM_AllScan_height_IO{j};
        nameScan=nameScan_AllScan{j};
        % extract data (lateral deflection Trace and Retrace, vertical deflection) and then mask (BK-PDA)
        % elementXelement ==> 
        %       1 (crystal)   => 0
        %       0 (BK)        => 1
        Lateral_Trace_masked    = (dataSingle(strcmpi([dataSingle.Channel_name],'Lateral Deflection') & strcmpi([dataSingle.Trace_type],'Trace')).AFM_image).*(~AFM_height_IO);
        Lateral_ReTrace_masked  = (dataSingle(strcmpi([dataSingle.Channel_name],'Lateral Deflection') & strcmpi([dataSingle.Trace_type],'ReTrace')).AFM_image).*(~AFM_height_IO);
        vertical_Trace   = (dataSingle(strcmpi([dataSingle.Channel_name],'Vertical Deflection') & strcmpi([dataSingle.Trace_type],'Trace')).AFM_image);
        vertical_ReTrace = (dataSingle(strcmpi([dataSingle.Channel_name],'Vertical Deflection') & strcmpi([dataSingle.Trace_type],'ReTrace')).AFM_image);
        alpha=metadataSingle.Alpha;
        % Calc Delta (offset loop) in BK only
        Delta = (Lateral_Trace_masked + Lateral_ReTrace_masked) / 2;
        % Calc W (half-width loop)
        W = Lateral_Trace_masked - Delta;            
        % convert W into force (in Newton units) using alpha calibration factor and show results.
        force=W*alpha;
        % flip and rotate to have the start of scan line to left and the low setpoint to bottom)
        force=rot90(flipud(force));
        vertical_Trace=rot90(flipud(vertical_Trace));
        vertical_ReTrace=rot90(flipud(vertical_ReTrace));
        % convert N into nN
        force=force*1e9;
        vertical_Trace=vertical_Trace*1e9;
        vertical_ReTrace=vertical_ReTrace*1e9;

        % plot lateral (masked force, N) and vertical data (masked force, N). Not show up but save fig
        
        f1=figure('Visible','off');
        subplot(121)
        imagesc(flip(force))
        c= colorbar; c.Label.String = 'Force [nN]'; c.FontSize = 15;
        title({'Lateral Force in BK regions';'(PDA masked out)'},'FontSize',20)
        xlabel(' fast direction - scan line','FontSize',15), ylabel('slow direction','FontSize',15)
        axis equal, xlim([0 size(force,2)]), ylim([0 size(force,1)])
        subplot(122)
        imagesc(flip(vertical_Trace.*(~rot90(flipud(AFM_height_IO)))))
        c= colorbar; c.Label.String = 'Force [nN]'; c.FontSize = 15;
        title({'Vertical Force in BK regions';'(PDA masked out)'},'FontSize',20)
        sgtitle(sprintf('Background of %s',nameScan),'Fontsize',20,'interpreter','none')
        xlabel(' fast direction - scan line','FontSize',15), ylabel('slow direction','FontSize',15)
        axis equal, xlim([0 size(force,2)]), ylim([0 size(force,1)])
        if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
        saveas(f1,fullfile(newFolder,sprintf('resultMethod_2_3_Lat_Vert_ForceInBKregions_scan_%s.tif',nameScan)))
        close(f1)


        % Remove outliers using a defined threshold of 4nN ==> not reliable data ==> trace and retrace in vertical
        % should be almost the same.
        % This threshold is used as max acceptable difference between trace and retrace of vertical data        
        Th = 4;
        % average of each single fast line
        vertTrace_avg = mean(vertical_Trace,2);
        vertReTrace_avg = mean(vertical_ReTrace,2);
        % find the idx (slow direction) for which the difference 
        % of average vertical force between trace and retrace is acceptable
        Idx = abs(vertTrace_avg - vertReTrace_avg) < Th;
        % using this idx, remove outliers in entire lines in the lateral force
        force_fixed = force(Idx,:);
        % prepare the x data for the fitting
        vertForce_avg_fix = (vertTrace_avg(Idx,:) + vertReTrace_avg(Idx)) / 2;

        % depending on the choosen method
        if choice == 2
            force_fixed_avg=avgLatForce(force_fixed,vertForce_avg_fix);
            figure(f_fcAll)
            plot(vertForce_avg_fix, force_fixed_avg, 'x','color',globalColor(j),'DisplayName',sprintf('Experiment %s',nameScan),'MarkerSize',10);
            limitsXYdata(:,:,j)=[min(vertForce_avg_fix) max(vertForce_avg_fix); min(force_fixed_avg) max(force_fixed_avg)];
            resFit_friction(j,:)=fittingForceSetpoint(vertForce_avg_fix,force_fixed_avg,j);
            
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
                            
                % show a dialog box indicating the index of fast scan line along slow direction and which pixel size is processing
                wb=waitbar(0/size(force_fixed,1),sprintf('Image %d - Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',j,fOutlierRemoval,0,pixData(1),0,0),...
                         'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
                setappdata(wb,'canceling',0);               
            else
                % reset the bar
                waitbar(0/size(force_fixed,1),wb,sprintf('Image %d - Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',j,fOutlierRemoval,0,pixData(1),0,0));
            end
            
            % start the counter for removal and init variables where store all the results, in order to
            % extract the desired one
            Cnt=1;
            arrayPixSizes=0:pixData(2):pixData(1);
            avg_fc_pix=zeros(1,length(arrayPixSizes));
            fitResults_fc=zeros(length(arrayPixSizes),2);
            pixx=zeros(1,length(arrayPixSizes));
            xDataAllPixelSizes=cell(length(arrayPixSizes),1);
            for pix = arrayPixSizes
                % init matrix.
                filteredForce = zeros(size(force_fixed));                                     
                % process the single fast scan line with a given pixel size
                for i=1:size(force_fixed,1)
                    filteredForce(i,:) = A1_method3feature_DeleteEdgeDataAndOutlierRemoval(force_fixed(i,:), pix, fOutlierRemoval);
                    % update dialog box and check if cancel is clicked
                    if(exist('wb','var'))
                        %if cancel is clicked, stop and delete dialog
                        if getappdata(wb,'canceling')
                            error('Manually stopped the process')
                        end
                    end
                    waitbar(i/size(force_fixed,1),wb,sprintf('Image %d - Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',j,fOutlierRemoval,pix,pixData(1),i,i/size(force_fixed,1)*100));
                end
                % get the average of the removed-pixel lateral force
                [filteredForce_avg,numSetpFit]=avgLatForce(filteredForce,vertForce_avg_fix);
                % obtain the friction coeff as single fitting
                [fitResults,xData]=fittingForceSetpoint(vertForce_avg_fix,filteredForce_avg);
                fitResults_fc(Cnt,:)=fitResults;
                xDataAllPixelSizes{Cnt}=xData;
                avg_fc_pix(Cnt) = fitResults_fc(Cnt);
                pixx(Cnt) = pix;
                

                % two way to stop the removal code
                % 1) slope higher than 0.95 has no sense
                % 2) number of overall common vertical force lower than used setpoint
                if avg_fc_pix(Cnt) > 0.95 %%|| p(1) < 0
                    uiwait(msgbox(sprintf('Slope outside the reasonable range ( 0 < m < 0.95 ) \x2192 stopped calculation!'),''));
                    break
                elseif numSetpFit < numSetpoint
                    uiwait(msgbox(sprintf('Missing data in the fitting \x2192 stopped calculation!'),''));
                    break
                end
                Cnt = Cnt+1;
            end
            
            % plot all the frictions coefficient in function of pixel size          
            f2=figure;         
            plot(pixx, avg_fc_pix, 'x-','LineWidth',2,'MarkerSize',10,'Color','blue'); grid on
            xlabel('Pixel size','fontsize',15); ylabel('Glass friction coefficient','fontsize',15);
            title('Result Method 3 (Mask + Outliers Removal)','FontSize',20);
            if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2); end


            % question='Select the method to extrapolate the definitive background friction';
            % options= {'1) select a specific point','2) average between two selected points'};
            % answer=getValidAnswer(question,'',options);
            uiwait(msgbox('Click on the plot'));
        
            % if answer == 1   
            idx_x=selectRangeGInput(1,1,0:pixData(2):pixData(1),avg_fc_pix);
            hold on
            scatter(pixData(2)*idx_x-pixData(2),avg_fc_pix(idx_x),400,'pentagram','filled', 'MarkerFaceColor', 'red');
            avg_fc_def=avg_fc_pix(idx_x);
            text='Selected';
            % else
            %     range_selected=selectRangeGInput(2,1,0:pixData(2):pixData(1),avg_fc);
            %     hold on
            %     scatter(pixData(2)*range_selected-pixData(2),avg_fc(range_selected),200,'pentagram','filled', 'MarkerFaceColor', 'red');
            %     range_selected=sort(range_selected);
            %     avg_fc_def=mean(avg_fc(range_selected(1):range_selected(2)));
            %     text='Averaged';
            % end
            mainText=sprintf('Result Method 3 (Mask + Outliers Removal) - %s',nameScan);
            resultChoice= sprintf('%s friction coefficient: %0.3g',text,avg_fc_def);
            title({mainText; resultChoice},'FontSize',20,'interpreter','none');            
            saveas(f2,sprintf('%s/resultMethod3_pixelVSfrictionCoeffs_%s.tif',newFolder,nameScan))
            close(f2)

            resFit_friction(j,[1 2])=fitResults_fc(idx_x,:);
            xdataDef=xDataAllPixelSizes{idx_x};
            xfit=linspace(min(xdataDef),max(xdataDef),100);
            yfit=xfit*resFit_friction(j,1)+resFit_friction(j,2);
            hold on
            if resFit_friction(j,2) < 0
                signM='-';
            else
                signM='+';
            end
            plot(xfit, yfit, '-.','color',globalColor(j),'DisplayName',sprintf('%s: %0.3g x %s %0.3g',nameScan,resFit_friction(j,1),signM,abs(resFit_friction(j,2))),'LineWidth',2);  
            limitsXYdata(:,:,j)=[min(xfit) max(xfit); min(yfit) max(yfit)];
        end 
    end

    % find the absolute minimum and maximum in all the data to better show the final results
    absMinX=min(limitsXYdata(1,1,:)); absMaxX=max(limitsXYdata(1,2,:));
    absMinY=min(limitsXYdata(2,1,:)); absMaxY=max(limitsXYdata(2,2,:));
    % prepare the plot for the definitive results
    xlim([absMinX*0.7 absMaxX*1.1]), ylim([absMinY*0.7 absMaxY*1.1])
    xlabel('Setpoint (nN)','Fontsize',15); ylabel('Delta Offset (nN)','Fontsize',15); grid on, grid minor
    legend('Location','northwest','FontSize',15,'Interpreter','none')
    title(sprintf('Delta Offset vs Vertical Force - Method %d',choice),'FontSize',20);
    if ~isempty(secondMonitorMain); objInSecondMonitor(secondMonitorMain,f_fcAll); end
    saveas(f_fcAll,sprintf('%s/resultMethod_%d_DeltaOffsetVSsetpoint.tif',newFolder,choice))
    close(f_fcAll)

    if exist('wb','var')
        delete(wb)
    end          
end

 
function [force_fixed_avg,numSetpFit]=avgLatForce(force_fixed,vert_avg_fix)    
    force_fixed_avg = zeros(1, size(force_fixed,1));
    % average fast line of lateral force ignoring zero values
    for i=1:size(force_fixed,1)
        tmp = force_fixed(i,:);
        force_fixed_avg(i) = mean(tmp(tmp~=0));
    end  
    % remove nan data and lines from vertical force using lateral force
    force_fixed_avg = force_fixed_avg(~isnan(force_fixed_avg));
    vert_avg_fix = vert_avg_fix(~isnan(force_fixed_avg));
    numSetpFit=length(unique(vert_avg_fix));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% SAME FUNCTION FOR METHOD 2 and 3 but method 3 uses this function %%%
%%% many times depending on pix value                                %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Output = fitting results. Useful to plot the results of every methods for better comparison
function [p,xData]=fittingForceSetpoint(x,y,varargin)
    % Linear fitting
    [xData, yData] = prepareCurveData(x,y');
    % Set up fittype and options.
    ft = fittype( 'poly1' ); opts = fitoptions( 'Method', 'LinearLeastSquares' ); opts.Robust = 'LAR';
    % Fit model to data.
    fitresult = fit( xData, yData, ft, opts );
    p(1)=fitresult.p1;
    p(2)=fitresult.p2;
    % in case of method 2, plot the relation of a given experiment.
    % in case of method 3, avoid to plot every curve
    if nargin == 3
        xfit=linspace(min(xData),max(xData),100);
        yfit=xfit*p(1)+p(2);
        if p(2) < 0
            signM='-';
        else
            signM='+';
        end
        plot(xfit, yfit, '-.','color',globalColor(varargin{1}),'DisplayName',sprintf('Fitted data: %0.3g x %s %0.3g',p(1),signM,abs(p(2))),'LineWidth',2);    
    end
end               


% pseudo global variable
function col = globalColor(n)
    colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k','#FF00FF','#00FF00','#0000FF','#FF0000'};
    col=colors{n};
end