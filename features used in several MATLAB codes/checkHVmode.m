function HVmodes=checkHVmode(mainPath)
    % clarify the mode of the HoverMode directories. HoverMode directories contains .jpk files
    list=dir(mainPath); listDirName={list.name};
    patternON="HoverMode.*ON"; patternOFF="HoverMode.*OFF";         % .* means any characters. not only . because it means any SINGLE char but it doesnt consider its absence
    dirONidx=cellfun(@(x) ~isempty(regexpi(x, patternON, 'once')),listDirName);
    hasON=any(dirONidx);
    dirON=listDirName(dirONidx);
    dirOFFidx=cellfun(@(x) ~isempty(regexpi(x, patternOFF, 'once')),listDirName);
    hasOFF=any(dirOFFidx);  
    dirOFF=listDirName(dirOFFidx);
    % prepare the struct to clarify which directory is available and which one is to be considered main data and eventually friction data
    HVmodes.ON=hasON; HVmodes.OFF=hasOFF;
    HVmodes.dirON=dirON; HVmodes.dirOFF=dirOFF;    
    if hasON && hasOFF
        question=sprintf("There are both HoverModes directories in the selected scan (HoverModeON and HoverModeOFF).\nDecide which one is the dir which contains the data to extract force-fluorescence correlation curve.");
        opts={"HoverModeON data as main 'normal' scan from which extract force-fluorescence curve (old approach, fc method found to be inaccurate),\nwhile HoverMode OFF as data from which get the friction coefficient",...
            "Consider only HoverModeOFF data as main 'normal' scan and ignore HoverModeON."};
        mainData={"ON","OFF"};
        frictionData={"OFF","none"};
    elseif ~hasON && hasOFF
        question=sprintf("There is only HoverModeOFF in the selected scan.\nDecide how to consider HoverModeOFF data.");
        opts={"Use it as main 'normal' scan from which extract force-fluorescence curve (new approach, indipendent from fc method)",...
            "Use it as data from which get the friction coefficient"};
        mainData={"OFF","none"};
        frictionData={"none","OFF"};
    elseif hasON && ~hasOFF
        question=sprintf("There is only HoverModeON in the selected scan.\nDecide how to consider HoverModeON data.");
        opts={"Use it as main 'normal' scan from which extract force-fluorescence curve",...
            "Use it as data from which get the friction coefficient (Highly not recommended. Code not developed for it!"};     
        mainData={"ON","error"};
        frictionData={"none","none"};
    else
        error('No HoverMode directories found in the selected scan!')
    end
    answ=getValidAnswer(question,"",opts);
    if strcmp(mainData{answ},"error")
        error("This possibility is currently not developed. Choose another option or get new data!")
    end
    HVmodes.mainData=mainData{answ};
    HVmodes.frictionData=frictionData{answ};
    clear answ opts question dirO* has* list* patternO* mainData frictionData
end