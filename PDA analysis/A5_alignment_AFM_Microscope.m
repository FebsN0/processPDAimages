% to align AFM height IO image to BF IO image, the main alignment
function [AFM_IO_3_BFaligned,BF_IO_1_cropped,AFM_Elab,info_allignment,offset]=A5_alignment_AFM_Microscope(BF_IO_0_original,metaData_BF,AFM_IO_0_mask,metaData_AFM,AFM_Elab,newFolder,idxMon,varargin)
    % OUTPUT DETAILS
    %   - AFM_IO_padded :   AFM height 0/1 data ALIGNED with BF 0/1 data BUT the image is slighly bigger (in
    %                       case of margin or only crop) which values, outside AFM height is only 0. Briefly,
    %                       it is the moving data
    %   - BF_IO_choice :   same size as the previous output data, it is the fixed data used for alignment
    %   - AFM_Elab      :   the AFM data with any channels. Post elaboration of the original AFM_Elab used as input.
    %                       the updates consist in:
    %                               1) AFM_image field  (update): the original data is aligned (rotation and resize)
    %                               2) AFM_Padded field         (new): it is the same of before, but in the space of BF original image (BF_Mic_Image_IO input variable)
    %   - pos_allignment
    %   - details_it_reg:   contains all the iterative (both manual or automatic) steps performed to process the AFM image. Two possibilities for each row
    %                       1) 1 : resize | scale (positive or negative)
    %                       2) 0 : rotation | degree rotation
    %
    % INPUT DETAILS

    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)

    p=inputParser();
    % Add required parameters
    addRequired(p, 'BF_Mic_Image_IO');
    addRequired(p,'metaData_BF')
    addRequired(p, 'AFM_height_IO');
    addRequired(p,'metaData_AFM')
    addRequired(p,'AFM_Elab') 
    
    argName = 'Silent';     defaultVal = 'No';      addParameter(p, argName, defaultVal, @(x) ismember(x,{'No','Yes'}));
    % how much bigger by fixed margin should be the BF compared to AFM size. Kind of fixed cropping
    argName = 'Margin';     defaultVal = 100;       addParameter(p,argName,defaultVal,@(x) isnumeric(x) && (x >= 0));
    parse(p,BF_IO_0_original,metaData_BF,AFM_IO_0_mask,metaData_AFM,AFM_Elab,varargin{:});
    clear argName defaultVal varargin
    if(strcmp(p.Results.Silent,'Yes')), SeeMe=false; else, SeeMe=true; end

    % x and y lengths of AFM image are in meters ==> convert to um 
    metaData_AFM.x_scan_length=metaData_AFM.x_scan_length_m*1e6;
    metaData_AFM.y_scan_length=metaData_AFM.y_scan_length_m*1e6;
    % Optical microscopy and AFM image resolution can be entered here
    if length(metaData_AFM.y_scan_pixels)~=1
        y_scan_pixelsCorrected=sum(metaData_AFM.y_scan_pixels);
    else
        y_scan_pixelsCorrected=metaData_AFM.y_scan_pixels;
    end

    if SeeMe
        [settings, ~] = settingsdlg(...
            'Description'                        , 'Setting the parameters that will be used in the elaboration', ...
            'title'                              , 'Image Alighnment options', ...
            'separator'                          , 'Microscopy Parameters (original data)', ...
            {'Image Width (um):';'MW'}               , metaData_BF.ImageWidthPixels*metaData_BF.ImageWidth_umeterXpixel, ...
            {'Image Height (um):';'MH'}              , metaData_BF.ImageHeightPixels*metaData_BF.ImageHeight_umeterXpixel, ... %modified to 237.18 from 237.10 on 12022020
            {'Or Img Size Px Width (Px):';'MicPxW'}  , metaData_BF.ImageWidthPixels, ...
            {'Or Img Size Px Height (Px):';'MicPxH'} , metaData_BF.ImageHeightPixels, ...
            'separator'                           , 'AFM Parameters', ...
            {'Image Width (um):';'AFMW'}          , metaData_AFM.x_scan_length, ...
            {'Image Height (um):';'AFMH'}         , metaData_AFM.y_scan_length, ...
            {'Image Pixel Width (Px):';'AFMPxW'}  , metaData_AFM.x_scan_pixels, ...
            {'Image Pixel Height (Px):';'AFMPxH'} , y_scan_pixelsCorrected);
    else
        settings.MW= metaData_BF.ImageWidthPixels*metaData_BF.ImageWidthMeter;
        settings.MH= metaData_BF.ImageHeightPixels*metaData_BF.ImageHeightMeter;
        settings.MicPxW= metaData_BF.ImageWidthPixels;
        settings.MicPxH= metaData_BF.ImageHeightPixels;
        settings.AFMW=metaData_AFM.x_scan_length;
        settings.AFMPxW=metaData_AFM.x_scan_pixels;
        settings.AFMH=metaData_AFM.y_scan_length;
        settings.AFMPxH=y_scan_pixelsCorrected;
    end
    
    BFRatioHorizontal=settings.MW/settings.MicPxW;              % size in um of single pixel based on entire image (horizontal - BF  image)
    BFRatioVertical=settings.MH/settings.MicPxH;                % size in um of single pixel based on entire image (vertical - BF  image)
    AFMRatioHorizontal=settings.AFMW/settings.AFMPxW;           % size in um of single pixel based on entire image (horizontal - AFM image
    AFMRatioVertical=settings.AFMH/settings.AFMPxH;             % size in um of single pixel based on entire image (vertical   - AFM image)
    clear settings
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%% FIRST MODIFICATION %%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  SCALING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % The AFM and BF may be in different meter scale (i.e. the size in meter of single pixel may be different)
    % Therefore a scaling is required so that the size of the single pixel is the same as the BF image. If the
    % ratio is > 1 ==> than the AFM image's size will increase, otherwise it will decrease
    scaleAFM2BF_H=  AFMRatioHorizontal/BFRatioHorizontal;
    scaleAFM2BF_V=  AFMRatioVertical/BFRatioVertical;    
    if(AFMRatioVertical==AFMRatioHorizontal)
        % if the x and y pixel sizes are the same
        scale = scaleAFM2BF_H;              % scalar value
    else
         % if the x and y pixel sizes are not the same
        scale = [round(scaleAFM2BF_H*size(AFM_IO_0_mask,1)) round(scaleAFM2BF_V*size(AFM_IO_0_mask,2))];    % number of rows and columns
    end
    % apply the scale to AFM_IO and AFM data
    AFM_IO_1_BFscaled=imresize(AFM_IO_0_mask,scale);
    for flag_AFM=1:size(AFM_Elab,2)
        % scale the AFM channels. It doesnt mean that the matrix size of AFM and BF images will be the same.
        % Indipendent from BF processing
        AFM_Elab(flag_AFM).AFM_scaled=imresize(AFM_Elab(flag_AFM).AFM_images_2_PostProcessed,scale);
    end
    clear BFRatioHorizontal BFRatioVertical AFMRatioHorizontal AFMRatioVertical scaleAFM2BF_H scaleAFM2BF_V scale y_scan_pixelsCorrected flag_AFM
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%   FIRST STEP   %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%  LOCATING AFM_IO WITH BF_IO  %%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % first correlation and best alignment the AFM IO height and BF images. Then show it. This step is only to
    % locate, without really adjust the data, to understand how make a better crop
    % rect is required to locate the AFM respect to BF
    [max_c_it_OI,~,rect,AFM_IO_2_BFpadded] = A5_feature_crossCorrelationAlignmentAFM(BF_IO_0_original,AFM_IO_1_BFscaled);
    f1=figure; axFig=axes('Parent', f1);
    figPair=imshowpair(BF_IO_0_original,AFM_IO_2_BFpadded,'falsecolor','Parent',axFig);
    title('Brightfield and AFM images - Post First cross-correlation','FontSize',14)
    objInSecondMonitor(f1,idxMon);
    saveFigures_FigAndTiff(f1,newFolder,"resultA5_1_BForiginal_AFMresize_firstCrossCorrelation",'closeImmediately',false)    
    AFM_Elab_original=AFM_Elab;
    while true
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%   SECOND STEP   %%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%  CROP AFM_IO AND BF_IO  %%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        f1.Visible = 'on';
        figure(f1)
        question='Choose one of the following options before run the optimization';
        options={ ...
            sprintf('1) Crop manually the BF image'), ...
            sprintf('2) Use a defined margin (%d pixels)?',p.Results.Margin), ... 
            sprintf('3) None')};
        answerCrop = getValidAnswer(question, '', options,2);        
        if answerCrop == 1
        % crop the right area containing the AFM image, if not, restart
            uiwait(msgbox('Crop the area of interest containing the stimulated part',''));
            [~,specs]=imcrop(figPair);
            % extract the cropped area
            XBegin=round(specs(1));
            YBegin=round(specs(2));
            XEnd=round(specs(1))+round(specs(3));
            YEnd=round(specs(2))+round(specs(end));
            % if cropped outise image
            if(YEnd>size(BF_IO_0_original,1)), YEnd=size(BF_IO_0_original,1); end
            if(XEnd>size(BF_IO_0_original,2)), XEnd=size(BF_IO_0_original,2); end
            % crop the BF original
            BF_IO_1_cropped=BF_IO_0_original(YBegin:YEnd,XBegin:XEnd);
            % create AFM image with same BF cropped size. Here alignment by cross-correlation is required at
            % the contrary of the other margin method because it is better
            [~,~,locationAFM2toBF1,AFM_IO_2_BFpadded] = A5_feature_crossCorrelationAlignmentAFM(BF_IO_1_cropped,AFM_IO_1_BFscaled);
        elseif answerCrop == 2
        % extract the BF with border depending on the margin
            % save the coordinates of AFM resized in the 2D space of BF original
            xbegin = rect(1); xend = rect(2);
            ybegin = rect(3); yend = rect(4);
            % FIX LEFT BORDER: if the BF border is very close and less than margin, then "modify" the margin to the extreme BF border
            if (xbegin-p.Results.Margin>=1), XBegin=xbegin-p.Results.Margin; else, XBegin=1; end
            % FIX RIGHT BORDER
            if (size(BF_IO_0_original,2)-xend > p.Results.Margin), XEnd=xend+p.Results.Margin; else, XEnd=size(BF_IO_0_original,2); end
            % FIX BOTTOM BORDER
            if (ybegin-p.Results.Margin>=1), YBegin=ybegin-p.Results.Margin; else, YBegin=1; end
            % FIX TOP BORDER
            if (size(BF_IO_0_original,1)-yend > p.Results.Margin), YEnd=yend+p.Results.Margin; else, YEnd=size(BF_IO_0_original,1); end
            % crop the BF IO using the margin
            BF_IO_1_cropped=BF_IO_0_original(YBegin:YEnd,XBegin:XEnd);
            % new crosscorrelation to locate the AFM to the new BF                        
            [~,~,locationAFM2toBF1,AFM_IO_2_BFpadded] = A5_feature_crossCorrelationAlignmentAFM(BF_IO_1_cropped,AFM_IO_1_BFscaled);
        else
            % do nothing
            BF_IO_1_cropped=BF_IO_0_original;
            locationAFM2toBF1=rect;            
        end
        % store the new dimensions of BF to adjust the TRITIC matrix 
        if answerCrop == 3
            offset=[];
        else
            offset=[YBegin,YEnd,XBegin,XEnd];              
        end
        
        f1.Visible = 'off';
        clear yend ybegin xend xbegin tmp_*
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%  THIRD STEP  %%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%  AFM_IO and BF_IO ALIGNMENT  %%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% NOTE: although the AFM and BF images have same sizes, the true content of AFM is smaller and coincides
        %%% with the AFM_IO_1_BFscaled        
        question='Maximizing the cross-correlation between the BF and AFM images.'; ...
        options={ ...
            sprintf('(1) Manual method\n Choose which operation (expansion, reduction and rotation) run.'); ...
            sprintf('(2) Automatic method\n Iterative process of expansion, reduction and rotation.'); ...
            sprintf('(3) Automatic method\n Thirion''s Demons Algorithm and Diffeomorphism')
                    '(4) Stop here the process. The fist cross-correlatin is okay.'};
        answerMethod=getValidAnswer(question,'',options,3);        
        clear flag_AFM options question saveFig SeeMe textTitle BF_IO_0_original rect
        flagDemons=false;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% manual approach %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if answerMethod==1
            % the output AFM_Elab will contain the corrected aligned data. Rect is required to 
            [AFM_IO_3_BFaligned,AFM_Elab,details_it_reg,rect]=A5_feature_manualAlignmentGUI(AFM_IO_2_BFpadded,BF_IO_1_cropped,AFM_Elab,locationAFM2toBF1,max_c_it_OI,idxMon,newFolder);                         
            textTitle='Brightfield IO - AFM IO -Final Alignment (Manual Approach)';
        %%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% automatic approach %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%
        elseif answerMethod == 2
            textTitle='Brightfield IO - AFM IO -Final Alignment (Automatic Approach)';
            [AFM_IO_3_BFaligned,AFM_Elab,details_it_reg,rect]=A5_feature_automaticLinearAlignment(AFM_IO_2_BFpadded,BF_IO_1_cropped,AFM_Elab,locationAFM2toBF1,max_c_it_OI,idxMon,newFolder);
        %%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% Demon's approach %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%                       
        elseif answerMethod==3
            % imregdemons(MOVING,FIXED)
            [DisplacementField,~] = imregdemons(AFM_IO_2_BFpadded,BF_IO_1_cropped,1000,'AccumulatedFieldSmoothing',2.0,'PyramidLevels',8,'DisplayWaitbar',true);
            % unfortunately, imregdemons uses bilinear interpolation and it is not possible to change 
            % (no optional arguments regarding the interpolation [...,'Interp', 'nearest']) because imregdemons is hardcoded
            % Consequently, the pixels at the borders (between 0 and 1) will no longer be binary.
            % To overcome the issue, only the displacement field will be considered and then used to warp AFM_IO_2_BFpadded,
            % rather than using the second output of imregdemons.
            AFM_IO_3_BFaligned = imwarp(AFM_IO_2_BFpadded,DisplacementField, 'Interp', 'nearest');
            % further check. It should not happen, but just in case...
            nonBinaryMask = AFM_IO_3_BFaligned(AFM_IO_3_BFaligned ~= 0 & AFM_IO_3_BFaligned ~= 1);
            if ~isempty(nonBinaryMask)
                uiwait(warndlg("Aware! For some unexpected reason, the interpolation of the borders 0-1 gave non binary values! Using the average, such values will be biclassified."))
                threshold=mean(nonBinaryMask(:));
                AFM_IO_3_BFaligned = AFM_IO_3_BFaligned > threshold;
            end
            textTitle='Brightfield IO - AFM IO - Final Alignment (Automatic Demon''s Algorithm Approach)';
            % first, create the pad version where there is in the middle the AFM data, then transforms image according to the displacement field.
            for flag_AFM=1:size(AFM_Elab,2)
                % first create zero matrix with the same dimension of the AFM IO mask
                AFM_Elab(flag_AFM).AFM_padded=zeros(size(AFM_IO_3_BFaligned));
                % move the AFM data channel to the same position of AFM IO mask
                AFM_Elab(flag_AFM).AFM_padded(locationAFM2toBF1(3):locationAFM2toBF1(4),locationAFM2toBF1(1):locationAFM2toBF1(2))=AFM_Elab(flag_AFM).AFM_scaled;
                adjDataTmp = imwarp(AFM_Elab(flag_AFM).AFM_padded,DisplacementField);
                AFM_Elab(flag_AFM).AFM_padded=adjDataTmp;               
            end
            flagDemons=true;
            details_it_reg=nan;
            clear adjDataTmp DisplacementField
        %%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%% Do nothing %%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%% 
        else
            AFM_IO_3_BFaligned=AFM_IO_2_BFpadded;
            for flag_AFM=1:size(AFM_Elab,2)
                AFM_Elab(flag_AFM).AFM_aligned=AFM_Elab(flag_AFM).AFM_scaled;
            end
            rect=locationAFM2toBF1;
            details_it_reg=nan;            
        end
        if ~flagDemons
            % pad AFM data too in right location respect to AFM_IO_3 and BF_IO_2 too
            for flag_AFM=1:size(AFM_Elab,2)
                AFM_Elab(flag_AFM).AFM_padded=zeros(size(AFM_IO_3_BFaligned));
                AFM_Elab(flag_AFM).AFM_padded(rect(3):rect(4),rect(1):rect(2))=AFM_Elab(flag_AFM).AFM_aligned;
            end
        end    
        % moving final in Manual era AFM_IO con la dimensione originale. In questo non piu utile perche si vuole prendere quella padded                                
        if any(size(AFM_IO_3_BFaligned) ~= size(BF_IO_1_cropped))
            messageError=sprintf(['\nThe resulting size between AFM_IO (%dx%d) and BF_IO (%dx%d) are different.\n',...
                'Try again this entire alignment step by cropping a bigger area or increase margin ',...
                'or use manual method with caution.\n',...
                'This happened because during the rotation or excessive expansion, one of the AFM matrix border went outside the fluorescence border.\n'],size(AFM_IO_3_BFaligned),size(BF_IO_1_cropped));
            error(messageError) %#ok<SPERR>
        end    
        % SHOW THE FINAL ALIGNMENT
        f3=figure;
        imshowpair(BF_IO_1_cropped,AFM_IO_3_BFaligned,'falsecolor');
        objInSecondMonitor(f3,idxMon);
        title(textTitle,'FontSize',14)
        saveFigures_FigAndTiff(f3,newFolder,"resultA5_4_BFreduced_AFMopt_EndAlignment",'closeImmediately',false)
        if getValidAnswer('Satisfied of the alignment (y) or restart (n)?','',{'y','n'})
            close all
            break
        end
        AFM_Elab=AFM_Elab_original;
        close(f3)
    end   

    if answerCrop == 1
        answerCrop= 'Cropped'; applied='Not applied';
    elseif answerCrop == 2
        answerCrop='Margin'; applied=p.Results.Margin; 
    else
        answerCrop='None'; applied='Not applied';
    end

    if answerMethod==4
        answerMethod='None';
        rotation_deg_tot = 'Not applied';         
    elseif answerMethod~=3
        rotation_deg_tot=sum(details_it_reg(details_it_reg(:,1)==0,2));
        total_resize=sum(details_it_reg(details_it_reg(:,1)==1,2));
        if answerMethod == 1
            answerMethod = 'Manual';
        else
            answerMethod='Automatic';
        end
    else
        answerMethod='Automatic - Demon''s algorithm';
        rotation_deg_tot='Not available';
        total_resize='Not available';       
    end
    % save all the information    
    info_allignment=struct(...
    'MarginOrCroppedOrNone', answerCrop, ...
    'AmountMargin', applied, ...
    'MethodOptimization', answerMethod, ...
    'OperationPerformed', details_it_reg, ...
    'TotalRotation', rotation_deg_tot, ...
    'TotalResize', total_resize);
end
