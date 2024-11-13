function avg_fc_def=A5_frictionGlassCalc_method3(alpha,AFM_Images,AFM_height_IO,setpoints,secondMonitorMain,newFolder)
%
% This function opens the AFM cropped data previously created to calculate the glass friction
% coefficient. This method is more accurated than the method 2.
% The function has two additional features:
%   1) REMOVAL OF OUTLIERS (= spike signal in correspondence with the PDA crystal's edges) line by line
%   2) 
%
% Author: Bratati Das, Zheng Jianlu
% University of Tokyo
% 
% Author modifications: Altieri F.
% University of Tokyo
%
% Last update 27/6/2024
%
% INPUT:    1) alpha calibration factor
%           2) AFM_cropped_Images (trace and retrace | height, lateral and vertical data)
%           3) AFM_height_IO (mask PDA-background 0/1 values)
%           4) secondMonitorMain
%           5) PixData: contain max size and step of fitlering window
%           5) fOutlierRemoval: mode of outlier removal:
%               1: Apply outlier removal to each segment after pixel reduction.
%               2: Apply outlier removal to one large connected segment after pixel reduction.

    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)


    % extract data (lateral deflection Trace and Retrace, vertical deflection) and then mask (glass-PDA) elementXelement
    % ONLY in correspondence with the glass!
    Lateral_Trace_masked    = (AFM_Images(strcmpi({AFM_Images.Channel_name},'Lateral Deflection') & strcmpi({AFM_Images.Trace_type},'Trace')).AFM_image).*(~AFM_height_IO);
    Lateral_ReTrace_masked  = (AFM_Images(strcmpi({AFM_Images.Channel_name},'Lateral Deflection') & strcmpi({AFM_Images.Trace_type},'ReTrace')).AFM_image).*(~AFM_height_IO);
    vertical_Trace   = (AFM_Images(strcmpi({AFM_Images.Channel_name},'Vertical Deflection') & strcmpi({AFM_Images.Trace_type},'Trace')).AFM_image);
    vertical_ReTrace = (AFM_Images(strcmpi({AFM_Images.Channel_name},'Vertical Deflection') & strcmpi({AFM_Images.Trace_type},'ReTrace')).AFM_image);

    % Calc Delta (offset loop) 
    Delta = (Lateral_Trace_masked + Lateral_ReTrace_masked) / 2;
    % Calc W (half-width loop)
    W = Lateral_Trace_masked - Delta;      
        
    % convert W into force (in Newton units) using alpha calibration factor and show results.
    force=W*alpha;
    % flip and rotate to have the start of scan line to left and the low setpoint to bottom)
    force=rot90(flipud(force));
    vertical_Trace=rot90(flipud(vertical_Trace));
    vertical_ReTrace=rot90(flipud(vertical_ReTrace));
    % plot lateral (masked force, N) and vertical data (masked force, N)
    % NOTE: vertical data is not directly masked, rather just only for the rapresentation to provide better show
    f1=figure;
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
    subplot(121)
    imagesc(flip(force))
    c= colorbar; c.Label.String = 'Force [N]'; c.FontSize = 15;
    title({'Force in glass regions';'(PDA masked out)'},'FontSize',20)
    xlabel(' fast direction - scan line','FontSize',15), ylabel('slow direction','FontSize',15)
    axis equal, xlim([0 size(force,2)]), ylim([0 size(force,1)])
    subplot(122)
    imagesc(flip(vertical_Trace.*(~rot90(flipud(AFM_height_IO)))))
    c= colorbar; c.Label.String = 'Force [N]'; c.FontSize = 15;
    title('Vertical Deflection (masked)','FontSize',20)
    xlabel(' fast direction - scan line','FontSize',15), ylabel('slow direction','FontSize',15)
    axis equal, xlim([0 size(force,2)]), ylim([0 size(force,1)])
    saveas(f1,sprintf('%s/resultA5method3_1_ForceInGlassRegionsAndVerticalDeflectionN.tif',newFolder))
    
