function [vertForce_secondClearing,force_secondClearing]=featureFrictionCalc1_clearingAndPlotData(vertical_Trace,vertical_ReTrace,force,idxRemovedPortion,newFolder,nameScan,secondMonitorMain,method)
  
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
    % build 1-dimensional array which contain 0 or 1 according to the idx of regions manually removed 
    % (0 = removed slow line)
    array01RemovedRegion=ones(1,size(force_firstClearing,2));
    if ~isempty(idxRemovedPortion)
        for n=1:size(idxRemovedPortion,1)
            array01RemovedRegion(idxRemovedPortion(n,1):idxRemovedPortion(n,2))=0;         
        end
    end
    % using this array (1 ok, 0 not ok), substitute entire lines in the lateral and vertical 
    % data with zero in corrispondence of removed regions
    vertForce_secondClearing=vertForce_firstClearing;
    vertForce_secondClearing(:,array01RemovedRegion==0)=0;
    force_secondClearing=force_firstClearing;
    force_secondClearing(:,array01RemovedRegion==0)=0;
       
    % plot lateral (masked force, N) and vertical data (masked force, N). Not show up but save fig
    featureFrictionCalc6_plotClearedImages(vertForce_secondClearing,force_secondClearing,newFolder,nameScan,secondMonitorMain,method)
end