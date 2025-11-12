function [dataAFM_assembled,AFM_height_IO_assembled,metadata,setpointN]=A2_processAFMdata(allData,otherParameters,mainPath,SaveFigFolder,idxMon,varargin)
    p=inputParser();
    argName = 'accuracyHeight';    defaultVal = 'Low';     addOptional(p,argName,defaultVal, @(x) ismember(x,{'Low','Medium','High'}));
    argName = 'accuracyLateral';   defaultVal = 'Low';     addOptional(p,argName,defaultVal, @(x) ismember(x,{'Low','Medium','High'}));
    argName = 'frictionData';      defaultVal = 'No';      addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    parse(p,varargin{:});    
    
    accuracyHeight=p.Results.accuracyHeight;
    accuracyLateral=p.Results.accuracyLateral;
    if strcmp(p.Results.frictionData,"No"), frictionCalc=false; else, frictionCalc=true; end
    clearvars argName defaultVal p varargin
    
    % count how many sections has been generated
    numFiles=length(allData);
    % QUESTION process single sections then assembly or assembly then
    % process? ASK only if the function is running with HOVER MODE ON. In
    % case of HOVER MODE OFF (friction), skip it because it will 
    typeProcessChoice=askTypeProcess(mainPath);
    flag_processSingleSection=typeProcessChoice.flag;
    if flag_processSingleSection
        SaveFigSingleSectionsFolder=typeProcessChoice.folderSingleSectionData;
        % prepare the diretory where to store the figures
        [pathDataSingleSections,~,~]=fileparts(SaveFigSingleSectionsFolder);       
    end
    clear typeProcessChoice

    % first process, then assembly
    if flag_processSingleSection           
        for i=1:numFiles
            % check if results were already made.
            [~,nameSection,~]=fileparts(allData(i).filenameSection);
            % path of the subfolder where to store figures for each section
            SaveFigIthSectionFolder=fullfile(SaveFigSingleSectionsFolder,sprintf("section_%d",i));
            fileName1=fullfile(pathDataSingleSections,sprintf("%s_heightChannelProcessed.mat",nameSection));
            fileName2=fullfile(pathDataSingleSections,sprintf("%s_lateralChannelProcessed.mat",nameSection));
            flagEnd=false;
            if exist(fileName2,"file") 
                question=sprintf("PostLateralChannel file .mat for the section %d already exists. Take it?",i);
                if getValidAnswer(question,"",{'y','n'})
                    load(fileName2,"AFM_LatDeflecFitted_Force")
                    flagEnd=true;
                end
            elseif exist(fileName1,"file")
                question=sprintf("PostHeightChannel file .mat for the section %d already exists. Take it?",i);
                if getValidAnswer(question,"",{'y','n'})
                    load(fileName1,"AFM_HeightFittedMasked","AFM_height_IO")
                end
            else
                % in case the HeightAFMprocess and LateralAFMprocess have never been done, then start it.
                % First, given the ith-section, create subfolder where store figures for each section and results                
                mkdir(SaveFigIthSectionFolder)
                % extract the data
                dataPreProcess=allData(i).AFMImage_Raw;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%% PROCESS HEIGHT CHANNEL %%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                [AFM_HeightFittedMasked,AFM_height_IO]=processHeightAFMdata(dataPreProcess,idxMon,SaveFigIthSectionFolder,accuracyHeight,'Yes',TypeSectionProcess);
                % save the results for the specific section, to avoid to perform manual binarization
                save(fullfile(pathDataSingleSections,sprintf("%s_heightChannelProcessed.mat",nameSection)),"AFM_HeightFittedMasked","AFM_height_IO")                
            end
            clear question fileName*
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%% PROCESS LATERAL DEFLECTION CHANNEL (in case of HOVER MODE ON DATA) %%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~flagEnd && ~frictionCalc
                metaData_AFM=allData(i).metadata; 
                AFM_LatDeflecFitted_Force=A5_LD_Baseline_Adaptor_masked(AFM_HeightFittedMasked,AFM_height_IO,metaData_AFM.Alpha,idxMon,SaveFigIthSectionFolder,mainPath,'FitOrder',accuracyLateral,'Silent','No');
                save(fullfile(pathDataSingleSections,sprintf("%s_lateralChannelProcessed.mat",nameSection)),"AFM_LatDeflecFitted_Force") 
            end   
            allData(i).AFMImage_PostProcess=AFM_LatDeflecFitted_Force;
            allData(i).AFMmask_heightIO=AFM_height_IO;     
            close all
        end
    end

    % ASSEMBLY!

    [dataAFM_assembled,AFM_height_IO_assembled,metadata,setpointN] = sortAndAssemblySections(allData,otherParameters,SaveFigFolder,flag_processSingleSection);
    


    % in case of no single section processing, now process the assembled image
    if ~flag_processSingleSection
        AFM_LatDeflecFitted=A5_LD_Baseline_Adaptor_masked(dataAFM_assembled,AFM_height_IO_assembled,metaData_AFM.Alpha,idxMon,folderResultsImg,mainPath,'FitOrder',accuracy,'Silent','No');
    end
