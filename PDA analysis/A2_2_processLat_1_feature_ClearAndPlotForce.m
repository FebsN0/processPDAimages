%%%%%%%% CLEARING STEPS %%%%%%%%      
function [vertForce_forthClearing,force_forthClearing]=A2_2_processLat_1_feature_ClearAndPlotForce(vertical_Trace,vertical_ReTrace,force,idxSection,newFolder,nameFig,idxMon)
% NOTE: doesnt matter the used method. Its just the mask applying and removal of common outliers
% Remove outliers among Vertical Deflection data using a defined threshold of 4nN 
% ==> trace and retrace in vertical deflection should be almost the same.
% This threshold is used as max acceptable difference between trace and retrace of vertical data      
    totElementsBeforeClearing=nnz(~isnan(force));
    %%%%%% FIRST CLEARING %%%%%%%
    Th = 4;
    % average of each single fast line
    vertTrace_avg = mean(vertical_Trace,'omitnan');
    vertReTrace_avg = mean(vertical_ReTrace,'omitnan');
    % find the idx (slow direction) for which the difference 
    % of average vertical force between trace and retrace is acceptable
    Idx = abs(vertTrace_avg - vertReTrace_avg) < Th;
    if ~all(Idx)
        warning('Performed First clearing - presence of outliers among vertical fast scan lines')
    end        
    % using this idx (1 ok, 0 not ok), substitute entire lines in the lateral data with zero
    force_firstClearing = force;    force_firstClearing(:,Idx==0)=NaN;
    numRemovedElements_1=totElementsBeforeClearing-nnz(~isnan(force_firstClearing));
    numRemovedElements_1=numRemovedElements_1/totElementsBeforeClearing*100;
    % using this idx (1 ok, 0 not ok), substitute entire lines in the vertical data with zero and average
    % trace and retrace vertical data
    vertForceT=vertical_Trace;      vertForceT(:,Idx==0)=0;
    vertForceR=vertical_ReTrace;    vertForceR(:,Idx==0)=0;
    vertForce_firstClearing = ((vertForceT + vertForceR) / 2)*1e9;    
    %%%%%% SECOND CLEARING %%%%%%%
    % remove outliers. NOTE: such a function consider outliers line by line. Therefore, transform force as single vector rather than matrix
    % for better statistics ==> single massive cycle
    vertForce_secondClearing=vertForce_firstClearing;
    force_vector=reshape(force_firstClearing,1,[]);
    [numRemovedElements_2,force_secondClearing_vector]=dynamicOutliersRemoval(force_vector');
    force_secondClearing=reshape(force_secondClearing_vector',size(force_firstClearing));
    vertForce_secondClearing(isnan(force_secondClearing))=nan;
    numRemovedElements_2=numRemovedElements_2/totElementsBeforeClearing*100;
    %%%%%% THIRD CLEARING %%%%%%%
    % aggressive cleaning. Therefore, let the user choose if it is good idea to clear
    force_thirdClearing=force_secondClearing;
    vertForce_thirdClearing=vertForce_secondClearing;
    tmp=nnz(~isnan(force_secondClearing));
    numRemovedElements_3=0;
    if getValidAnswer("Third Lateral Force clearing step.\nDo you want to perform a more aggressive clearing which remove values higher than a user-defined percentile?",'',{"Y","N"})
        while true
            perc = str2double(inputdlg('Enter a percentile value to exclude lateral force data above that threshold. Use the distribution data for better guidance.','',[1 50],"90"));
            if any(isnan(perc)) || perc <= 0 || perc >= 100
                questdlg('Invalid input! Please enter a numeric value','','OK','OK');
            else
                break
            end
        end        
        for i=1:size(idxSection,2)
            startIdx=idxSection(1,i);
            lastIdx=idxSection(2,i);                      
            force_tmp=force_thirdClearing(:,startIdx:lastIdx);
            maxlimit=prctile(force_tmp(:),perc);
            force_tmp(force_tmp>maxlimit)=nan;
            force_thirdClearing(:,startIdx:lastIdx)=force_tmp;     
        end
        vertForce_thirdClearing(isnan(force_thirdClearing))=nan;
        numRemovedElements_3=tmp-nnz(~isnan(force_thirdClearing));
        numRemovedElements_3=numRemovedElements_3/totElementsBeforeClearing*100;
    end
    %%%%%% FORTH CLEARING %%%%%%%
    % remove manually regions
    tmp=nnz(~isnan(force_thirdClearing));
    [~,force_forthClearing]=featureRemovePortions(force_thirdClearing,"Lateral Force\nAfter automatic clearing",idxMon, ...
        'additionalImagesToShow',force,'additionalImagesTitleToShow','Lateral Force\nBefore clearing process','originalDataIndex',2,'normalize',false);
    vertForce_forthClearing=vertForce_thirdClearing;
    vertForce_forthClearing(isnan(force_forthClearing))=nan;
    numRemovedElements_4=tmp-nnz(~isnan(force_forthClearing));
    numRemovedElements_4=numRemovedElements_4/totElementsBeforeClearing*100;
    %----------- final part ------------%
    % for some reasons, the measurements in HV off can be oddly totally wrong when the voltage is positive
    restClearing=nnz(~isnan(force_forthClearing));
    if restClearing < 5*totElementsBeforeClearing/100
        warndlg(sprintf("ALARM: after clearing, background lateral/vertical data have less than 5%% (%d) of the total elements before cleaning (%d).\nSomething wrong in the data!",restClearing,totElementsBeforeClearing))
    end            
    titleData1="Lateral Force - raw";
    titleData2={"Lateral Force - 1st+2nd clearing";sprintf("VD-4nN (%.2f%%), LD outliers (%.2f%%)",numRemovedElements_1,numRemovedElements_2)};
    if exist("perc","var") && isnumeric(perc)
        titleData3={"Lateral Force - 3rd+4th clearing";sprintf("Removed %.2fth percentile (%.2f%%); manualRemoval (%.2f%%)",perc,numRemovedElements_3,numRemovedElements_4)};    
    else
        titleData3={"Lateral Force - 3rd+4th clearing";sprintf("No 3rd clearing; manualRemoval (%.2f%%)",numRemovedElements_4)};    
    end    
    labelText="Force [nN]";
    showData(idxMon,false,force,titleData1,newFolder,nameFig,"labelBar",labelText,...
        "extraData",{force_secondClearing,force_forthClearing},...
        "extraTitles",{titleData2,titleData3},"extraLabel",{labelText,labelText});
end