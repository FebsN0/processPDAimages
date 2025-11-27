% The feature removes portion of the AFM data which are manually considered unstable (for example, when the
% tip is not scanning anymore or it is not properly scanning). Such regions can negatively affects both
% regular scans used for fluorescence-force experiments and scans from which extrapolate the definitive
% background friction coefficient.
% The values in the removed regions are substituted with NaN. Therefore, for any type of fitting, lineByLine or Plane, they will be ignored.
% Exception is in case of binary image: to prevent nan incompatibility in next steps, the values are changed into 0 or 1 depending on the
% user choice.
%  
% INPUT:
%   -dataToShow1 :  first data image (matrix or struct) to show
%   -textTitle1 :   title for dataToShow1 figure
%   -idxMon  :      idx for additional monitor
%   -varargin :     additional optional inputs
%                       - channelToShow :                   choose a specific channel (lateral,vertical,height) in case one of the given data is a struct data  
%                       - additionalImagesToShow :          additional image to show. It can be a matrix (single additional image only) or
%                                                                   cell array containing one or more additional images
%                       - additionalImagesTitleToShow :     similar to textTitle1, but for additionalImagesTitleToShow%                       
%                       - originalDataIndex                 which image to use to restore values. Recommended the one which has not been previously masked and not the binary image                           
%                       - whichNaN                          which type of data convert into NaN? convert FR or BK values into NaN? By default, FR values will be converted into FR
%                       
% OUTPUT:
%   varargout :     cell array containing the original data with removed portions
%                       (varargout{i}=allDataToShow{i} ==> allDataToShow = dataToShow1 + additionalImagesToShow)