end
       
    
%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% FUNCTION %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%

function typeProcessChoice=askTypeProcess(varargin)
    flag_processSingleSection=false;
    % For the normal AFM postprocessing, ask if PROCESS PRE ASSEMBLY.
    % If YES, create another directory containing a directory for each section where to store the results of single sections processing
    question= sprintf('Process single sections before assembling?');
    if getValidAnswer(question,'', {'Yes','No'})
        mainPath=varargin{1};
        flag_processSingleSection=true;
        % prepare the directories where store the data of single section
        % and its figures. SaveFigFolder is only for assembled data. It
        % will be used after assembling
        pathDataSingleSections=fullfile(mainPath,"HoverMode_ON","dataSingleSections");
        SaveFigSingleSectionsFolder=fullfile(pathDataSingleSections,"Results singleSectionsProcessing");
        if ~exist(pathDataSingleSections,"dir")            
            mkdir(pathDataSingleSections)            
        end
        if ~exist(SaveFigSingleSectionsFolder,"dir")        
            mkdir(SaveFigSingleSectionsFolder)
        end     
        typeProcessChoice.folderSingleSectionData=SaveFigSingleSectionsFolder;
    end
    typeProcessChoice.flag=flag_processSingleSection;    
end


function [AFM_HeightFittedMasked,AFM_height_IO]=processHeightAFMdata(dataPreProcess,typeProcess,setpointN,SaveFigFolder,idxMon,accuracyHeight,SeeMe,norm,sizeSections)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% PROCESS HEIGHT CHANNEL %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    iterationMain=1;
    while true
        % show the data prior the adjustments
        A1_feature_CleanOrPrepFiguresRawData(dataPreProcess,setpointN,idxMon,SaveFigFolder,'metadata',metaDataAssembled,'imageType',typeProcess,'Silent',SeeMe,'Normalization',true,'sectionSize',sizeSections);
        % first process: OBTAIN MASK 0/1 of the Height channel
        [AFM_HeightFitted,AFM_height_IO]=A3_El_AFM(dataPreProcess,iterationMain,idxMon,SaveFigFolder,"fitOrder",accuracyHeight,"SeeMe",SeeMe);
        % Using the AFM_height_IO, fit the background again, yielding a more accurate height image by using the
        % 0\1 height image
        [AFM_HeightFittedMasked,AFM_height_IO]=A4_El_AFM_masked(AFM_HeightFitted,AFM_height_IO,iterationMain,idxMon,SaveFigFolder,"SeeMe",SeeMe);
        % ask if re-run the process to obtain better AFM height image 0/1
        if ~getValidAnswer('Run again A3 and A4 to create better optimized mask and height AFM image?','',{'y','n'},2)
            break
        else
            iterationMain=iterationMain+1;
            dataPreProcess=AFM_HeightFittedMasked;
        end
    end
end