%%%%%%%%%%%------- SETTING PARAMETERS FOR THE EDGE REMOVAL -------%%%%%%%%%%%
    % the user has to choose the number of points
    % in a single fast scan line to consider in order to remove the edge spikes data
    pixData=zeros(2,1);
    question ={'How many pixels to get remove from both edges of the segment? ' ...
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
    wb=waitbar(0/size(force,1),sprintf(' Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',fOutlierRemoval,0,pixData(1),0,0),...
             'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);
    % open a new figure where plot the fitting curve
    f2=figure;
    if ~isempty(secondMonitorMain); objInSecondMonitor(secondMonitorMain,f2); end
    xlim([min(min(vertical_Trace))*0.9 max(max(vertical_Trace))*1.1])
    ylim([min(min(force))*0.9 max(max(force))*1.1])
    Cnt=1;
    for pix = 0:pixData(2):pixData(1)
        % init matrix with the same size of cropped AFM image. Double is already default
        filteredForce = zeros(size(force));
                             
        % process the single fast scan line with a given pixel size
        for i=1:size(force,1)
            filteredForce(i,:) = A5_method3feature_DeleteEdgeDataAndOutlierRemoval(force(i,:), pix, fOutlierRemoval);
            % update dialog box and check if cancel is clicked
            if(exist('wb','var'))
                %if cancel is clicked, stop and delete dialog
                if getappdata(wb,'canceling')
                    break
                end
            end
            waitbar(i/size(force,1),wb,sprintf(' Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',fOutlierRemoval,pix,pixData(1),i,i/size(force,1)*100));
        end           
       
        % calc average along fast scan line, ignore zero values
        force_avg = zeros(1, size(force,1));
        for i=1:size(force,1)
            tmp = filteredForce(i,:);
            force_avg(i) = mean(tmp(tmp~=0));
        end

        % Detect over the threshold. Remove those with vertical force values too outside from theoritical value
        Th = 0.4e-8;
        vertTrace_avg = mean(vertical_Trace,2);
        vertReTrace_avg = mean(vertical_ReTrace,2);
        Idx = abs(vertTrace_avg - vertReTrace_avg) < Th;
        % based on the idx, remove the outliers
        force_avg_fix = force_avg(Idx);
        vert_avg_fix = (vertTrace_avg + vertReTrace_avg) / 2;
        vert_avg_fix = vert_avg_fix(Idx);
        % remove NaN data
        force_avg_fix = force_avg_fix(~isnan(force_avg_fix));
        vert_avg_fix = vert_avg_fix(~isnan(force_avg_fix));
        setpointFitting=unique(round(vert_avg_fix,9));

        % delete previous experimental data, keep curve fitting. Update the latter
        if exist('xyExp','var')
            delete(xyExp)
        end

        hold on
        xyExp=scatter(vert_avg_fix, force_avg_fix, 100,'pentagram','filled', 'MarkerFaceColor', 'green','DisplayName','experimental data');
        xlabel('Set Point (N)'); ylabel('Delta Offset (N)');
        % Linear fitting
        [xData, yData] = prepareCurveData(vert_avg_fix,force_avg_fix);
        % Set up fittype and options.
        ft = fittype( 'poly1' ); opts = fitoptions( 'Method', 'LinearLeastSquares' ); opts.Robust = 'LAR';
        % Fit model to data.
        fitresult = fit( xData, yData, ft, opts );
        p(1)=fitresult.p1;
        p(2)=fitresult.p2;
        xfit=linspace(min(xData),max(xData),100);
        yfit=xfit*p(1)+p(2);
        xyFit=plot(xfit, yfit, 'r-.','DisplayName','Fitted data'); grid on

        legend([xyExp(1),xyFit(1)],'Location','northwest','FontSize',15)
        eqn = sprintf('Last executed Linear fitting: y = %0.3g x + %0.3g', p(1), p(2));
        title({'Delta Offset vs Set Point'; eqn},'FontSize',15);
        hold off
        
        % Store coef data
        avg_fc(Cnt) = p(1);
        pixx(Cnt) = pix;
        Cnt = Cnt+1;
        
        % since slope higher than 0.95 has no sense, the loop will be stopped. In theory max 1, but it will be
        % never such value
        if p(1) > 0.95 %%|| p(1) < 0
            uiwait(msgbox(sprintf('Slope outside the reasonable range ( 0 < m < 0.95 ) \x2192 stopped calculation!'),''));
            break
        elseif length(setpointFitting) < length(setpoints)
            uiwait(msgbox(sprintf('Missing data in the fitting \x2192 stopped calculation!'),''));
            break
        end
        
    end
    saveas(f2,sprintf('%s/resultA5method3_2_DeltaOffsetVSsetpoint.tif',newFolder))
    close(f2)
    delete(wb)
    f3=figure;
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f3); end
    plot(pixx, avg_fc, 'bx-'); grid on
    xlabel('Pixel size'); ylabel('Glass friction coefficient');
    title('Result Method 3 (Mask + Outliers Removal','FontSize',16);
    
    question='Select the method to extrapolate the definitive glass friction';
    options= {'1) select a specific point','2) average between two selected points'};
    answer=getValidAnswer(question,'',options);
    uiwait(msgbox('Click on the plot'));

    if answer == 1   
        idx_x=selectRangeGInput(1,1,0:pixData(2):pixData(1),avg_fc);
        hold on
        scatter(pixData(2)*idx_x-pixData(2),avg_fc(idx_x),200,'pentagram','filled', 'MarkerFaceColor', 'red');
        avg_fc_def=avg_fc(idx_x);
        text='Selected';
    else
        range_selected=selectRangeGInput(2,1,0:pixData(2):pixData(1),avg_fc);
        hold on
        scatter(pixData(2)*range_selected-pixData(2),avg_fc(range_selected),200,'pentagram','filled', 'MarkerFaceColor', 'red');
        range_selected=sort(range_selected);
        avg_fc_def=mean(avg_fc(range_selected(1):range_selected(2)));
        text='Averaged';
    end
    resultChoice= sprintf('%s friction coefficient: %0.3g',text,avg_fc_def);
    title({'Result Method 3 (Mask + Outliers Removal)'; resultChoice},'FontSize',16);
    saveas(f3,sprintf('%s/resultA5method3_3_pixelVSfrictionCoeffs.tif',newFolder))
end