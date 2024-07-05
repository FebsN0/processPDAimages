function [data,metaData,filePathData] = A1_openANDassembly_JPK
    %%%% the funtion open .jpk files. If there are more files than one, then assembly togheter before process
    %%%% them

    [fileName, filePathData] = uigetfile('*.jpk', 'Select a .jpk AFM image','MultiSelect', 'on');
    if isequal(fileName,0)
        error('No File Selected');
    else
        if iscell(fileName)
            numFiles = length(fileName);
        else
            numFiles = 1; % if only one file, filename is a string
        end
    end

    if numFiles > 1
        question= sprintf('More .jpk files are uploaded. Are they from the same experiment which only setpoint is changed?');
        options= {'Yes','No'};
        if getValidAnswer(question,'',options) ~= 1
            error('Restart again and select only one .jpk file if the more uploaded .jpk are from different experiment')
        end
    end

    % assembly the .jpk files
    for i=1:numFiles
        % open jpk, it returns the AFM file, the details (position of tip, IGain, Pgain, Sn, Kn and
        % calculates alpha, based on the pub), it returns the location of the file.
        [data,metaData]=A1_open_JPK(fullfile(filePathData,fileName));
    
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
            % ASSEMBLY DATA

            % FIX METADATA vedendo il contenuto di metaData
    
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end


end