% several approaches to remove data has been explore and each showed a problem
% sol 1 (USED): the removed values became NaN
% problem: during the next fitting, preparecurve function remove all NaN values so the
% corresponding line will be empty ==> FAILURE FITTING (the error is like not possible to perform
% fitting because there are no enough values..
% sol to this problem: check the line before the fitting and entirely skip leaving NaN
% new problem: when plotted, there is no right proportion so it seems that the removed region is
% more close to BK while the true BK is higher rather than being close to zero
% data(:,xstart:xend)=nan; 

% sol 2: the removed values became the minimum value in the matrix outside the removed regions
% problem: the values in correspondence of crystal are considered background in the background/foreground
% separation to create the mask, so in the optimization process (A4_El_AFM_masked), the values in PDA 
% regions will be considered because the mask "says" it is background...
% sol to this problem: better managment in friction codes. Not an issue in case of regular scans
% data(:,xstart:xend)=min(min(data(:,[1:xstart-1 xend+1:end])))
%
% sol 3: remove entirely the selected regions and merge the others. Save the idx so they will be
% used to remove also vertical and lateral deflection data
% problem: regions will be disconnected.. but at least totally cleared data
% true problem: in case of normal scans, the alignment of IOimage with fluorescence images will
% fail...            
% data=[data(:,1:xstart-1) data(:,xend+1:end)];

                          
function varargout = featureRemovePortions(dataToShow1,textTitle1,idxMon,varargin)
    %init instance of inputParser
    p=inputParser();
    % Required arguments
    addRequired(p, 'dataShow1', @(x) (isstruct(x) || ismatrix(x)));
    addRequired(p, 'idxMon', @(x) isnumeric(x));
    % Optional parameters
    addParameter(p, 'channelToShow','',@(x) (isempty(x) || (ismember(x,{'Height (measured)','Lateral Deflection','Vertical Deflection'}))))
    addParameter(p, 'additionalImagesToShow', [],       @(x) (ismatrix(x) || isempty(x)|| iscell(x)));
    addParameter(p, 'additionalImagesTitleToShow', [],  @(x) (isstring(x) || ischar(x) || isempty(x) || iscell(x)));
    addParameter(p, 'originalDataIndex', 1, @(x) isnumeric(x));
    addParameter(p, 'normalize', true, @(x) islogical(x));
    % validate and parse the inputs
    parse(p, dataToShow1, idxMon, varargin{:});  

    % by default take the height channel in case of struct and if not specified by user      
    if ~isempty(p.Results.channelToShow), channel=p.Results.channelToShow; else, channel = 'Height (measured)'; end
    [flagStructDataToShow1,dataToShow1]=isstructImage2Show(dataToShow1,channel);
    % check if the image is binary, so the figure can be adapted
    isDataToShow1Bin=isbinaryImage(dataToShow1);
    normDataToShow1=false;
    if ~isDataToShow1Bin
        normDataToShow1=true;
    end
    % init
    flagStructDataToShowK=[];
    % redo the same operations to additional figures whenever they are present
    flagAdditionalImageToShow=false;    
    if ~isempty(p.Results.additionalImagesToShow)
        flagAdditionalImageToShow=true;
        % in case of cell, very likely that there are multiple data to show
        if iscell(p.Results.additionalImagesToShow)            
            nExtra = numel(p.Results.additionalImagesToShow);
            nExtraTitle = numel(p.Results.additionalImagesTitleToShow);
            if nExtraTitle~=nExtra
                error("Number of titles for additional images is not the same with the number of additional images! Check out")
            end
            % init
            dataToShowK=cell(1,nExtra);
            titleExtraK=cell(1,nExtra);
            binaryFormatImage=zeros(1,nExtra);
            normDataToShowK=zeros(1,nExtra);
            flagStructDataToShowK=zeros(1,nExtra);
            for k=1:nExtra
                tmp=p.Results.additionalImagesToShow{k};
                % check if struct
                [flagStructTmp,tmp]=isstructImage2Show(tmp,channel);
                dataToShowK{k}=tmp;
                flagStructDataToShowK(k)=flagStructTmp;
                % check if binary, if not, then normalize
                binaryFormatImage(k)=isbinaryImage(tmp);
                if ~binaryFormatImage(k), normDataToShowK(k)=1; end
                % prep the titles
                titleExtraK{k}=string(p.Results.additionalImagesTitleToShow{k});
            end
        elseif ismatrix(p.Results.additionalImagesToShow)
            % in case it is just one image
            nExtra=1;
            % init
            dataToShowK=cell(1,1);
            titleExtraK=cell(1,1);                        
            tmp=p.Results.additionalImagesToShow;
            [flagStructTmp,tmp]=isstructImage2Show(tmp,channel);
            dataToShowK{1}=tmp;
            flagStructDataToShowK=flagStructTmp;
            titleExtraK{1}=string(p.Results.additionalImagesTitleToShow);
            binaryFormatImage=isbinaryImage(tmp);
            if ~binaryFormatImage, normDataToShowK=1; else, normDataToShowK=0; end
        end
        nTotData=nExtra+1;
        % merge in a cell array all the given data to easily identify and other flags
        allDataToShow= [{dataToShow1}; dataToShowK(:)];
        allData_binaryFormat=[isDataToShow1Bin binaryFormatImage];
        allData_normalizedFormat=[normDataToShow1 normDataToShowK];
        allData_titles=[{textTitle1}; titleExtraK(:)];
    else
        nTotData=1;
        allDataToShow={dataToShow1};
        allData_binaryFormat=isDataToShow1Bin;
        allData_normalizedFormat=normDataToShow1;
        allData_titles={textTitle1};
    end
    % check if one of the given data is struct
    flagStructDataArray=[flagStructDataToShow1,flagStructDataToShowK];
    if any(flagStructDataArray)
        flagStructData=true;
        idxStructInput=find(flagStructDataArray);
        nStruct=length(idxStructInput);
        if nStruct>1
            question="More than one struct data has been provided as input.\nWhich one will be the original of which will be used to replace original values";
            options=cell(1,nStruct);
            for i=1:nStruct
                options{i} = sprintf('Input provided # %d',idxStructInput(i));
            end
            choice=getValidAnswer(question,'',options);
            idxStructOriginal=idxStructInput(choice);
        else
            idxStructOriginal=idxStructInput;
        end
        structOriginal=allDataToShow{idxStructOriginal};
        % since it is referred as original, use it also for changing channel.
        idxStructData=idxStructOriginal;  
    else
        flagStructData=false;
    end

    originalDataIndex=p.Results.originalDataIndex;   
    if originalDataIndex>nTotData
        error("The index to select the original data in the dataset is higher than the number of all dataset!")
    elseif nTotData>1
        % if the index is the same for the binary image index, then switch image
        if find(allData_binaryFormat,1) == originalDataIndex
            originalDataIndex=find(~allData_binaryFormat,1);
        end 
    end    
    % in case of restoring values when the user choose foreground after area selection
    data_originalXrestoring=allDataToShow{originalDataIndex};
    if ~p.Results.normalize
        allData_normalizedFormat=false(1,length(allData_normalizedFormat));
    end
    clear tmp varargin p dataTo* flagStructDataToShow* flagStructTmp isDataToShow1Bin binaryFormatImage k nExtra normDataToShow* textTitle1 titleExtraK
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%% all the data is now ready to show and start the removal %%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
    fcomparisonRemoval=[];
    
    % prep removal settings for the question
    allMethodsRemoval={'All fast scan lines';'Rectangle area';'Polygon area'};
    allOnWhichFigure=cell(1,nTotData);
    for i=1:nTotData
        allOnWhichFigure{i}=sprintf('Figure %d',i);
    end
    
    while true
        if flagAdditionalImageToShow
            fcomparisonRemoval=showData(idxMon,true,allDataToShow{1},allData_titles{1},'','','saveFig',false,'normalized',allData_normalizedFormat(1),'binary',allData_binaryFormat(1),...
                'extraData',allDataToShow(2:end),'extraTitles',allData_titles(2:end), ...
                'extraBinary',allData_binaryFormat(2:end),'extraNorm',allData_normalizedFormat(2:end), ...
                'prevFig',fcomparisonRemoval);
        else
            fcomparisonRemoval=showData(idxMon,true,allDataToShow{1},allData_titles{1},'','','saveFig',false,'normalized',allData_normalizedFormat,'binary',allData_binaryFormat,'prevFig',fcomparisonRemoval);
        end
        % Terminate or continue. In case of struct in the data, ask if change channel for different visual
 
        if flagStructData                                           
            options = {'Yes','No',sprintf('Change into height channel for the %d-th figure',idxStructData),sprintf('Change into lateral deflection channel for the %d-th figure',idxStructData)};
        else
            options = {'Yes','No'};
        end
        question = 'Remove/restore lines or portion? If not, interrupt the current step.';
        answer=getValidAnswer(question,'',options,2);
        % STOP THE REMOVAL EXE
        if answer==2 || answer == false
            break
        elseif answer~=1 || answer ~= true     
            % CHANGE CHANNEL
            if answer==3 
                channel='Height (measured)';
            else
                channel='Lateral Deflection';
            end
            dataStruct = allDataToShow{idxStructData};
            matchIdx = strcmp([dataStruct.Channel_name],channel) & strcmp([dataStruct.Trace_type],'Trace');
            dataStructUpdated=dataStruct(matchIdx).AFM_image;
            allDataToShow{idxStructData}=dataStructUpdated;
        % START THE REMOVAL EXE
        else          
            question='Choose the removal type. Then double click on the selected marked object to terminate the drawing.';
            selectedOptions = selectOptionsDialog(question,false,allMethodsRemoval,allOnWhichFigure,'Titles',{'Select which removal method.','Select on which figure draw.'});
            methodRemoval=selectedOptions{1};
            onWhichFigure= selectedOptions{2}; 
            % get all the axes (subfigures) from the main figure
            axAll = findall(fcomparisonRemoval, 'type', 'axes');
            % Sort left-to-right
            [~, idx] = sort(arrayfun(@(ax) ax.Position(1), axAll));
            axAll = axAll(idx);
            axSelected=axAll(onWhichFigure);
            axes(axSelected) %#ok<LAXES>
            hold(axSelected, 'on');
            if methodRemoval == 1
                modeRemoval='line';
                roi=drawline(axSelected,'Color','red');
                pos = round(customWait(roi));
                coordinatesSelectedArea=[pos(1,1) pos(2,1)];
            elseif methodRemoval == 2
                modeRemoval='rect';
                roi=drawrectangle(axSelected,'Color','red');
                pos = round(customWait(roi));
                % take the coordinates along slow scan direction.
                xstart = pos(1);     xend = xstart+pos(3);
                % take the coordinates along fast scan direction.
                ystart = pos(2);     yend = ystart+pos(4);            
                coordinatesSelectedArea=[xstart ystart xstart yend xend yend xend ystart];
            else
                modeRemoval='polygon';
                roi=drawpolygon(axSelected,'Color','red');
                pos = customWait(roi);
                coordinatesSelectedArea=round(reshape(pos',[1 size(pos,1)*2]));
            end            
            % in case of interruption
            if isempty(roi.Position)
                break
            end
            hold(axSelected, 'off');          
            % manage the coordinates to create the mask depending on the choosen removal method
            [rows, cols] = size(allDataToShow{onWhichFigure});
            if ~strcmp(modeRemoval,'line')
                xCoords = coordinatesSelectedArea(1:2:end);
                yCoords = coordinatesSelectedArea(2:2:end);            
            else
                % in case of line, create a big rectangule occupying all fast scan lines (y coords, rows)
                coordinatesSelectedArea=sort(coordinatesSelectedArea);
                yCoords=[0 0 rows rows];
                xCoords=[coordinatesSelectedArea(1) coordinatesSelectedArea(2) coordinatesSelectedArea(2) coordinatesSelectedArea(1)];
            end
            % create the mask polygon
            mask = poly2mask(xCoords, yCoords, rows, cols); 
            % prepare the user choices on how to treat the data
            question='Choose what to do';                       
            options1={'Background (change into 0 for mask)','Foreground (change into 1 for mask)'};
            options2={'Restore original values','Trasform into NaN'};
            titles={'What is the selected area?','How to trasform the relative values?'};
            selectedOptions = selectOptionsDialog(question,false,options1,options2,'Titles',titles);
            if selectedOptions{2}==2, flagIntoNan=true; else, flagIntoNan=false; end
            if selectedOptions{1}==1, isBK=true; else, isBK=false; end
            for i=1:nTotData
                tmp=allDataToShow{i};    
                % in case of binary image, to avoid to process nan values later and use it as definitive mask, covert the values into 0 or 1
                if allData_binaryFormat(i)                    
                     % Binary: 0 or 1
                    tmp(mask) = (isBK ~= 1);             
                else
                % in case of normal images, convert into NaN or restore values depending on the user first choice (by default, FR values are converted into NaN in the selected areas) 
                    if ~flagStructDataArray(i)
                        % Apply the replacement
                        if flagIntoNan
                            tmp(mask) = NaN;
                        else                            
                            tmp(mask) = data_originalXrestoring(mask);
                        end                                                              
                    else
                    % if the given data was a struct, update every channel. Note; tmp is a struct
                        for j=1:length(tmp)
                            tmpS=tmp(j).AFM_image;
                            tmpOriginal=structOriginal(j).AFM_image;
                            if flagIntoNan
                                tmpS(mask)=NaN;
                            else                                
                                tmpS(mask) = tmpOriginal(mask);
                            end
                            dataStruct(j).AFM_image=tmpS;
                        end                    
                    end                    
                end 
                allDataToShow{i}= tmp;
            end
        end        
    end
    close(fcomparisonRemoval)
    varargout=cell(1,nTotData);
    for i=1:nTotData
        varargout{i}=allDataToShow{i};
    end
end

%%%%%%%%%%%%%%%%%
%%% FUNCTIONS %%%
%%%%%%%%%%%%%%%%%

% Function to wait until completion by clicking twice. Return final pos array
function pos = customWait(hROI)
    % Listen for mouse clicks on the ROI
    l = addlistener(hROI,'ROIClicked',@clickCallback);    
    % Block program execution
    uiwait;    
    % Remove listener
    delete(l);    
    % Return the current position
    pos = hROI.Position;
end

function clickCallback(~,evt)
    if strcmp(evt.SelectionType,'double')
        uiresume;
    end
end

function [flagStructData,image2show]=isstructImage2Show(image,channel)
    if isempty(channel)
        channel='Height (measured)';
    end    
    if isstruct(image)                       
        matchIdx = strcmp([image.Channel_name],channel) & strcmp([image.Trace_type],'Trace');
        image2show=image(matchIdx).AFM_image; 
        flagStructData=true;
    else
        image2show=image;
        flagStructData=false;
    end
end

function bin=isbinaryImage(image)
% return 0 or 1 if the image is binary (contains 0/1/nan)
    finiteVals = image(~isnan(image));       % drop NaNs before checking finite values
    hasZeroOne = all(ismember([0 1], finiteVals));
    if hasZeroOne, bin=1; else, bin=0; end
end
