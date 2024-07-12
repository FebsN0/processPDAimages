% to align AFM height IO image to BF IO image, the main alignment
function [padded_AFM,microscope_cut,AFM_data,pos_allighnment,details_it_reg]=A10_alignment_AFM_Microscope(BF_Mic_Image_IO,metaData_BF,AFM_height_IO,metaData_AFM,AFM_data,varargin)


dbstop if error
warning('off', 'Images:initSize:adjustingMag');


if(~isempty(varargin))
    for checkVar=1:size(varargin,2)
        if(isstruct(varargin{1,checkVar}))
            AFM_data=varargin{1,checkVar};
            [AFM_data(:).Padded]=deal(zeros(size(BF_Mic_Image_IO)));
            
            
            varargin(:,checkVar)=[];
            break
        end
    end
    if(size(varargin,2)==1)
        if(iscell(varargin{1,1}))
            varargin=vertcat(varargin{:});
        end
    end
end

p=inputParser();
argName = 'Silent';
defaultVal = 'No';
addOptional(p,argName,defaultVal,@(x) ismember(x,{'No','Yes'}));
argName = 'QuickMatch';
defaultVal = 'Yes';
addOptional(p,argName,defaultVal,@(x) ismember(x,{'No','Yes'}));
argName = 'CropStill';
defaultVal = 'Yes';
addOptional(p,argName,defaultVal,@(x) ismember(x,{'No','Yes'}));
argName = 'CropStillOriginal';
defaultVal = 'No';
addOptional(p,argName,defaultVal,@(x) ismember(x,{'No','Yes'}));
argName = 'Margin';
defaultVal = 25;
addOptional(p,argName,defaultVal,@(x) isnumeric(x) && (x > 0));

parse(p,varargin{:});
if(strcmp(p.Results.Silent,'Yes')), SeeMe=false; else, SeeMe=true; end
if(strcmp(p.Results.QuickMatch,'Yes')), aw='No'; end
fprintf(['Results of optional input:\n' ...
    '\tSilent:\t\t\t\t%s\n'      ...
    '\tQuickMatch:\t\t\t%s\n'  ...
    '\tCropStill:\t\t\t%s\n' ...
    '\tCropStillOriginal:\t%s\n' ...
    '\tMargin:\t\t\t\t%d\n'
    ],p.Results.Silent,p.Results.QuickMatch,p.Results.CropStill,p.Results.CropStillOriginal,p.Results.Margin)

% Optical microscopy and AFM image resolution can be entered here

if SeeMe==true
    [settings, ~] = settingsdlg(...
        'Description'                        , 'Setting the parameters that will be used in the elaboration', ...
        'title'                              , 'Image Alighnment options', ...
        'separator'                          , 'Microscopy Parameters', ...
        {'Image Width (um):';'MW'}               , metaData_BF.ImageWidthPixels*metaData_BF.ImageWidthMeter, ...
        {'Image Height (um):';'MH'}              , metaData_BF.ImageHeightPixels*metaData_BF.ImageHeightMeter, ... %modified to 237.18 from 237.10 on 12022020
        {'Or Img Size Px Width (Px):';'MicPxW'}  , metaData_BF.ImageWidthPixels, ...
        {'Or Img Size Px Height (Px):';'MicPxH'} , metaData_BF.ImageHeightPixels, ...
        'separator'                           , 'AFM Parameters', ...
        {'Image Width (um):';'AFMW'}          , metaData_AFM.x_scan_length, ...
        {'Image Height (um):';'AFMH'}         , metaData_AFM.y_scan_length, ...
        {'Image Pixel Width (Px):';'AFMPxW'}  , metaData_AFM.x_scan_pixels, ...
        {'Image Pixel Height (Px):';'AFMPxH'} , metaData_AFM.y_scan_pixels);
else
    settings.MW= metaData_BF.ImageWidthPixels*metaData_BF.ImageWidthMeter;
    settings.MicPxW= metaData_BF.ImageWidthPixels;
    settings.AFMW=metaData_AFM.x_scan_length;
    settings.AFMPxW=metaData_AFM.x_scan_pixels;
    settings.AFMH=metaData_AFM.y_scan_length;
    settings.AFMPxH=metaData_AFM.y_scan_pixels;
