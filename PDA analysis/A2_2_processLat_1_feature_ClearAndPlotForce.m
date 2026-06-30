%%%%%%%% CLEARING STEPS %%%%%%%%      
function [vertForce_thirdClearing,force_tr_thirdClearing,force_rt_thirdClearing,numRemovedElements_allSteps]=A2_2_processLat_1_feature_ClearAndPlotForce(vert_tr,vert_rt,force_tr,force_rt,mask,idxMon)
% NOTE: doesnt matter the used method. Its just the mask applying and removal of common outliers
% Remove outliers among Vertical Deflection data using a defined threshold of 4nN 
% ==> trace and retrace in vertical deflection should be almost the same.
% This threshold is used as max acceptable difference between trace and retrace of vertical data      
    totElementsBeforeClearing=nnz(~isnan(force_tr));
    %---------------------------%
    %%%%%% FIRST CLEARING %%%%%%%
    %---------------------------%
    Th = 4;
    % average of each single fast line
    vertTrace_avg = mean(vert_tr,'omitnan');
    vertReTrace_avg = mean(vert_rt,'omitnan');
    % find the idx (slow direction) for which the difference 
    % of average vertical force between trace and retrace is acceptable
    Idx = abs(vertTrace_avg - vertReTrace_avg) < Th;
    if ~all(Idx)
        warning('Performed First clearing - presence of outliers among vertical fast scan lines')
    end        
    % using this idx (1 ok, 0 not ok), substitute entire lines in the lateral data with zero
    force_tr_firstClearing = force_tr;    force_tr_firstClearing(:,Idx==0)=NaN;
    force_rt_firstClearing = force_rt;    force_rt_firstClearing(:,Idx==0)=NaN;
    % update the counter of removed elements
    numRemovedElements_1=totElementsBeforeClearing-nnz(~isnan(force_tr_firstClearing));
    numRemovedElements_1=numRemovedElements_1/totElementsBeforeClearing*100;
    % using this idx (1 ok, 0 not ok), substitute entire lines in the vertical data with zero and average
    % trace and retrace vertical data
    vertForceT=vert_tr;    vertForceT(:,Idx==0)=0;
    vertForceR=vert_rt;    vertForceR(:,Idx==0)=0;
    vertForce_firstClearing = ((vertForceT + vertForceR) / 2)*1e9;    
    %----------------------------%
    %%%%%% SECOND CLEARING %%%%%%%
    %----------------------------%
    % remove outliers. NOTE: such a function consider outliers line by line. Therefore, transform force as single vector rather than matrix
    % for better statistics ==> single massive cycle
    vertForce_secondClearing=vertForce_firstClearing;
    force_rt_secondClearing=force_rt_firstClearing;
    % find outliers in force_trace (Foreground data only, to save time, since the background will be removed)
    disp("Running outliers removal of Force-Trace")
    tmp=force_tr_firstClearing;
    tmp(~mask)=nan;
    force_vector=reshape(tmp,1,[]);
    [numRemovedElements_2_1,force_secondClearing_vector]=dynamicOutliersRemoval(force_vector');
    force_tr_secondClearing=reshape(force_secondClearing_vector',size(force_tr_firstClearing));
    % restore BK data
    force_tr_secondClearing(~mask)= force_tr_firstClearing(~mask);
    % propagate nan in other datasets
    vertForce_secondClearing(isnan(force_tr_secondClearing))=nan;
    force_rt_secondClearing(isnan(force_tr_secondClearing))=nan;
    % process retrace
    disp("Running outliers removal of Force-ReTrace")
    tmp=force_rt_secondClearing;
    tmp(~mask)=nan;
    force_vector=reshape(tmp,1,[]);
    [numRemovedElements_2_2,force_secondClearing_vector]=dynamicOutliersRemoval(force_vector');
    force_rt_secondClearing=reshape(force_secondClearing_vector',size(force_rt_firstClearing));
    % restore BK data
    force_rt_secondClearing(~mask)= force_rt_firstClearing(~mask);
    % propagate nan in other datasets
    vertForce_secondClearing(isnan(force_rt_secondClearing))=nan;
    force_tr_secondClearing(isnan(force_rt_secondClearing))=nan;
    numRemovedElements_2=(numRemovedElements_2_1+numRemovedElements_2_2)/totElementsBeforeClearing*100;
    %---------------------------%
    %%%%%% THIRD CLEARING %%%%%%%
    %---------------------------%
    % remove manually regions
    tmp=nnz(~isnan(force_tr_secondClearing));
    [~,force_tr_thirdClearing,force_rt_thirdClearing]=featureRemovePortions(force_tr_secondClearing,"Lateral Force Trace",idxMon, ...
        'additionalImagesToShow',force_rt_secondClearing,'additionalImagesTitleToShow','Lateral Force Retrace','originalDataIndex',2,'normalize',false);
    vertForce_thirdClearing=vertForce_secondClearing;
    vertForce_thirdClearing(isnan(force_tr_thirdClearing))=nan;
    numRemovedElements_3=tmp-nnz(~isnan(force_tr_thirdClearing));
    numRemovedElements_3=numRemovedElements_3/totElementsBeforeClearing*100;
    %----------- final part ------------%
    % for some reasons, the measurements in HV off can be oddly totally wrong when the voltage is positive
    restClearing=nnz(~isnan(force_tr_thirdClearing));
    if restClearing < 5*totElementsBeforeClearing/100
        warndlg(sprintf("ALARM: after clearing, background lateral/vertical data have less than 5%% (%d) of the total elements before cleaning (%d).\nSomething wrong in the data!",restClearing,totElementsBeforeClearing))
    end      
    numRemovedElements_allSteps=[numRemovedElements_1,numRemovedElements_2,numRemovedElements_3];   
end