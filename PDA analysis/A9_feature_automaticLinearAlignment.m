function [AFM_IO_3_BFaligned,AFM_Elab,details_it_reg,rect] = A9_feature_automaticLinearAlignment(AFM_IO,BF_IO,AFM_Elab,locationAFM2toBF1,max_c_it_OI,secondMonitorMain,newFolder)
    wb=waitbar(0,'Initializing Iterative Cross Correlation','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);         
    rotation_deg_tot=0;                
    % setting the parameters
    cycleParameters=zeros(3,1);
    question ={'Enter the number of iterations:' ...
        'Enter the step in pixel to increase/decrease during the resize:'...
        'Enter the step in degree° to rotate clock-wise/counter clock-wise:'...
        'How many attempts to halves the steps in case local maximum is not found?'};
    valueDefault = {'100','4','4','4'};
    while true
        cycleParameters = str2double(inputdlg(question,'Setting parameters for the alignment',[1 80],valueDefault));
        if any(isnan(cycleParameters)), questdlg('Invalid input! Please enter a numeric value','','OK','OK');
        else, break
        end
    end
    Limit_Cycles=cycleParameters(1);
    StepSizeMatrix=cycleParameters(2);
    Rot_par=cycleParameters(3);
    maxAttempts=cycleParameters(4);    
    % init vars. Everytime the cross-correlation is better than the previous, increase z
    N_cycles_opt=1; z=0;
    % Init the var where keep information of any transformationù
    % 1° col: resize operation (0 = no, 1 = yes)
    % 2° col: save the new matrix size (row) OR the rotation angle
    % 3° col: save the new matrix size (col) OR NaN
    details_it_reg = zeros(Limit_Cycles,2);
    before2=datetime('now');   
    % not padded (identical to AFM_IO_1_BFscaled, it has been deleted to not be confused which one to use)
    moving_OPT=AFM_IO(locationAFM2toBF1(3):locationAFM2toBF1(4),locationAFM2toBF1(1):locationAFM2toBF1(2));
    % init plot where show overlapping of AFM-BF and trend of max correlation value
    h_it=figure;
    f2max=figure; grid on
    max_c_it_OI_prev=max_c_it_OI;
    maxC_original = max_c_it_OI;
    h = animatedline('Marker','o');
    addpoints(h,0,1)
    ylabel('Cross-correlation score (%)','FontSize',12), xlabel('# cycles','FontSize',12)        
    % prepare the field where store the iteratively modified AFM data
    for flag_AFM=1:size(AFM_Elab,2)
        AFM_Elab(flag_AFM).AFM_aligned=AFM_Elab(flag_AFM).AFM_scaled;
    end
    while(N_cycles_opt<=Limit_Cycles)
        if(exist('wb','var'))
            %if cancel is clicked, stop
            if getappdata(wb,'canceling')
               break
            end
        end
        waitbar(N_cycles_opt/Limit_Cycles,wb,sprintf('Processing the EXP/RED/ROT optimization. Cycle %d / %d',N_cycles_opt,Limit_Cycles));
        % init
        moving_iterative=cell(1,4); max_c_iterative=zeros(1,4); imax_iterative=zeros(1,4); sz_iterative=zeros(4,2);
        textFprintf={'Expansion','Reduction','Counter ClockWise Rotation','ClockWise Rotation'};
        % 1: Oversize - 2 : Undersize - 3 : PosRot - 4 : NegRot
        moving_iterative{1} = imresize(moving_OPT,size(moving_OPT)+abs(StepSizeMatrix));
        moving_iterative{2} = imresize(moving_OPT,size(moving_OPT)-abs(StepSizeMatrix));
        moving_iterative{3} = imrotate(moving_OPT,Rot_par,'nearest','loose');
        moving_iterative{4} = imrotate(moving_OPT,-Rot_par,'nearest','loose');
        for i=1:4
            [max_c_it_OI,imax,sz] = A9_feature_crossCorrelationAlignmentAFM(BF_IO,moving_iterative{i},'runAlignAFM',false);
            max_c_iterative(i)=max_c_it_OI;
            imax_iterative(i)=imax;
            sz_iterative(i,:) = sz;
        end
        % if the max value of the new cross-correlation is better than the previous saved one, then
        % update. Save also the index for a new shift
        if(max(max_c_iterative)>max_c_it_OI_prev)
            % reset the attemptChanges
            attemptChanges=0;
            z=z+1;
            [a,b]=max(max_c_iterative);
            max_c_it_OI_prev=a;
            imax_OI=imax_iterative(b);   % required to shift the image
            size_OI = sz_iterative(b,:);
            % save the best moving AFM image
            moving_OPT= moving_iterative{b};
            % adjust any AFM data channels into FIELD AFM_image (Lateral deflection, etc etc) every step based
            % on the OPT process. NOTE: Indipendent from BF processing
            switch b
                case {1,2} 
                    if b == 1, StepSizeMatrix=abs(StepSizeMatrix); else, StepSizeMatrix=-abs(StepSizeMatrix); end
                    for flag_AFM=1:size(AFM_Elab,2)
                        AFM_Elab(flag_AFM).AFM_aligned=imresize(AFM_Elab(flag_AFM).AFM_aligned,size(AFM_Elab(flag_AFM).AFM_aligned)+StepSizeMatrix);
                    end
                    % keep track
                    details_it_reg(z,1)=1;
                    details_it_reg(z,2)=StepSizeMatrix;
                case {3,4}
                    if b == 3, Rot_par=abs(Rot_par); else, Rot_par=-abs(Rot_par); end
                    for flag_AFM=1:size(AFM_Elab,2)
                        AFM_Elab(flag_AFM).AFM_aligned=imrotate(AFM_Elab(flag_AFM).AFM_aligned,Rot_par,'bilinear','loose');
                    end
                    % keep track
                    details_it_reg(z,1)=0;
                    details_it_reg(z,2)=Rot_par;
                    rotation_deg_tot=rotation_deg_tot+Rot_par;
            end
            fprintf('\n %s Scaling Optimization Found.\n\tMatrix Size: %dx%d\n\tTotal rotation:%0.2f°\n', textFprintf{b}, size(moving_OPT),rotation_deg_tot)

            % update the score
            figure(f2max)
            score = max_c_it_OI_prev/maxC_original;
            addpoints(h,N_cycles_opt, score)
            drawnow
            
            % adjust the AFM height 0/1 image, dont run FFT, just alignment section and generate the
            % new AFM_IO corrected and padded with same BF_IO size
            [~,~,~,~,rect,AFM_IO_3_BFaligned] = A9_feature_crossCorrelationAlignmentAFM(BF_IO,moving_OPT,'runFFT',false,'idxCCMax',imax_OI,'sizeCCMax',size_OI);   
            figure(h_it);
            if exist('pairAFM_BF','var')
                delete(pairAFM_BF)
            end
            pairAFM_BF=imshowpair(BF_IO,AFM_IO,'falsecolor');
            % update the cycle
            N_cycles_opt=N_cycles_opt+1;
        else
            % if there are no updates, a maximum local is likely to be found, therefore reduce StepSizeMatrix and rotaion degree.
            % If there are no updates three consecutive times when changing the StepSize, then the entire process stops
            StepSizeMatrix=ceil((StepSizeMatrix/2));
            Rot_par=Rot_par/2;
            N_cycles_opt=N_cycles_opt+1;
            attemptChanges=attemptChanges+1;
            fprintf('\nA local maximum may have been found. Halved parameters. Attempt %d of %d\n\t\tStepSizeMatrix: %.2f\n\t\tRot_par: %.2f\n',attemptChanges,maxAttempts,StepSizeMatrix,Rot_par)
            if(attemptChanges==maxAttempts)
                break
            end
        end
    end
    %%%% end iteration %%%
    % remove the all zero elements
    tmp=details_it_reg(1:z,:);
    details_it_reg = tmp;
    % calc the calculates the time taken for the entire process
    final_time2=minus(datetime('now'),before2);
    waitbar(1/1,wb,'Completed the EXP/RED/ROT optimization');
    uiwait(msgbox(sprintf('Performed %d Cycles in %3.2f min',N_cycles_opt,minutes(final_time2))))            
    figure(f2max)
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2max); end
    title('Trend Cross-correlation score (max value among the four different image editing)','FontSize',14)
    saveas(f2max,sprintf('%s/resultA9_4_TrendCross-correlationScore_EndIterativeProcess.tif',newFolder))
    close(f2max), close(h_it)
    if(exist('wb','var'))
        delete (wb)
    end    
end