end
    
    MRatio=settings.MW/settings.MicPxW;
    AFMRatioVertical=settings.AFMW/settings.AFMPxW;
    AFMRatioHoriz=settings.AFMH/settings.AFMPxH;
    
    if(AFMRatioVertical==AFMRatioHoriz)
        moving=imresize(AFM_height_IO,AFMRatioVertical/MRatio);
         if(exist('AFM_data','var'))
            fprintf('\n Elaborating AFM images ... \n')
            for flag_AFM=1:size(AFM_data,2)
                AFM_data(flag_AFM).Cropped_AFM_image=imresize(AFM_data(flag_AFM).Cropped_AFM_image,AFMRatioVertical/MRatio);
            end
        end
    else
        moving=imresize(AFM_height_IO,[round(((AFMRatioVertical/MRatio)*size(AFM_height_IO,1)),0) round(((AFMRatioHoriz/MRatio)*size(AFM_height_IO,2)),0)]);
        if(exist('AFM_data','var'))
            fprintf('\n Elaborating AFM images ... \n')
            for flag_AFM=1:size(AFM_data,2)
                AFM_data(flag_AFM).Cropped_AFM_image=imresize(AFM_data(flag_AFM).Cropped_AFM_image,[round(((AFMRatioVertical/MRatio)*size(AFM_height_IO,1)),0) round(((AFMRatioHoriz/MRatio)*size(AFM_height_IO,2)),0)]);
            end
        end
    end

% crop BF IO image (as small as possible, for easier alignment)    

if(strcmp(p.Results.CropStillOriginal,'Yes'))
    awnser_Crop=questdlg(sprintf('Would you like to crop still image?'),'Crop Still Image','Yes','No','No');
    if(strcmp(awnser_Crop,'Yes'))
        showComplete_image=figure;imshow(BF_Mic_Image_IO);
        [~,specs]=imcrop(showComplete_image);
        close all
        YBegin=round(specs(1,1));
        XBegin=round(specs(1,2));
        YEnd=round(specs(1,1))+round(specs(1,3));
        XEnd=round(specs(1,2))+round(specs(1,end));
        
        if(XEnd>size(moving,1))
            XEnd=size(moving,1);
        end
        if(YEnd>size(moving,2))
            YEnd=size(moving,2);
        end
        still_OR=BF_Mic_Image_IO;
        BF_Mic_Image_IO=BF_Mic_Image_IO(XBegin:XEnd,YBegin:YEnd,:);
    else
        YBegin=nan;
        XBegin=nan;
        YEnd=nan;
        XEnd=nan;
    end
end

fprintf('\n First Cross Correlataion ... \n')
before1=clock;
cross_correlation=xcorr2_fft(BF_Mic_Image_IO,moving);
final_time=etime(clock,before1);

[~, imax] = max(abs(cross_correlation(:)));

[ypeak, xpeak] = ind2sub(size(cross_correlation),imax(1));

corr_offset = [(xpeak-size(moving,2)) (ypeak-size(moving,1))];
rect_offset = [(BF_Mic_Image_IO(1)-moving(1)) (BF_Mic_Image_IO(2)-moving(2))];

offset = corr_offset + rect_offset;
xoffset = offset(1);
yoffset = offset(2);

if(xoffset~=0)
    xbegin = round(xoffset);
else
    xbegin = 1;
end
xend   = round(xoffset+size(moving,2))-1;
if(yoffset~=0)
    ybegin = round(yoffset);
else
    ybegin = 1;
end
yend   = round(yoffset+size(moving,1))-1;

if(ybegin<=0)
    ybegin=1;
end
if(xbegin<=0)
    xbegin=1;
end

padded_AFM=(zeros(size(BF_Mic_Image_IO)));
padded_AFM(ybegin:yend,xbegin:xend,:) = moving;

figure('visible',SeeMe),imshowpair(BF_Mic_Image_IO(:,:,1),padded_AFM,'falsecolor')

if(strcmp(p.Results.QuickMatch,'No'))
    if(strcmp(SeeMe,'Yes'))
        aw=questdlg(sprintf('Would you like to maximize cross-correlation? \n Iterative, auto-expansion and compression of moving image. \n This will take approximately %3.2f min',final_time*100/20),'Optimization','Yes','No','No');
    else
        aw='Yes';
    end
end

[size_final_row,size_final_col]=size(moving);

rotation_deg=0;