function varargout = sortAndAssemblySections(allData,otherParameters,flag_processSingleSection,SaveFigFolder,varargin)
% First part is sorting in function of the y-position of the sections
% Second part is assembling the sections
    p=inputParser();    
    argName = 'Silent';                     defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'Normalization';              defaultVal = false;     addParameter(p,argName,defaultVal, @(x) islogical(x)); 
    % validate and parse the inputs
    parse(p,varargin{:});
    numFiles=length(allData);
    
    % check the origin offset information and properly sort data and
    % metadata. In theory, the sections are already ordered, but further
    % check always better! Note: each line of struct is
    % data-metadata-filename of specific section!
    y_OriginAllScans=[otherParameters.y_OriginAllScans];   
    [~,idx]=sort(y_OriginAllScans);
    allDataOrdered=allData(idx);

    % before assembly the data, adjust the metadata of the final assembly.
    % Copy the metadata of the first section and modify some fields
    metaDataAssembled= allDataOrdered(1).metadata;
    % adjust the metaData, in particular:
    %       y_Origin
    %       y_scan_length
    %       y_scan_pixels
    %       Baseline_V
    %       Baseline_N
    %       SetP_V
    %       SetP_m
    %       SetP_N
    % the others don't change. 
    % since it is ordered, the first element already contains the true y_Origin        
    % in case of y lenght, just sum single y lenght of each section to have entire scan size
    y_scan_lengthAllScans = arrayfun(@(s) s.metadata.y_scan_length_m, allDataOrdered);      
    % allDataOrdered is a struct array
    % Each element has a field .metadata
    % .metadata itself is another struct (not an array).
    % ==>
    % y_scan_lengthAllScans=[allDataOrdered.metadata.y_scan_length_m]
    % ===== FAILS because [struct.struct.field] ===> which it can't flatten automatically.
    metaDataAssembled.y_scan_length_m= sum(y_scan_lengthAllScans);
    % in case of y pixel, keep the pixel value of each section. This information is valuable especially for
    % friction experiment method 1 which it needs to separate the section depending on setpoint
    metaDataAssembled.y_scan_pixels = arrayfun(@(s) s.metadata.y_scan_pixels, allDataOrdered);
    % in case of setpoints and baseline, create an array if more sections. For newton values, round a little a bit the values
    metaDataAssembled.SetP_V= arrayfun(@(s) s.metadata.SetP_V, allDataOrdered);
    metaDataAssembled.SetP_N=round(arrayfun(@(s) s.metadata.SetP_N, allDataOrdered),9);
    metaDataAssembled.Baseline_V=arrayfun(@(s) s.metadata.Baseline_V, allDataOrdered);
    metaDataAssembled.Baseline_N=round(arrayfun(@(s) s.metadata.Baseline_N, allDataOrdered),12);
    clear y_scan_lengthAllScans y_OriginAllScans idx 

    % Init vars where store the assembled sections by copying common data fields.
    % Copy just the first row (The data will be overwritten later during assembly):
    %   Channel_name
    %   Trace_type
    %   AFM data
    dataAssembled_1Raw=allDataOrdered(1).AFMImage_Raw;
    if flag_processSingleSection
        dataAssembled_2Processed=allDataOrdered(1).AFMImage_PostProcess;
        maskAssembled=allDataOrdered(1).AFMmask_heightIO;
    end

    



    
    % ASSEMBLY BY CONCATENATION. Take the i-th channel and assembly
    for i=1:size(dataAssembled_1_ORIGINAL,2)
        % init the var where store the concatenated sections of pre and
        % post processed sections        
        concatenatedData_Raw_afm_image=[];
        concatenatedData_AFM_image_START=[];
        if flag_processSingleSection
            concatenatedData_AFM_image_END=[];
        end

        for j=numFiles:-1:1            
            dataRAW=flip(allScansImage_1_ORIGINAL_Ordered{j}(i).Raw_afm_image);
            concatenatedData_Raw_afm_image      = cat(1,concatenatedData_Raw_afm_image,dataRAW);
            dataIMAGE=flip(allScansImage_1_ORIGINAL_Ordered{j}(i).AFM_image);
            concatenatedData_AFM_image_START    = cat(1,concatenatedData_AFM_image_START,dataIMAGE);
            if numFiles>1
                sizeSections(j)=size(dataRAW,1);
            else
                sizeSections=[];
            end
            if flag_processSignleSections
                dataPOST=flip(rot90(allScans_AFMImage_2_PROCESSED_Ordered{j}(i).AFM_image));
                concatenatedData_AFM_image_END  = cat(1,concatenatedData_AFM_image_END,dataPOST);
                % no need to process iteratively in case of AFM Height IO image
                if i==1
                    dataIO=flip(rot90(allScans_AFM_HeightIO_ordered{j}));
                    concatenated_AFM_Height_IO  = cat(1,concatenated_AFM_Height_IO,dataIO);
                end
            end
        end

        dataAssembled_1_ORIGINAL(i).Raw_afm_image= flip(concatenatedData_Raw_afm_image);
        dataAssembled_1_ORIGINAL(i).AFM_image=flip(concatenatedData_AFM_image_START);
        if flag_processSignleSections
            dataAssembled_2_PROCESSED(i).AFM_image   = flip(rot90(concatenatedData_AFM_image_END,-1));
        end
    end
    
    % show and save figures post assembly
    A1_feature_CleanOrPrepFiguresRawData(dataAssembled_1_ORIGINAL,setpointN,idxMon,SaveFigFolder,'metadata',metaDataAssembled,'imageType',TypeSectionProcess,'Silent',silent,'Normalization',norm,'sectionSize',sizeSections);
    
    varargout{1}=dataAssembled_1_ORIGINAL;

    % process the data (A3 and A4 to create optimized and 0\1 height images
    [AFM_HeightFittedMasked,AFM_height_IO]=processData_A3_A4(dataAssembled_1_ORIGINAL,idxMon,SaveFigFolder,accuracy,silent);
    % save the outputs
    varargout{1}=AFM_HeightFittedMasked;
    varargout{2}=AFM_height_IO;
    varargout{3}=metaDataAssembled;
    varargout{4}=SaveFigFolder;
    varargout{5}=setpointN;
end




