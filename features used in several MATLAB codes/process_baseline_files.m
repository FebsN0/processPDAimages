function process_baseline_files(folder_path)
    % Trova tutti i file baseline.txt nelle sottocartelle
    % una caratteristica di dir e' crea uno struct e tra i vari fields c'e anche l'intera path folder
    clc, close all
    f1=figure; hold on, grid on, grid minor
    objInSecondMonitor(1,f1)
    xlabel('Time [min]','FontSize',20), ylabel('Baseline [nN]','FontSize',20)

    filesJPK = dir(fullfile(folder_path, '**', '*.jpk'));
    filesBaseline = dir(fullfile(folder_path, '**', 'baseline.txt'));
    % find the main folder of single experiment
    pathFilesBaseline = unique({filesBaseline.folder}');
    pathFilesJPK = unique({filesJPK.folder}');
    [a,b]=fileparts(pathFilesJPK);
    % in case there is the dir HoverMode_ON, remove to take only the name of upper folder
    pathFilesJPK(strcmp(b,'HoverMode_ON'))=a(strcmp(b,'HoverMode_ON')); 
    pathFilesJPK(strcmp(b,'HoverMode_OFF'))=a(strcmp(b,'HoverMode_OFF')); 
    % find the idx dirs in which there is baseline.txt
    idxBaselineDir = ismember(pathFilesJPK,pathFilesBaseline);
 
    j=1;
    % Itera su ogni file trovato
    for i = 1:length(idxBaselineDir)
        fprintf('\nCurrent folder:\n\t%s\n\n',pathFilesJPK{i});
        if idxBaselineDir(i)
            file_path = fullfile(filesBaseline(j).folder, filesBaseline(j).name);
            % extract metadata to check the unit of baseline
            jpkpath = dir(fullfile(filesBaseline(j).folder, '**', '*.jpk'));
            jpkfile = fullfile(jpkpath(1).folder, jpkpath(1).name);
            [~,metadata,~]=A1_open_JPK(jpkfile,'metadataExtractionOnly','Yes');
            process_baselineFile(file_path,metadata,i)            
            j=j+1;
        else
            if i==1
                [prevSn,prevKn]=process_jpkFiles(pathFilesJPK{i},i);
            else
                process_jpkFiles(pathFilesJPK{i},i,prevSn,prevKn)
            end
        end
        
    end
    legend('show','FontSize',12,'location','bestout')
end

function process_baselineFile(file_path,metadata,n)
    
    % Leggi il contenuto del file
    file_content = fileread(file_path);
    lines = splitlines(file_content);
    
    % Variabili di interesse
    ScanIndex = [];
    Setpoint = [];
    BaselineStart = [];
    BaselineEnd = [];
    flagEnd=false;
    flagEndExp=false;
    % Ciclo per analizzare ogni linea
    i = 1;
    while i <= length(lines)
        line = strtrim(lines{i});              
        % Salta righe vuote o non rilevanti
        if isempty(line) || startsWith(line, '# Start time') || startsWith(line, '# Scan output directory') || ...
                startsWith(line,'# ScanSizeFast (X)') || startsWith(line,'# ScanSizeSlow (Y)') || ...
                startsWith(line,'# End time') || startsWith(line,'# Number of sections')
            i = i + 1;
            continue;
        % Rileva l'header
        elseif contains(line, '# ScanIndex	Setpoint	BaselineStart	BaselineEnd	XOffset	YOffset') || ...
                contains(line, '# ScanIndex	Setpoint	BaselineStart	XOffset	YOffset')
            % Passa alla riga successiva con i dati
            i = i + 1;
            while i <= length(lines) && ~isempty(strtrim(lines{i})) && ~startsWith(lines{i}, '#')
                % Leggi i dati dalla linea corrente
                data = textscan(lines{i}, '%f%f%f%f%f%f', 'Delimiter', '\t');
                ScanIndex(end + 1) = data{1};
                Setpoint(end + 1) = data{2};
                BaselineStart(end + 1) = data{3};
                if ~contains(line, '# ScanIndex	Setpoint	BaselineStart	XOffset	YOffset')
                    BaselineEnd_current = data{4}; % Salva l'ultimo valore
                else
                    BaselineEnd_current=[];
                end
                i = i + 1;
            end
            flagEnd=true;
            BaselineEnd = BaselineEnd_current;
        end
        % process the end experiment

        if startsWith(line, '# Total time (min)')
            % once reached this point ==> end single experiment

            % [-+]?     => [] define char set (in this case - and +
            %           => ? define optional char (it may appear one or none)
            % Example: "123", "+123", "-123".
            % \d+       => \d represent any single number but with => more numbers are accepted
            % (\.\d+)?  => () groups what's inside as single unit
            %           => \. == dot char
            %           ===> entire unit may be optional (?)
            % Example: "123.456", "123" ok
            totalTime = str2double(regexp(line, '[-+]?\d+(\.\d+)?', 'match'));
            flagEndExp=true;
            flagEnd = false;
        end
        if flagEnd && (startsWith(line, '# Start time') || i==length(lines))

            timeSingleSectionMin=(metadata.y_scan_pixels)/(metadata.Scan_Rate_Hz)/60;
            totalTime= ScanIndex(end)*timeSingleSectionMin;
            flagEnd = false;
            flagEndExp=true;
        end
        if flagEndExp
            tolerance = 1e-8;
            are_close = abs(BaselineStart(1) - metadata.Baseline_N) <= tolerance;
            % in case baseline from txt file is expressed in Volt ==> the number will significantly differ
            % if so, convert to Newton unit
            if ~are_close
                fprintf('\nBaseline from txt file:\t%.4e\nBaseline from jpk file:\t%.4e \n\n', BaselineStart(1), Baseline_N);
                answer=input('convert baseline from txt file into proper unit? [y|n] ','s');
                if strcmp(answer,'y')
                    factor=metadata.Vertical_Sn*metadata.Vertical_kn;
                    Setpoint=Setpoint*factor;
                    BaselineStart=BaselineStart*factor;
                    BaselineEnd=BaselineEnd*factor;
                end
            end
                
            baselineArray = [BaselineStart,BaselineEnd];
            % in case of missing end baseline measurement, exclude last time
            if isempty(BaselineEnd)
                totalTime = totalTime-totalTime/length(baselineArray);
            end
            timeArray = linspace(0,totalTime,length(baselineArray));           
            % Newton ==> nanoNewton
            Setpoint = Setpoint*1e9; baselineArray =baselineArray*1e9;
            
            makePlot(Setpoint,timeArray,baselineArray,n)
        end
        i = i + 1;
    end
end


function varargout =process_jpkFiles(file_path,n,prev_vSn,prev_vKn)
    filesJPK = dir(fullfile(file_path, '**', '*.jpk'));
    allBaseline=zeros(length(filesJPK),1);
    timeSingleSectionMin=zeros(length(filesJPK),1);
    Setpoint=zeros(length(filesJPK),1);
    prevV_flag=false;

    for i=1:length(filesJPK)
        [~,metadata,~]=A1_open_JPK(fullfile(filesJPK(i).folder, filesJPK(i).name),'metadataExtractionOnly','Yes');
        allBaseline(i)=metadata.Baseline_N;    % Newton
        % one line = one pixel ==> y Hz = x sec ==> one line takes x sec
        timeSingleSectionMin(i)=(metadata.y_scan_pixels)/(metadata.Scan_Rate_Hz)/60;
        % for security, take the volt and then convert
        Setpoint(i)=metadata.SetP_V;
        vSn=metadata.Vertical_Sn;
        vKn=metadata.Vertical_kn;
        if i== 1
            fprintf('\tVertical_Sn: %d\n\tVertical_kn: %d\n',vSn,vKn)
        end
        % check first if the values makes sense
        if vSn > 1e-6 || vKn > 0.9
            if ~prevV_flag
                v=input(sprintf(['Something odd happened in the current data:\n\tVertical_Sn: %d\n\tVertical_kn: %d\n'...
                    'put manually a value/use the previous if already entered? [0|1] '],vSn,vKn));
                if v
                    corr_vSn = input('Vertical_Sn (already 1e-9): ');
                    corr_vKn = input('Vertical_kn: ');
                    prevV_flag=true;
                end
            end
            % apply the correction
            if prevV_flag
                metadata.Vertical_Sn=corr_vSn;
                metadata.Vertical_kn=corr_vKn;               
            end
        end
        % if first section has wrong values
        if n == 1 && i == 1
            v=input('Change the current kn and Sn and use them as reference for all other scannings? [0|1] : ');
            if v
                prev_vSn = input('Vertical_Sn (already 1e-9): ');
                prev_vSn=prev_vSn*1e-9;
                prev_vKn = input('Vertical_kn: ');
            else
                prev_vSn= metadata.Vertical_Sn;
                prev_vKn= metadata.Vertical_kn;
            end
            varargout{1}=prev_vSn;
            varargout{2}=prev_vKn;
        % when it is not the first scan image, check the vertical parameters
        else
            if vSn ~= prev_vSn || vKn ~= prev_vKn
                metadata.Vertical_Sn=prev_vSn;
                metadata.Vertical_kn=prev_vKn;
                warning(['the original values are not the same, changed\n' ...
                    '   original\t==> corrected\nSn : %.4f\t %0.4f\nKn : %.4f\t\t %0.4f\n'],vSn*1e9,prev_vSn*1e9,vKn,prev_vKn)
            end
        end

        factor=prev_vKn*prev_vSn;
        Setpoint(i)=Setpoint(i)*factor;
        allBaseline(i)=metadata.Baseline_V*factor;


    end
    timeArray = linspace(0,sum(timeSingleSectionMin)-timeSingleSectionMin(end),length(Setpoint));
    if ~prevV_flag
        Setpoint = Setpoint*1e9; allBaseline =allBaseline*1e9;
    end
    makePlot(Setpoint,timeArray,allBaseline,n)

end

function makePlot(Setpoint,timeArray,baselineArray,n)
    Setpoint= round(Setpoint,2);
    if isscalar(unique(Setpoint))
        Setpoint=unique(Setpoint);
    end

    % Usa sprintf per generare la stringa
    formattedSetpoint = sprintf('%.2f  ', Setpoint);
    formattedSetpoint = regexprep(formattedSetpoint, '\.00', ''); % Rimuove ".00" quando presente
    % Rimuove lo spazio extra alla fine
    formattedSetpoint = strtrim(formattedSetpoint);
    % Aggiungi il prefisso "Setpoint: "
    name = ['Setpoint: ', formattedSetpoint];

    plot(timeArray,baselineArray,'-*',"Color",globalColor(n),'LineWidth',2,'MarkerSize',10,'DisplayName',name)
    % for j=1:length(baselineArray)    
    %     h2=plot(timeArray(j),baselineArray(j),'-*',"Color",colors{j},'LineWidth',2,'MarkerSize',10);
    %     h2.Annotation.LegendInformation.IconDisplayStyle = 'off'; % Escludi dalla legenda
    % end
end

% pseudo global variable
function col = globalColor(n)
    colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k','#FF00FF','#00FF00','#0000FF','#FF0000'};
    col=colors{n};
end