if(strcmp(aw,'Yes'))
    size_final_row=size(moving,1);
    size_final_col=size(moving,2);
    N_cycles_opt=1;

    StepChanges=0;
    if(strcmp(SeeMe,'Yes'))
        hWait = waitbar(0,'Initializing', ...
            'Name','Iterative Cross Correlation ...', ...
            'CreateCancelBtn', ...
            'setappdata(gcbf,''canceling'',1)');
        setappdata(hWait,'canceling',0);
    end
    
    if(strcmp(p.Results.CropStillOriginal,'Yes'))
        if(ybegin-p.Results.Margin>=1)&&(xbegin-p.Results.Margin>=1)&&(yend+p.Results.Margin<size(BF_Mic_Image_IO,2))&&(xend+p.Results.Margin<size(BF_Mic_Image_IO,2))
            still_reduced=BF_Mic_Image_IO(ybegin-p.Results.Margin:yend+p.Results.Margin,xbegin-p.Results.Margin:xend+p.Results.Margin,:);
        else
            still_reduced=BF_Mic_Image_IO;
        end
    else
        still_reduced=BF_Mic_Image_IO;
    end
    
    cross_correlation=xcorr2_fft(still_reduced,moving);
    [max_c_it_OI,~] = max(abs(cross_correlation(:)));
    options= { ...
        sprintf('TRCDA\n(Limit_Cycles: 1000; StepSize: 0.005 Tot_par: 2)'),...
        sprintf('DCDA\n(Limit_Cycles: 500; StepSize: 0.0001 Tot_par: 50)'),...
        sprintf('PCDA\n(Limit_Cycles: 1000; StepSize: 0.00001 Tot_par: 500)'),...
        'Enter manually the values'};
    question='Select the Polydiacetylene used in the experiment to prepare the alignment cycle parameters ';
    answer=getValidAnswer(question,'',options);
    switch answer
        case 1
            Limit_Cycles=1000; % the number of iteration of alignment, can be modified
            StepSize=0.005; % the increase in resize, can be modified
            Rot_par=2; % the extra rotational parameter, can be modified
        case 2
            Limit_Cycles=500; % the number of iteration of alignment, can be modified
            StepSize=0.0001; % the increase in resize, can be modified
            Rot_par=50; % the extra rotational parameter, can be modified
        case 3
            Limit_Cycles=1000; % the number of iteration of alignment, can be modified
            StepSize=0.00001; % the increase in resize, can be modified
            Rot_par=500; % the extra rotational parameter, can be modified
        case 4
            cycleParameters=zeros(3,1);
            question ={'Enter the Limit Cycle:' ...
                'Enter the step size:'...
                'Enter the rotational parameter'};
            valueDefault = {'1000','0.005','2'};
            while true
                cycleParameters = str2double(inputdlg(question,'Setting parameters for the alignment',[1 90],valueDefault));
                if any(isnan(cycleParameters)), questdlg('Invalid input! Please enter a numeric value','','OK','OK');
                else, break
                end
            end
            Limit_Cycles=cycleParameters(1);
            StepSize=cycleParameters(2);
            Rot_par=cycleParameters(3);
    end

    wb=waitbar(0/Limit_Cycles,'Processing the expanding/reduction/rotation optimization','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);
  
    while(N_cycles_opt<=Limit_Cycles)
        if(exist('wb','var'))
            %if cancel is clicked, stop
            if getappdata(wb,'canceling')
               break
            end
        end
        waitbar(N_cycles_opt/Limit_Cycles,wb,'Processing the expanding/reduction/rotation optimization');

        if(N_cycles_opt==1)
            moving_iterative_Oversize=imresize(moving,1+StepSize*N_cycles_opt);
            cross_correlation_Oversize=xcorr2_fft(still_reduced,moving_iterative_Oversize);
            [max_c_iterative(1,1),imax(1,1)] = max(abs(cross_correlation_Oversize(:)));
            
            moving_iterative_Undersize=imresize(moving,1-StepSize*N_cycles_opt);
            cross_correlation_Undersize=xcorr2_fft(still_reduced,moving_iterative_Undersize);
            [max_c_iterative(1,2),imax(1,2)] = max(abs(cross_correlation_Undersize(:)));
            
            moving_iterative_PosRot=imrotate(moving,StepSize*N_cycles_opt*Rot_par,'nearest','loose');
            cross_correlation_PosRot=xcorr2_fft(still_reduced,moving_iterative_PosRot);
            [max_c_iterative(1,3),imax(1,3)] = max(abs(cross_correlation_PosRot(:)));
            
            moving_iterative_NegRot=imrotate(moving,-StepSize*N_cycles_opt*Rot_par,'nearest','loose');
            cross_correlation_NegRot=xcorr2_fft(still_reduced,moving_iterative_NegRot);
            [max_c_iterative(1,4),imax(1,4)] = max(abs(cross_correlation_NegRot(:)));
        else
            moving_iterative_Oversize=imresize(moving_OPT,1+StepSize*N_cycles_opt);
            cross_correlation_Oversize=xcorr2_fft(still_reduced,moving_iterative_Oversize);
            [max_c_iterative(1,1),imax(1,1)] = max(abs(cross_correlation_Oversize(:)));
            
            moving_iterative_Undersize=imresize(moving_OPT,1-StepSize*N_cycles_opt);
            cross_correlation_Undersize=xcorr2_fft(still_reduced,moving_iterative_Undersize);
            [max_c_iterative(1,2),imax(1,2)] = max(abs(cross_correlation_Undersize(:)));
            
            moving_iterative_PosRot=imrotate(moving_OPT,StepSize*N_cycles_opt*Rot_par,'nearest','loose');
            cross_correlation_PosRot=xcorr2_fft(still_reduced,moving_iterative_PosRot);
            [max_c_iterative(1,3),imax(1,3)] = max(abs(cross_correlation_PosRot(:)));
            
            moving_iterative_NegRot=imrotate(moving_OPT,-StepSize*N_cycles_opt*Rot_par,'nearest','loose');
            cross_correlation_NegRot=xcorr2_fft(still_reduced,moving_iterative_NegRot);
            [max_c_iterative(1,4),imax(1,4)] = max(abs(cross_correlation_NegRot(:)));
        end
        
        if(max(max_c_iterative)>max_c_it_OI)
            if(~exist('z','var'))
                z=1;
                fprintf('\n')
            else
                z=z+1;
            end
            [a,b]=max(max_c_iterative);
            max_c_it_OI=a;
            if(b==1)
                moving_OPT=moving_iterative_Oversize;
                imax_OI=imax(1,1);
                size_OI=size(cross_correlation_Oversize);
                details_it_reg(z,1)=1;
                details_it_reg(z,2)=size(moving,1);
                details_it_reg(z,3)=size(moving,2);
                fprintf('\n Expansion Scaling Optimization Found ... %f \n',details_it_reg(z,2))
                if(exist('AFM_data','var'))
                    fprintf('\n Elaborating AFM images ... \n')
                    for flag_AFM=1:size(AFM_data,2)
                        AFM_data(flag_AFM).Cropped_AFM_image=imresize(AFM_data(flag_AFM).Cropped_AFM_image,1+StepSize*N_cycles_opt);
                    end
                end
            elseif(b==2)
                moving_OPT=moving_iterative_Undersize;
                imax_OI=imax(1,2);
                size_OI=size(cross_correlation_Undersize);
                details_it_reg(z,1)=1;
                details_it_reg(z,2)=size(moving,1);
                details_it_reg(z,3)=size(moving,2);
                fprintf('\n Contraction Scaling Optimization Found ... %f \n',details_it_reg(z,2))
                if(exist('AFM_data','var'))
                    fprintf('\n Elaborating AFM images ... \n')
                    for flag_AFM=1:size(AFM_data,2)
                        AFM_data(flag_AFM).Cropped_AFM_image=imresize(AFM_data(flag_AFM).Cropped_AFM_image,1-StepSize*N_cycles_opt);
                    end
                end
            elseif(b==3)
                moving_OPT=moving_iterative_PosRot;
                imax_OI=imax(1,3);
                size_OI=size(cross_correlation_PosRot);
                details_it_reg(z,1)=0;
                details_it_reg(z,2)=StepSize*N_cycles_opt*Rot_par;
                details_it_reg(z,3)=nan;
                fprintf('\n Clock Wise Rotation Scaling Optimization Found ... %f \n',details_it_reg(z,2))
                if(exist('AFM_data','var'))
                    fprintf('\n Elaborating AFM images ... \n')
                    for flag_AFM=1:size(AFM_data,2)
                        AFM_data(flag_AFM).Cropped_AFM_image=imrotate(AFM_data(flag_AFM).Cropped_AFM_image,StepSize*N_cycles_opt*Rot_par,'bilinear','loose');
                    end
                end
            else
                moving_OPT=moving_iterative_NegRot;
                imax_OI=imax(1,4);
                size_OI=size(cross_correlation_NegRot);
                details_it_reg(z,1)=0;
                details_it_reg(z,2)=-StepSize*N_cycles_opt*Rot_par;
                details_it_reg(z,3)=nan;
                fprintf('\n Counter Clock Wise Rotation Scaling Optimization Found ... %f \n',details_it_reg(z,2))
                if(exist('AFM_data','var'))
                    fprintf('\n Elaborating AFM images ... \n')
                    for flag_AFM=1:size(AFM_data,2)
                       AFM_data(flag_AFM).Cropped_AFM_image=imrotate(AFM_data(flag_AFM).Cropped_AFM_image,-StepSize*N_cycles_opt*Rot_par,'bilinear','loose');
                    end
                end
            end
            if(exist('h_it','var'))
                close(h_it)
            end
            if(size(moving_OPT)<size(still_reduced))
                [ypeak, xpeak] = ind2sub(size_OI,imax_OI(1));
                corr_offset = [(xpeak-size(moving_OPT,2)) (ypeak-size(moving_OPT,1))];
                rect_offset = [(still_reduced(1)-moving_OPT(1)) (still_reduced(2)-moving_OPT(2))];
                offset = corr_offset + rect_offset;
                xoffset = offset(1);
                yoffset = offset(2);
                if(xoffset~=0)
                    xbegin = round(xoffset);
                else
                    xbegin = 1;
                end
                xend   = round(xoffset+size(moving_OPT,2))-1;
                if(yoffset~=0)
                    ybegin = round(yoffset);
                else
                    ybegin = 1;
                end
                yend   = round(yoffset+size(moving_OPT,1))-1;
                
                if(ybegin<=0)
                    ybegin=1;
                end
                if(xbegin<=0)
                    xbegin=1;
                end
                if(exist('padded_AFM','var'))
                    clearvars padded_AFM
                end
                padded_AFM=(zeros(size(still_reduced)));
                padded_AFM(ybegin:yend,xbegin:xend,:) = moving_OPT;
                [size_final_row,size_final_col]=size(moving_OPT);
                h_it=figure('visible',SeeMe);imshowpair(still_reduced,padded_AFM,'falsecolor');
            else
                h_it=figure('visible',SeeMe);imshowpair(still_reduced,moving_OPT,'falsecolor');
            end
            N_cycles_opt=N_cycles_opt+1;
        else
            fprintf('\n\n Changing Step Size ... \n')
            StepSize=StepSize/2;
            N_cycles_opt=N_cycles_opt+1;
            StepChanges=StepChanges+1;
            if(StepChanges==3)
                N_cycles_opt=Limit_Cycles+1;
            end
        end
        
    end
%     if(strcmp(SeeMe,'on'))
%         delete(hWait)
%     end
else
    details_it_reg=[];
    details_it_reg(1,1)=1;
    details_it_reg(1,2)=size(moving,1);
    details_it_reg(1,3)=size(moving,2);
end


if(exist('AFM_data','var'))
    fprintf('\n Final elaboration of AFM images ... \n')
    for flag_size=1:size(AFM_data,2)
         AFM_data(flag_size).Padded(ybegin:size(AFM_data(flag_size).Cropped_AFM_image,1)+ybegin-1,xbegin:size(AFM_data(flag_size).Cropped_AFM_image,2)+xbegin-1)=AFM_data(flag_size).Cropped_AFM_image;
    end
end

fprintf('\n')
pos_allighnment=struct(...
    'YBegin',...
    ybegin,...
    'YEnd',...
    yend,...
    'XBegin',...
    xbegin,...
    'XEnd',...
    xend,...
    'FinalAdjPixelCol',...
    size_final_row,...
    'FinalAdjPixelRow',...
    size_final_col,...
    'Rotation',...
    rotation_deg,...
    'MarginOfBFReduced',...
    p.Results.Margin);


if(strcmp(p.Results.CropStill,'Yes'))
    warning_Flag=0;
    a=ybegin-p.Results.Margin;
    c=xbegin-p.Results.Margin;
    b=yend+p.Results.Margin;
    d=xend+p.Results.Margin;
    if ~(ybegin-p.Results.Margin>=1)
        a=1;
        warning_Flag=1;
    end
    if ~(xbegin-p.Results.Margin>=1)
        c=1;
        warning_Flag=1;
    end
    if ~(yend+p.Results.Margin<size(BF_Mic_Image_IO,1))
        b=size(BF_Mic_Image_IO,1);
        warning_Flag=1;
    end
    if ~(xend+p.Results.Margin<size(BF_Mic_Image_IO,2))
        d=size(BF_Mic_Image_IO,2);
        warning_Flag=1;
    end
    microscope_cut=BF_Mic_Image_IO(a:b,c:d);
    if(warning_Flag==1)
        warndlg('Was not able to assign Cut Microscope image ... ')
    end
end

end
