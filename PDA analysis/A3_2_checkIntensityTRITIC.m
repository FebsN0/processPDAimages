function [metaData_NIKON,TRITICdata]=A3_2_checkIntensityTRITIC(metaData_NIKON,TRITICdata,SaveFigFolder,idxMon,varargin)
% REORGANIZE TRITIC DATA IN TERMS OF GAIN AND TIME EXPOSURE
% PLOT TRITIC DISTRIBUTION OVER ENTIRE TRITIC IMAGE
    p=inputParser();
    %Add default mandatory parameters.
    argName = 'postHeat';    defaultVal = false;     addParameter(p,argName,defaultVal, @(x) islogical(x));
    parse(p,varargin{:});
    postHeat=p.Results.postHeat;    
    clearvars p argName defaultVal varargin
    if ~postHeat
        metadataTRITIC{1}=metaData_NIKON.TRITIC.pre;   
        metadataTRITIC{2}=metaData_NIKON.TRITIC.post; 
        numTRITICimages=2;    % pre and post
    else
        metadataTRITIC{1}=metaData_NIKON.TRITIC;
        numTRITICimages=1;    % only pre
    end
    expTimeGroup_all=cell(1,numTRITICimages);
    gainGroup_all=cell(1,numTRITICimages);
    for i=1:numTRITICimages
        % find what gain and time exposure have been used and check if everything is okay between the two moments
        n = numel(metadataTRITIC{i});
        gainAll    = zeros(1, n);
        expTimeAll = zeros(1, n);      
        for j = 1:n
            gainAll(j)    = str2double(metadataTRITIC{i}{j}.Gain);   % convert once
            expTimeAll(j) = metadataTRITIC{i}{j}.ExposureTime;
        end
        clear n j
        gainGroup_all{i}=sort(unique(gainAll),'ascend');
        expTimeGroup_all{i}=sort(unique(expTimeAll),'descend');
    end
    if ~(all(cellfun(@(x) isequal(x, gainGroup_all{1}), gainGroup_all)) && all(cellfun(@(x) isequal(x, expTimeGroup_all{1}), expTimeGroup_all)))
        error("PRE and POST metadata are not the same! Something went wrong. Maybe missing some data with specific optical condition")
    else
        % since metadata is confirmed to be the same between pre and post, just take one block
        gainGroup=gainGroup_all{1};
        expTimeGroup=expTimeGroup_all{1};
        metadataTRITIC=metadataTRITIC{1};
    end
    % now that time exposure and gain are same for all TRITIC images, lets start the TRITIC intensity analysis
    % BUT additional check and reorganazing the data for any evenience
    % 
    % in case of mismatch between naming and metadata, reorganize the data according to exposure time and gain to regroup all the data properly
    % even if everything is okay, organize as 
    %       columns: highExpTime -> lowExpTime
    %       vectors: lowGain -> highGain
    % in this way, low expTime TRITIC distribution will be shown frontally    
    if ~isequal([length(expTimeGroup),length(gainGroup)],size(metadataTRITIC))
        expTimeGroup_text=num2str(expTimeGroup);
        gainGroup_text=num2str(gainGroup);
        uiwait(warndlg(sprintf("Aware! Additional settings found in the metadata of TRITIC.\n" + ...
            "I.e. different gain/expTime than expected from the TRITIC filename\n" + ...
            "gain: %s\nExposure Time: %s",gainGroup_text,expTimeGroup_text)))
        error("not possible to continue")
    end
    % init data and metadata
    metadataTRITIC_corr=cell(length(expTimeGroup),length(gainGroup));
    TRITICdata_corr_pre=cell(length(expTimeGroup),length(gainGroup));
    if ~postHeat
        TRITICdata_corr_post=cell(length(expTimeGroup),length(gainGroup));
    end
    for ithGain=1:length(gainGroup)
        for ithExpTime=1:length(expTimeGroup)
            % Find matching index using logical indexing — no inner loop
            mask = (expTimeAll == expTimeGroup(ithExpTime)) & ...
                   (gainAll    == gainGroup(ithGain));            
            idx = find(mask, 1);   % expect exactly one match
            if ~isempty(idx)
                metadataTRITIC_corr{ithExpTime, ithGain} = metadataTRITIC{idx};
                tmp=TRITICdata.pre{idx};
                TRITICdata_corr_pre{ithExpTime, ithGain}=tmp;
                if ~postHeat
                    tmp=TRITICdata.post{idx};
                    TRITICdata_corr_post{ithExpTime, ithGain}=tmp;
                end
            else
                error('No match found for gain=%.1f, expTime=%.4f', ...
                    gainGroup(ithGain), expTimeGroup(ithExpTime));
            end                       
        end
    end
    clear expTime* gain* i idx mask numTRITICimages tmp TRITICdata metadataTRITIC
    % store the organized data
    metadataTRITIC=metadataTRITIC_corr;
    metaData_NIKON.TRITIC=metadataTRITIC;
    TRITICdata.pre=TRITICdata_corr_pre;
    if ~postHeat
        TRITICdata.post=TRITICdata_corr_post;
    end           
    clear TRITICdata_corr_post TRITICdata_corr_pre metadataTRITIC         
      
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% SHOW FLUORESCENCE DISTRIBUTION OF FULL TRITIC IMAGE %%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % plot the Fluorescence distribution of entire TRITIC image.
    fs=fieldnames(TRITICdata);
    maxTRITIC=cell(1,2); minTRITIC=cell(1,2);
    % prepare the bin sizes so the distributions are more comparable
    for i=1:2        
        maxTRITIC{i}=max(cellfun(@(x) max(x(:)), TRITICdata.(fs{i})),[],'all');
        minTRITIC{i}=min(cellfun(@(x) min(x(:)), TRITICdata.(fs{i})),[],'all');
    end   
    for ithGain=1:size(TRITICdata.pre,2)            
        gain=metaData_NIKON.TRITIC{1,ithGain}.Gain;
        figDistTRITIC=figure("Visible","off");
        tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact',"Parent",figDistTRITIC);
        axDist{1}  = nexttile(tl);
        axDist{2} = nexttile(tl);
        mainText={"BEFORE AFM SCANNING","AFTER AFM SCANNING"};        
        sgtitle(figDistTRITIC,sprintf("Distribution Fluorescence (Full TRITIC image) - Gain: %s",gain),'FontSize',18,'Interpreter','none');
        
        for i=1:2
            hold(axDist{i},"on")
            xlabel(axDist{i},'Absolute fluorescence increase (A.U.)','FontSize',15), ylabel(axDist{i},"PDF",'FontSize',15)
            title(axDist{i},mainText{i},"FontSize",16), legend(axDist{i},'FontSize',12)
        end               
        edges=linspace(min([minTRITIC{:}]),max([maxTRITIC{:}]),100);
        for ithTimeExp=1:size(TRITICdata.pre,1)
            % get the information about time exposure
            ithMetadataTRITIC=metaData_NIKON.TRITIC{ithTimeExp,ithGain};
            expTime=ithMetadataTRITIC.ExposureTime;
            for i=1:2
                ithTRITICdata=TRITICdata.(fs{i}){ithTimeExp,ithGain}; 
                vectDelta=ithTRITICdata(:);
                % find the percentage of saturated values
                ratioSat=nnz(vectDelta>edges(end-1))/length(vectDelta)*100;
                % prepare the name for legend
                nameScanText=sprintf('%dms - ratioSaturation: %.2f%%',round(double(expTime)),ratioSat);
                % show distribution of all TRITIC image
                histogram(axDist{i},vectDelta,'BinEdges',edges,"DisplayName",nameScanText,"Normalization","pdf",'FaceAlpha',0.3,"FaceColor",globalColor(ithTimeExp))                
            end
        end
        % better show for the distribution
        figDistTRITIC.Visible="on";
        objInSecondMonitor(figDistTRITIC,idxMon); 
        for i=1:2
            xlim(axDist{i},"padded"); ylim(axDist{i},"tight"), grid(axDist{i},"on"), grid(axDist{i},"minor")
            legend(axDist{i},"Location","best")
        end                          
        nameFig=sprintf('resultA3_3_%d_DistributionFluorescenceDiffTimeExp_gain%s',ithGain,gain);
        pause(2)
        saveFigures_FigAndTiff(figDistTRITIC,SaveFigFolder,nameFig)
    end                                   
end