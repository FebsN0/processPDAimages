function A0_feature_1_FrictionCoefficientCalc(allData,otherParameters,SaveFigFolder,idxMon)
    close all
         
    %{
    % to extract the friction coefficient, choose which method use.
    question=sprintf('Is the data containing PDA or only background?');
    options={ ...
        sprintf('1) only Background'), ...
        sprintf('2) PDA+Background')};
    if getValidAnswer(question, '', options)==1
        % get the friction from ONLY BACKGROUND .jpk file experiments.
        typeData = "BKOnly";
        % get the friction from BACKGROUND+PDA .jpk file experiments.
        typeData = "BK_PDA";        
    end
    %}
    question=sprintf('Calculate the friction coefficient for each section or after assembling?');
    options={ ...
        sprintf('1) Single section'), ...
        sprintf('2) Post section assembly')};
    if getValidAnswer(question, '', options)==1
        % get the friction from ONLY BACKGROUND .jpk file experiments.
        flag_processSingleSection = true;
    else
        % get the friction from BACKGROUND+PDA .jpk file experiments.
        flag_processSingleSection = false;        
    end
    clear options questions    
    if ~flag_processSingleSection
        [AFM_images_assembled,metaData] = A2_sortAndAssemblySections(allData,otherParameters,1);
        SaveFigSingleSectionsFolder=fullfile(SaveFigFolder,"assembled");
        verForce=AFM_images_assembled(strcmp([AFM_images_assembled.Channel_name],"Vertical Force") & strcmp([AFM_images_assembled.Trace_type],"Avg")).AFM_images_2_PostProcessed;
        latForce=AFM_images_assembled(strcmp([AFM_images_assembled.Channel_name],"Lateral Force") & strcmp([AFM_images_assembled.Trace_type],"Average")).AFM_images_2_PostProcessed;
        mask=AFM_images_assembled(strcmp([AFM_images_assembled.Channel_name],"Height (measured)")).AFMmask_heightIO;
        latForce_BK=latForce;
        latForce_BK(logical(mask))=nan;
        verForce_BK=verForce;
        verForce_BK(logical(mask))=nan;
        idxSection=metaData.y_scan_pixels;
        % flip because left area is last section
        idxSection=flip(idxSection,2);
        resFriction_all = A0_feature_2_FrictionGUI(verForce_BK,latForce_BK,mask,idxSection,idxMon,SaveFigSingleSectionsFolder);
        AFM_images_assembled(strcmp([AFM_images_assembled.Channel_name],"Lateral Force") & strcmp([AFM_images_assembled.Trace_type],"Average")).AFM_images_3_ForceBK_Friction=resFriction_all.force_data;
        AFM_images_assembled(end+1).Channel_name="FRICTION_lateralForce_median_vector";
        AFM_images_assembled(end).FrictionDatapoints=resFriction_all.force_median_vector;
        AFM_images_assembled(end+1).Channel_name="FRICTION_verticalForce_median_vector";
        AFM_images_assembled(end).FrictionDatapoints=resFriction_all.vertForce_median_vector;
        metaData.frictionCoeff_Used=resFriction_all.resFit.fc;
        save(fullfile(SaveFigFolder,"resultData_2_FC_postAssembly"),"AFM_images_assembled","metaData","resFriction_all")
    else
        numSections=length(allData);    
        resFriction_all=cell(1,numSections);
        for ithSection=1:numSections
            fprintf("\nFRICTION CALC: Processing section %d\n",ithSection)
            SaveFigSingleSectionsFolder=fullfile(SaveFigFolder,"singleProcessing",sprintf("section%d",ithSection));
            if ~exist(fullfile(SaveFigSingleSectionsFolder,"resultsDataFrictionCoefficient.mat"),'file')     
                mkdir(SaveFigSingleSectionsFolder)           
                %%%%% PREPARE THE DATA BEFORE FRICTION CALC %%%%%
                tmp=allData(ithSection).AFMImage_PostProcess;
                verForce=tmp(strcmp([tmp.Channel_name],"Vertical Force") & strcmp([tmp.Trace_type],"Avg")).AFM_images_3_PostLatProcessed_0_entire;
                latForce=tmp(strcmp([tmp.Channel_name],"Lateral Force") & strcmp([tmp.Trace_type],"Average")).AFM_images_3_PostLatProcessed_0_entire;
                mask=allData(ithSection).AFMmask_heightIO;
                latForce_BK=latForce;
                latForce_BK(logical(mask))=nan;
                verForce_BK=verForce;
                verForce_BK(logical(mask))=nan;
                idxSection=allData(ithSection).metadata.y_scan_pixels;
                %%%%%%%%% FRICTION CALCULATION %%%%%%%%%
                resFriction = A0_feature_2_FrictionGUI(verForce_BK,latForce_BK,mask,idxSection,idxMon,SaveFigSingleSectionsFolder);
                close all
                save(fullfile(SaveFigSingleSectionsFolder,"resultsDataFrictionCoefficient"),"resFriction")
                height=tmp(strcmp([tmp.Channel_name],"Height (measured)")).AFM_images_2_PostHeightProcessed;
                correctHeight(height,mask,resFriction,idxMon,SaveFigSingleSectionsFolder)    
            else
                load(fullfile(SaveFigSingleSectionsFolder,"resultsDataFrictionCoefficient.mat"),"resFriction")
            end
            % save the results of friction calcs
            allData(ithSection).metadata.frictionCoeff_Used=resFriction.resFit.fc;
            allData(ithSection).AFMImage_ForceBK_Friction =resFriction.force_data;
            allData(ithSection).FrictionDatapoints.latForce_median_vector = resFriction.force_median_vector;
            allData(ithSection).FrictionDatapoints.vertForce_median_vector = resFriction.vertForce_median_vector;
            resFriction_all{ithSection}=resFriction;
        end
        % assembly
        [AFM_images_assembled,metaData] = A2_sortAndAssemblySections(allData,otherParameters,1);
        forceBKfriction=AFM_images_assembled(end).AFM_images_3_ForceBK_Friction;
        showData(idxMon,false,forceBKfriction,"Lateral Force BK post Friction Calculation",SaveFigFolder,"resultFriction1_singleSectionProcessing_lateralForceBK")
        % put together Friction datapoints and show their relative FC
        fBKdatapoints=figure("Visible","off");
        axBKdatapoints=axes('Parent',fBKdatapoints);
        hold(axBKdatapoints,"on")
        FCarray=zeros(1,numSections);
        for i=1:numSections
            x=allData(i).FrictionDatapoints.vertForce_median_vector;
            y=allData(i).FrictionDatapoints.latForce_median_vector;
            xmean=mean(x,'omitmissing'); ymean=mean(y,'omitmissing'); ystd=std(y,'omitmissing');
            plot(axBKdatapoints,x,y,'*','Color',globalColor(i),'MarkerSize',40,'DisplayName',sprintf("Datapoints Section #%d\nMean±Std: %.2f ± %.2f (nN)",i,ymean,ystd))
            perr=errorbar(axBKdatapoints,xmean,ymean,ystd,"-s",'Linewidth',2,'capsize',25,'Color','black',...
                'markerFaceColor','black','markerEdgeColor','black','MarkerSize',16);
            perr.Annotation.LegendInformation.IconDisplayStyle = 'off';
            FCarray(i)=allData(i).metadata.frictionCoeff_Used;
        end
        legend(axBKdatapoints,'FontSize',15,'Location','northwest')
        xlabel(axBKdatapoints,'Vertical Force [nN]','FontSize',15); ylabel(axBKdatapoints,'Lateral Force [nN]','FontSize',15);
        textXtitle= sprintf("Datapoints of every section (single section processing)\nFriction Coefficient from each section: %s",strtrim(sprintf('%.2f ',FCarray))); 
        title(axBKdatapoints,textXtitle,'FontSize',20)
        grid(axBKdatapoints,"on")
        objInSecondMonitor(fBKdatapoints,idxMon)
        saveFigures_FigAndTiff(fBKdatapoints,SaveFigFolder,"resultFriction2_singleSectionProcessing_datapoints_FC")
        save(fullfile(SaveFigFolder,"resultData_2_FC_singleSection"),"AFM_images_assembled","metaData","resFriction")
    end
end


function correctHeight(height_preFriction,mask,resFriction,idxMon,saveFigPath)
    % save height figure to better compare with lateral channel
    height_preFriction(logical(mask))=NaN;
    height_afterFriction=height_preFriction;
    height_afterFriction(isnan(resFriction.force_data))=nan;
    nameFig="result_friction_4_heightChannelBeforeAfterFrictionCalc";
    showData(idxMon,false,height_preFriction*1e9,"Height Before Friction calc",saveFigPath,nameFig,"labelBar","Height [nm]",...
            "extraData",height_afterFriction*1e9, ...
            "extraTitles","Height After Friction calc", ...
            "extraLabel","Height [nm]");    
end