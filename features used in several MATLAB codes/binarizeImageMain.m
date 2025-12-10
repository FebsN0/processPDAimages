function [IO_Image,binarizationMethod]=binarizeImageMain(image,idxMon,varargin)    
    image=imadjust(image);
    % start the classic binarization to create the mask, i.e. the 0/1 height image (0 = Background, 1 = Foreground). 
    [IO_Image,binarizationMethod]=binarize_GUI(image);                         
    % PYTHON BINARIZATION TECHNIQUES. It requires other options, when I will have more time. Especially for DeepLearning technique
    question="Satisfied of the first binarization method? If not, run the Python Binarization tools!";
    if ~getValidAnswer(question,"",{"Yes","No"},2)
        [IO_Image,binarizationMethod]=binarization_withPythonModules(image,idxMon);
    end    
    % show data and if it is not okay, start toolbox segmentation    
    if ~isempty(varargin)     
        iterationMain=varargin{1};
        question=sprintf('Satisfied of the binarization of the iteration %d? If not, run ImageSegmenter ToolBox for better manual binarization',iterationMain);    
        if iterationMain>1 && ~getValidAnswer(question,'',{'Yes','No'})                    
            % Run ImageSegmenter Toolbox if at end of the second iteration, the mask is still not good enough
            [IO_Image,binarizationMethod]=binarization_ImageSegmenterToolbox(image,idxMon);
        end
    end
end


%%%% ADD HERE ALL THE BINARIZATION METHODS

% IMAGE_SEGMENTER_TOOLBOX (USE IN THE WORST CASE).
function [IO_Image,binarizationMethod]=binarization_ImageSegmenterToolbox(image,idxMon)
    textTitle='Image original - CLOSE THIS WINDOW WHEN SEGMENTATION TERMINATED';
    fImageSegToolbox=showData(idxMon,true,image,textTitle,'','','saveFig',false,'normalized',true);
    % ImageSegmenter return vars and stores in the base workspace, outside the current
    % function. So take it from there. Save the workspace of before and after and take
    % the new variables by checking the differences of workspace
    tmp1=evalin('base', 'who');
    image_norm=image/max(image(:));
    imageSegmenter(image_norm), colormap parula
    waitfor(fImageSegToolbox)
    tmp2=evalin('base', 'who');
    varBase=setdiff(tmp2,tmp1);
    for i=1:length(varBase)            
        text=sprintf('%s',varBase{i});
        var = evalin('base', text);
        ftmp=figure;
        imshow(var), colormap parula            
        if getValidAnswer('Is the current figure the right binarized AFM?','',{'Yes','No'})
            close(ftmp)
            IO_Image=var;
            break
        end
        close(ftmp)
    end
    binarizationMethod="ImageSegmenter Toolbox";      
end

% BINARIZE WITH PYTHON METHODS
function mod=extractBinarizationPYmodule()
% the python file is assumed to be in a directory called "PythonCodes". Find it to a max distance of 4 upper
    % folders
    % Maximum levels to search
    maxLevels = 4; originalPos=pwd;
    for i=1:maxLevels
        if isfolder(fullfile(pwd, 'PythonCodes'))
            cd 'PythonCodes'
            % Call the Python function
            mod = py.importlib.import_module("binarize_stripe_image");
            py.importlib.reload(mod);
                    
            break
        elseif i==4
            error("file python not found")
        else
            cd ..        
        end            
    end 
    % return to original position
    cd(originalPos)  
end
function [IO_Image,binarizationMethod]=binarization_withPythonModules(idxMon,image)    
    modulePython=extractBinarizationPYmodule();
    % show height image for help
    titletext='Image - original';
    ftmp=showData(idxMon,true,image,titletext,'','','normalized',true,'saveFig',false);            
    % NOTE, output from python function are py.numpy.ndarray, not MATLAB arrays. Therefore, take BW and corrected directly appear unusable.
    options={'Otsu','Multi-Otsu','Sauvola','Niblack','Bradley-Roth','Adaptive-Gaussian','Yen','Li','Triangle','Isodata','Watershed'};
    BW_allMethods=cell(1,length(options));
    figPy=cell(1,length(options));
    for i=1:length(options)
        method=options{i};
        result=modulePython.binarize_stripe_image(image,method);
        % Convert to MATLAB arrays
        BW = double(result);
        figPy{i}=figure; imagesc(BW), axis equal, xlim tight, title(sprintf("METHOD BINARIZATION: %s",method),"Fontsize",16)
        BW_allMethods{i}=BW;
    end
    choice=getValidAnswer('Which Binarization method do you choose?',"",options);
    IO_Image=BW_allMethods{choice};
    binarizationMethod=sprintf("Python Binarization Method %s",options{choice});
    close(ftmp), clear ftmp
    for i=1:length(options)
        if isgraphics(figPy{i})   % <- figure still open & valid
            close(figPy{i})
        end
    end
end

