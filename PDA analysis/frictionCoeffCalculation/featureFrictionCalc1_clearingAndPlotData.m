function [vertForce_thirdClearing,force_thirdClearing]=featureFrictionCalc1_clearingAndPlotData(vertical_Trace,vertical_ReTrace,setpoints,maxSetpointsAllFile,force,idxSection,idxRemovedPortion,newFolder,nameScan,secondMonitorMain,method)
  
    %%%%%%% FIRST CLEARING %%%%%%%
    % Remove outliers among Vertical Deflection data using a defined threshold of 4nN 
    % ==> trace and retrace in vertical deflection should be almost the same.
    % This threshold is used as max acceptable difference between trace and retrace of vertical data        
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
                vertForce_thirdClearing(:,idxRemovedPortion(1):idxRemovedPortion(2))=0;
                force_thirdClearing(:,idxRemovedPortion(1):idxRemovedPortion(2))=0;
            else
                % remove portions
                vertForce_thirdClearing(idxRemovedPortion(3):idxRemovedPortion(4),idxRemovedPortion(1):idxRemovedPortion(2))=0;
                force_thirdClearing(idxRemovedPortion(3):idxRemovedPortion(4),idxRemovedPortion(1):idxRemovedPortion(2))=0;
            end
        end
    end
    % using this array (1 ok, 0 not ok), substitute entire lines in the lateral and vertical 
    % data with zero in corrispondence of removed regions

    % plot lateral (masked force, N) and vertical data (masked force, N). Not show up but save fig
    featureFrictionCalc6_plotClearedImages(vertForce_thirdClearing,force_thirdClearing,maxSetpointsAllFile,newFolder,nameScan,secondMonitorMain,method)
end