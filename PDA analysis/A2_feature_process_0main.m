function [AFM_HeightFittedMasked,AFM_height_IO]=A2_feature_process_0main(dataPreProcess,SaveFigFolder,idxMon,accuracyHeight,varargin)
% run A2_feature_process_1 and A2_feature_process_2
    p=inputParser();
    argName = 'setpointsList';  defaultVal = [];        addParameter(p,argName,defaultVal);
    argName = 'SeeMe';          defaultVal = false;     addParameter(p,argName,defaultVal, @(x) islogical(x));
    argName = 'imageType';      defaultVal = 'Entire';  addParameter(p,argName,defaultVal, @(x) ismember(x,{'Entire','SingleSection','Assembled'}));
    argName = 'Normalization';  defaultVal = false;     addParameter(p,argName,defaultVal, @(x) islogical(x));
    argName = 'metadata';       defaultVal = [];        addParameter(p,argName,defaultVal);
    parse(p,varargin{:});

    if p.Results.SeeMe,  SeeMe=1; else, SeeMe=0; end                    
    typeProcess=p.Results.imageType;
    if p.Results.Normalization; norm=1; else, norm=0; end
    setpointN=p.Results.setpointsList;
    metaData=p.Results.metadata;
    clearvars argName defaultVal p

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% PROCESS HEIGHT CHANNEL %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    iterationMain=1;
    while true
        % show the data prior the adjustments
        A1_feature_CleanOrPrepFiguresRawData(dataPreProcess,'idxMon',idxMon,'folderSaveFig',SaveFigFolder,'metadata',metaData,'imageType',typeProcess,'SeeMe',SeeMe,"setpointsList",setpointN,'Normalization',norm);
        % first process: OBTAIN MASK 0/1 of the Height channel
        [AFM_HeightFitted,AFM_height_IO]=A2_feature_process_1_fitHeightChannel(dataPreProcess,iterationMain,idxMon,SaveFigFolder,"fitOrder",accuracyHeight,"SeeMe",SeeMe);
        % Using the AFM_height_IO, fit the background again, yielding a more accurate height image by using the
        % 0\1 height image
        [AFM_HeightFittedMasked,AFM_height_IO]=A2_feature_process_2_fitHeightChannelWithMask(AFM_HeightFitted,AFM_height_IO,iterationMain,idxMon,SaveFigFolder,"SeeMe",SeeMe);
        % ask if re-run the process to obtain better AFM height image 0/1
        if ~getValidAnswer('Run again A3 and A4 to create better optimized mask and height AFM image?','',{'y','n'},2)
            break
        else
            iterationMain=iterationMain+1;
            dataPreProcess=AFM_HeightFittedMasked;
        end
    end
end