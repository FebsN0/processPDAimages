clc, clear, close
format shortE

%% Part 1 : upload and order the trace, retrace and height cross section .txt files from the JPK software.
%  IMPORTANT: upload only those files using the same SETPOINT and speed scan rate!

%select the files
[fileNames, filePathData] = uigetfile('*.cross', 'Select .cross files containing trace, retrace and height information', 'MultiSelect', 'on');
unorderedData={};

%In case of only one Height Data
question= ['Choose one of the possible options to process Height/Trace/Retrace Data:\n' ...
    ' (0) Use only one Height Data for every Trace/Retrace Data.\n' ...
    ' (1) Use the Height Data for each Trace\Retrace Data.\n'];
possibleAnswers= {'0','1'};
singleHeightData = str2double(getValidAnswer(question,possibleAnswers));

% save the uploaded but unordered data due to user-dependent file naming
% if only one Height Data is selected, take only the first. Save time by
% avoiding use importdata function
firstHeight=true;
j=1;
for i = 1:length(fileNames)
    currentFile = fullfile(filePathData, fileNames{i});
    unorderedData_tmp = importdata(currentFile);
    if contains(unorderedData_tmp.textdata(2),'Height') && ~singleHeightData
        if firstHeight==true
            unorderedData{j} = unorderedData_tmp;
            firstHeight=false;
            j=j+1;
        else
            % skip to the next iteration if already saved a Height Data
            continue
        end
    else
        unorderedData{j} = importdata(currentFile);
        j=j+1;
    end
end

orderedData = {};
% Order the data based on the type and coordinates of single grate lines
%   1st col       2nd col         3rd col
%   TRACE         RETRACE         HEIGHT
idx=1;
for i = 1:length(unorderedData)
    % search Trace data, then search the relative Retrace data using the
    % same coordinates of the line cross section
    if contains(unorderedData{i}.textdata(2),'Lateral Deflection (Trace)')
        orderedData{idx,1}=unorderedData{i}.data;               % Trace data
        for j = 1:length(unorderedData)
            % check that the coordinates are the same
            if strcmpi(unorderedData{i}.textdata{4},unorderedData{j}.textdata{4})
                if contains(unorderedData{j}.textdata(2),'Lateral Deflection (Retrace)')
                    orderedData{idx,2}=unorderedData{j}.data;   % Retrace data
                elseif contains(unorderedData{j}.textdata(2),'Height')
                    orderedData{idx,3}=unorderedData{j}.data;   % Height data
                end
            end
        end
        idx = idx + 1;
    end
end

% check missing trace/retrace/height data in the OrderedData var.
% in case of only one Height Data option, copy the first available one,
% otherwise, give error.
copy=false;
for i=1:size(orderedData,1)
    for j=1:3
        if ~any(orderedData{i,j})
            if j==3 && ~singleHeightData
                if i==1, copy=true; end
            else
                error('\nERROR: The matrix OrderedData(%d,%d) has missing data! Check the coordinates in the .cross-files and re-run the code!\n',i,j)
            end
        elseif j==3 && copy
            orderedData{1,3}=orderedData{i,3};
            copy=false;
        end
    end
end    

%check if the size of each data is correct
clear i idx j unorderedData unorderedData_tmp firstHeight copy

%move the figure in another monitor in a maximized windows if second monitor is allowed
question= 'Do you want to show the figures into a maximized window in a second monitor? [Y/N]: ';
possibleAnswers= {'y','n'};
secondMonitor = getValidAnswer(question,possibleAnswers);


%% Part 2 : Plotting Trace Retrace and Height of every data
%  (if you want still to plot more than 9 single grates, add a new custom color palette for each new grates)
question='Do you want to see overlapped trace, retrace and height of every provided data? [Y/N]: ';
plotEverything = getValidAnswer(question,possibleAnswers);

if strcmpi(plotEverything,'y') && size(orderedData, 1) < 10
    if strcmpi(secondMonitor,'y'), figure('units','normalized','outerposition',[-2 0 1 1],'WindowState','maximized'); else, figure; end
    hold on
    customColorPalette = [
        1 0 0   % red
        0 1 0;  % green
        0 0 1;  % blue
        1 0 1;  % magenta
        0 1 1;  % cyan
        1 1 0;  % yellow
        0 0 0;  % black
        0.9290 0.6940 0.1250;
        0.6350 0.0780 0.1840;
        ]; 
    
    %plot trace, retrace and height for each data
    p_heightTraceRetrace=zeros(size(orderedData, 1),3);
    displayNames=   {'Height';'Trace';'Retrace'};
    lineStyles=     {'-';'-.';':'};
    firstHeight=true;
    for i = 1:size(orderedData, 1)
        for j=1:3
            if j == 3 %height
                yyaxis right
            else
                yyaxis left
            end
            if ~singleHeightData && j == 3
                if firstHeight
                    firstHeight=false;
                else
                    continue
                end
            end
            x_data = orderedData{i, j}(:, 1);
            y_data = orderedData{i, j}(:, 2);
            p_heightTraceRetrace(i,j)=plot(x_data, y_data,'LineWidth',2,'LineStyle',lineStyles{j},'DisplayName',displayNames{j},'Color',customColorPalette(i,:),'Marker','none');

        end
    end
    yyaxis right,   ylabel('Height [\mum]'),                    ylim([-2E-7 1E-5])
    yyaxis left,    ylabel('lateral deflection signal [V]'),    ylim([-7 3])
    xlim tight,     xlabel('offset [\mum]');
    grid on
    legend([p_heightTraceRetrace(1,1),p_heightTraceRetrace(1,2),p_heightTraceRetrace(1,3)]);
    hold off;
    title(append('Trace, Retrace and Height from ', string(size(orderedData, 1)), ' cross-section files'), 'FontSize',16)
    clear customColorPalette i j x_data y_data p_heightTraceRetrace displayNames lineStyles
end
clear question plotEverything possibleAnswers firstHeight
%% PART 3:

% Enter the SETPOINT from which the data is obtained. Check on JPK program
clc
L = input("Enter the Setpoint value [nN] applied from which the uploaded data (Trace/Retrace/Height) originated: ");

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Let's calculate the Adhesion Force
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% many adhesion force curves exists but the information may be from the txt files or manually entered through JPK software.
% 1) MANUAL WAY: enter manually the value until finished 
% 2) IMPORT WAY: import txt data and process them

question= ['\nChoose the Adhesion Force value modality:\n' ...
    '1) [manual] : Enter manually the single values for each force curve.\n' ...
    '2) [import] : Import txt data files\n'];
possibleAnswers= {'manual','import'};   % 1 = manual | 0 = import
mode1=getValidAnswer(question,possibleAnswers);

if strcmpi(mode1,'manual')
% manual adhesion force of each force curve
    values = [];
    while true
        v = input('Enter the Adhesion Force value [nN]. Digit ''E'' to finish. ','s');
        if strcmpi(v,'E')
            break;
        else
            v_num = str2double(v);
            if ~isnan(v_num),   values = [values, v_num];
            else,               disp('Invalid input! Please enter a numeric value or ''E'' to finish. ');
            end
        end
    end
    % already expressed in nN
    F_adhesion = abs(mean(values));
    F_adhesion_std = std(values);
    numberForceCurves=length(v);
    clear v_num v
else
% import force curves
    [fileNames, filePathFC] = uigetfile({'*.txt'}, 'Select the force curves .txt files', filePathData, 'MultiSelect', 'on');
    numberForceCurves=length(fileNames);
    question= 'Is the force curve obtained in acqueous or air condition? [air | aqueous] : ';
    possibleAnswers= {'aqueous','air'};   % 1 = aqueous | 0 = air
    mode2=getValidAnswer(question,possibleAnswers);
    % extract and clean from NaN values among any the force curves
    for i = 1:length(fileNames)
        currentFile = fullfile(filePathFC, fileNames{i});
        rawForceCurves = readtable(currentFile);
        nan_rows = any(isnan(rawForceCurves{:,1}), 2);
        cleaned_data = rawForceCurves(~nan_rows, :); 
        % Shift toward x axis = 0 using the first value
        shifted_cleaned_data = cleaned_data{:,2}-cleaned_data{1,2};

        % min function can be used without problems (maybe..) to find the
        % adhesion force
        if strcmpi(mode2,'air')
            values(i)= min(shifted_cleaned_data);
        else
        % aqueous
            % IMPORTANT NOTE: in acqueos condition, the force adhesion is very
            % small and the vibration can be even higher. So min function
            % lead to wrong force adhesion value.
            % To overcome this issue, in theory the adhesion value should be very
            % close to zero.
            % To check if this happens, an user-guided selection will follow to
            % find the force adhesion for any force curve
            if secondMonitor, figure('units','normalized','outerposition',[-2 0 1 1],'WindowState','maximized'); else, figure; end
            xlabel('Height (m)');
            ylabel('Vertical Deflection (N)');
            title('Select two point to create a range of interest in which the force adhesion is extracted','FontSize',16)
            hold on
            % extract data. Find the maximum point to separate
            % trace and retrace. Force adhesion is obtained from
            % retrace curve
            height = cleaned_data{:,1};
            force  = shifted_cleaned_data;
            [~,ixMax]=max(force);
            hf1= plot(height(1:ixMax),force(1:ixMax),'b','DisplayName','Trace');
            hf2= plot(height(ixMax+1:end),force(ixMax+1:end),'r','DisplayName','Retrace');
            legend([hf1,hf2],'Autoupdate','off')
            % height = x | force = y
            while true
                if exist('sf_real', 'var') && ishandle(sf_real)
                    delete(sf_real), delete(hp), delete(sf_idx), delete(point_selected)
                end
                closest_indices= selectRangeGInput(2,1,height(ixMax+1:end),force(ixMax+1:end));
                closest_indices=closest_indices+ixMax;
                % Plot the points closer to the manually selected points
                %delete(point_selected)
                x_selected = height(closest_indices); y_selected = force(closest_indices);
                sf_idx=scatter(x_selected, y_selected, 200,'pentagram','filled', 'MarkerFaceColor', 'green','DisplayName','Closest selected points');
     
                % Create a patch to highlight the selected x-axis range
                y_limits = ylim;
                x_patch = [x_selected(1), x_selected(2), x_selected(2), x_selected(1)];
                y_patch = [y_limits(1), y_limits(1), y_limits(2), y_limits(2)];
                hp=patch(x_patch, y_patch, 'blue', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
                                    
                % find the adhesion force and plot
                [ ~ , ix ] = min([force(min(closest_indices):max(closest_indices))]);
                ix1=min(closest_indices)+ix-1;
                sf_real=scatter(height(ix1),force(ix1), 200,'pentagram','filled', 'MarkerFaceColor', 'k','DisplayName','Adhesion Force');       
                legend([hf1, hf2 ,sf_idx, sf_real])
                fprintf('Adhesion Force is = %.3f nN\n', abs(force(ix1))*1e9)
                
                question= 'Is the Adhesion Force ok? [y/n] ';
                possibleAnswers= {'y','n'};   % 1 = y | 0 = n
                completed=getValidAnswer(question,possibleAnswers);
                close
                if strcmpi(completed,'y')
                    values(i)=force(ix1);
                    break
                end
            end
        end
    end
    % conver N -> nN
    F_adhesion = abs(mean(values))*1e9;
    F_adhesion_std = std(values)*1e9;
end

%express Force Adhesion and Setpoint in nN
clc
fprintf('\nAdhesion Force (mean+std) on %d force curves = %.3g \x00B1 %.2g nN \n\n',numberForceCurves, F_adhesion,F_adhesion_std)
clear numberForceCurves text question completed values possibleAnswers forceCurvecompleted distances currentFile fileNames filePathFC i shifted_cleaned_data cleaned_data nan_rows rawForceCurves mode* j closest_indices force* height* hf* ix* hp pointSelected_all range_selected sf_* x* y*

%% Part 4
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Let's calculate the theta angle, W and Theta
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% subpart 1: calculate the theta angle
% subpart 2;:
% subpart 3: select the range of each slope and flat sections ==> calculate
%            Delta e W

% To guide the user, a reference picture is showed during the selection
% of points to establish a range, while a semi-transparent rectangle
% appears


% Read the two reference images to select the range of left/right slopes
% and flat section.
referenceImage1 = imread('referencePicLateralDeflectionCalibration_1.png');
referenceImage2 = imread('referencePicLateralDeflectionCalibration_2.png');
if secondMonitor, figure('units','normalized','outerposition',[-2 0 1 1],'WindowState','maximized'); else, figure; end


ax1=axes('Position', [0.05, 0.5, 0.47, 0.47]); % subplot 1
imshow(referenceImage1,'Border','tight');
ax2=axes('Position', [0.5, 0.5, 0.47, 0.47]); % subplot 2
imshow(referenceImage2,'Border','tight');

% init array where saving the:
% - mu friction (slope) coefficients
% - alpha calibration factor
% - mu friction (flat) coefficients

realMuCoefficient=[];
realAlphaCoefficient=[];
realMuFlatCoefficient=[];
m=1;

% enter manually the theta OR
% use the theta of the first height only OR
% of all data
question=['\nChoose one of the following options:\n' ...
    ' (1) Enter manually the theta angle\n' ...
    ' (2) Extract theta angle from the first Height data and use it for the rest of the data\n' ...
    ' (3) Extract theta angle for each Height data\n'];
possibleAnswers={'1','2','3'};
processTheta=getValidAnswer(question,possibleAnswers);
if processTheta == '1'
    theta = input("Enter the theta angle [°,degree]: ");
else
    if processTheta == '3' && ~singleHeightData
        processTheta = '2';
        fprintf('\nThere is only one Height Data ==> switched to (2) automatically\n\n')
    end
    firstTheta= false;
end

firstHeight=true;
for i = 1:size(orderedData, 1)
    text=append('DATA #',string(i));
    sgtitle(text, 'FontSize', 20, 'color','red');

    % j=1 Trace_x|y
    % j=2 Retrace_x|y
    % j=3 Height_x|y
    for j=1:3
        if j==3 && ~singleHeightData
            if firstHeight && ~singleHeightData
                firstHeight=false;
            else
                continue
            end
        end
        x_data{j} = orderedData{i, j}(:, 1);    
        y_data{j} = orderedData{i, j}(:, 2);
    end
        
    if exist('h', 'var') && ishandle(h)
        delete(h);
    end
    if exist('r', 'var') && ishandle(r)
        delete(r);
    end
    %h represent entire third subplot
    h=subplot(2,2,[3 4]);
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % In this part, angle theta is calculated from the Height data
    
    % plot the Height data
    hold on
    hh=plot(x_data{3}, y_data{3},'k-','DisplayName','Height','LineWidth',2);
    ylabel('Height [\mum]');
    xlabel('offset [\mum]');
    grid minor
    legend(hh,'AutoUpdate','off');
    
    % select manually the points on the plots to calculate the theta.
    % Sometimes the slope may be disaligned, therefore the code asks you if
    % the theta is ok by checking the red slope on the plot
    if processTheta=='2' || processTheta=='3'
        % OPTION 3: extract the first theta angle. If processTheta=2, then
        % do it only once and break the while loop, otherwise for each 
        % Height data 
        if firstTheta== false
            while true
                title('Click on the plot to select the coordinates to calculate theta angle','FontSize',16);
                fprintf('Click on the plot to select the coordinates to calculate theta angle\n')
                % calc theta angle specifing the points manually
                closest_indices=selectRangeGInput(2,2,x_data{3},y_data{3});
                % plot the real coordinates from the manually selected points
                x = x_data{3}(closest_indices); y = y_data{3}(closest_indices);
                stheta_real=scatter(x, y, 200,'pentagram','filled', 'MarkerFaceColor', 'green','DisplayName','real idx');
                
                % calculate theta from real points
                theta = atand(((y(2)-y(1))/(x(2)-x(1))));
        
                slope= tand(theta);
                x_range= linspace(min(x),max(x),100); y_range= slope*(x_range-x(1)) + y(1);
                line_theta=plot(x_range, y_range,'r--','LineWidth',2,'DisplayName','slope');
                legend([hh,stheta_real,line_theta])
                theta_all(i)=abs(theta);
                fprintf('%s = %.2f\n', char(952), theta_all(i));
                question= 'Is the calculated theta ok? [Y/N]: ';
                possibleAnswers= {'y','n'};   % 1 = y | 0 = n
                completed=getValidAnswer(question,possibleAnswers);
                delete(stheta_real), delete(line_theta)
                clc
                if strcmpi(completed,'y')
                    if processTheta=='2' || ~singleHeightData
                        firstTheta=true;
                    end
                    break
                end
            end
        end
    end

    clear stheta_selected stheta_real line_theta x_range slope y_range x y closest_indices distances ix j pointSelected_all selectionThetaCompleted x_selected y_selected
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % plot Trace and Retrace curves
    yyaxis right
    ht=plot(x_data{1}, y_data{1},'r-','DisplayName','Trace','LineWidth',2);
    hr=plot(x_data{2}, y_data{2},'b-','DisplayName','Retrace','LineWidth',2);
    ylabel('lateral deflection signal [V]');
    
    legend([hh,ht,hr],'AutoUpdate','off')
    xlim padded
    ylim padded
    
    % find the closest indexes for each semi trasparent rectangle box.
    % Needeed to calculate the Delta and W of left and right slope and flat
    nameSlopes = {'W^{left slope} in TRACE curve'; 'W^{flat} in TRACE curve'; 'W^{right slope} in TRACE curve';
                  'W^{left slope} in RETRACE curve'; 'W^{flat} in RETRACE curve'; 'W^{right slope} in RETRACE curve'};
    positionRect = [290 200 105 60;
                    420 355 445 25;
                    890 390 105 50;
                    290 360 105 60;
                    420 385 445 25;
                    895 630 100 50];
    while true
        closest_indices = [];
        for j= 1:6
            title(['Click on the plot to select the ', num2str(j),'th point set for', nameSlopes{j}],'FontSize',16);
            %add semi trasparent rectangle for left/right slope or flat
            switch j
                case {1,2,4}       % X trace points
                    ax=ax1;
                case {3,5,6}    % X Retrace points
                    ax=ax2;
            end
            r=rectangle(ax,'Position', positionRect(j,:), 'FaceColor', [1 0 0], 'EdgeColor', 'none', 'FaceAlpha', 0.5,'Curvature',0.5);
            closest_indices = [closest_indices, selectRangeGInput(2,1,x_data{ceil(j/3)},y_data{ceil(j/3)})];
            delete(r)
        end
     
        st=scatter(x_data{1}(closest_indices(:,1:3)), y_data{1}(closest_indices(:,1:3)), 200,'pentagram','filled', 'MarkerFaceColor', 'magenta','DisplayName','real idx');
        sr=scatter(x_data{2}(closest_indices(:,4:6)), y_data{2}(closest_indices(:,4:6)),200,'pentagram','filled', 'MarkerFaceColor', 'magenta','DisplayName','real indexes');
        legend([ht,hr,hh,st(1)])

        
        question= 'Are real indexes ok? [Y/N]: ';
        possibleAnswers= {'y','n'};   % 1 = y | 0 = n
        completed=getValidAnswer(question,possibleAnswers);
        delete(sr), delete(st)
        if strcmpi(completed,'y')
            break
        end
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    clear ix pointSelected_all r selectionPointCompleted sr ss st x_selected y_selected positionRect nameSlopes
    title('')
    
    %build two arrays of mean and std W values using the idx, then plot
    %{
%%%%%   CLOSEST INDEXES                         LATERAL DEFLETION AVG
1,2     IDX left slope    TRACE                1  latDefl left slope   AVG  TRACE  
3,4     IDX flat          TRACE                2  latDefl flat         AVG  TRACE           1 Delta Left slope      |     1 W Left slope
5,6     IDX right slope   TRACE        ==>     3  latDefl right slope  AVG  TRACE       ==> 2 Delta flat            |     2 W flat
7,8     IDX left slope    RETRACE              4  latDefl left slope   AVGRETRACE           3 Delta Right slope     |     3 W Right slope
9,10    IDX flat          RETRACE              5  latDefl flat         AVG  RETRACE
11,12   IDX right slope   RETRACE              6  latDefl right slope  AVG  RETRACE
    %}
    
    latDefl_avg = zeros(6,1);
    latDefl_std = zeros(6,1);
    for j=1:2:11
        %calc mean and standard deviation
        switch j
            case {1,3,5}
                % trace
                n=1;
            case {7,9,11}
                % retrace
                n=2;
        end
        latDefl_avg((j+1)/2) = mean(y_data{n}(closest_indices(j):closest_indices(j+1)));
        latDefl_std((j+1)/2) = std(y_data{n}(closest_indices(j):closest_indices(j+1)));
        %plot the mean and std
        plot([x_data{n}(closest_indices(j)),x_data{n}(closest_indices(j+1))], [latDefl_avg((j+1)/2), latDefl_avg((j+1)/2)],'--', 'Color', 'g', 'LineWidth', 2);
        errorbar(mean(x_data{n}(closest_indices(j):(closest_indices(j+1)))), latDefl_avg((j+1)/2), latDefl_std((j+1)/2), 'k', 'LineStyle', 'none', 'Marker','none','LineWidth', 1.5);
    end

    %calculate Delta and W for the slope and flat parts
    Delta = zeros(3,1);
    W = zeros(3,1);
    deltaPlot = zeros(3,1);
    for j=1:3
        Delta(j) = mean([latDefl_avg(j),latDefl_avg(j+3)]);
        %since Delta is the average between the two lateral defletions,
        %doesn't matter which latDefl take (if part of trace or retrace)
        W(j) = abs(latDefl_avg(j)- Delta(j));
        %plot Delta
        x_max = max(closest_indices((j*2)-1),closest_indices((j*2)+5));
        x_min = min(closest_indices(j*2),closest_indices((j*2)+6));
        deltaPlot(j)=plot([x_data{n}(x_max),x_data{n}(x_min)], [Delta(j), Delta(j)],'--', 'Color', 'k', 'LineWidth', 2,'DisplayName','\Delta');
    end
    legend([ht,hr,hh,deltaPlot(1)])
    % make positive the values. Downhill Delta is likely to be negative
    Delta=abs(Delta);
    W=abs(W);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % At this point, all the experimental variables for a dataset are known. Let's calculate the calibration factor!!!.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
    
    % SOLVE THE FUNCTION X OBTAIN CALIBRATION FACTOR
    % variables: Delta W L Fa (Force Adhesion) mu
    %NOTE: the equation is done twice: one for the left slope and one for
    %the right slope! Once the calibration factor are calculated, check if
    %they have Im part. If so, rejection!


%{
%%%%% nameVariables              Delta                     W
                        1 Delta Left slope      |     1 W Left slope
                        2 Delta flat            |     2 W flat
                        3 Delta Right slope     |     3 W Right slope
%}

    % calc the coefficients separately the LEFT slope + FLAT then RIGHT slope + FLAT
    nameSlopes = {'Left Slope'; 'Flat'; 'Right Slope'};
    clc
    %absolute value, since Delta1-Delta2 to cancel effects
    % Delta=abs(Delta);
    % W=abs(W);
    if processTheta=='2'
        theta=theta_all(1);
    elseif processTheta=='3' && singleHeightData
        theta=theta_all(i);
    end
    
    MuCoefficient=[];
    AlphaCoefficient=[];
    MuFlatCoefficient=[];
    % j=1 process Left slope     j=3 process Right slope
    for j=1:2:3
        fprintf("\n\t\t\t\t\t%%%%%%%%%%%%%%%%%%%%%%%%\tProcess the %s\t%%%%%%%%%%%%%%%%%%%%%%%%\n",nameSlopes{j})
        [MuCoefficient,MuFlatCoefficient,AlphaCoefficient]=processCoefficcients(theta,L,F_adhesion,Delta(j),Delta(2),W(j),W(2));
        if any(MuCoefficient)
            realMuCoefficient(m)=MuCoefficient;
            realMuFlatCoefficient(m)=MuFlatCoefficient;
            realAlphaCoefficient(m)=AlphaCoefficient;
            m=m+1;
        end
        delta_W_rate(i,(j+1)/2)=(Delta(j)-Delta(2))/W(j);
    end
    
    question= '\n\nClick any button to continue to the next data...';
    possibleAnswers= {''};
    getValidAnswer(question,possibleAnswers);
    clc
end

%% extract final results
close
clear firstTheta ans secondMonitor ax MuCoefficient AlphaCoefficient MuFlatCoefficient text question possibleAnswers completed positionRect ax1 ax2 closest_indices data deltaPlot h* i j latDefl_* n nameSlopes referenceImage* x* y*
clc

      
filename = "resultsCalibration"+string(L)+'nN';
fullfilen=fullfile(filePathData, filename);
if processTheta=="2" || processTheta == "3"; theta=mean(theta_all); end
save(fullfilen,"L","F_adhesion","orderedData","realMuFlatCoefficient","realMuCoefficient","realAlphaCoefficient","theta","delta_W_rate")

fullfilen = fullfilen+".txt";
fileID = fopen(fullfilen, 'w');
% %save data on Command Window and in txt file
text='Ratio (DeltaSlope-DeltaFlat) / WSlope:\n';
fprintf(fileID,text);
text='\tLEFT\t\tRIGHT\n';
fprintf(fileID,text);
for i=1:size(orderedData,1)
    text='DATA %d\t %0.3g\t\t%0.3g\n\n';
    fprintf(fileID,text, [i,delta_W_rate(i,1),delta_W_rate(i,2)]);
end

text='Total data processed\t\t\t = %d\n';
fprintf(text, size(orderedData, 1)*2)
fprintf(fileID,text, size(orderedData, 1)*2);
text='Calibration Success Rate\t\t = %0.2f%%\n\n';
fprintf(text, (m-1)/size(orderedData, 1)/2*100)
fprintf(fileID,text, (m-1)/size(orderedData, 1)/2*100);
text='Mean \x03bc (slope) coefficient\t\t = %0.3g\n';
fprintf(text,mean(realMuCoefficient))
fprintf(fileID,text,mean(realMuCoefficient));
text='StandDev \x03bc (slope) coefficient\t\t = %0.3g\n\n';
fprintf(text,std(realMuCoefficient))
fprintf(fileID,text,std(realMuCoefficient));
text='Mean Calibration Factor \x0251\t\t = %0.3g [nN/mV]\n';
fprintf(text,mean(realAlphaCoefficient))
fprintf(fileID,text,mean(realAlphaCoefficient));
text='StandDev Calibration Factor \x0251\t\t = %0.3g\n\n';
fprintf(text,std(realAlphaCoefficient))
fprintf(fileID,text,std(realAlphaCoefficient));
text='Mean \x03bc (flat) coefficient\t\t = %0.3g\n';
fprintf(text,mean(realMuFlatCoefficient))
fprintf(fileID,text,mean(realMuFlatCoefficient));
text='StandDev \x03bc (flat) coefficient\t\t = %0.3g\n\n';
fprintf(text,std(realMuFlatCoefficient))
fprintf(fileID,text,std(realMuFlatCoefficient));
fclose(fileID);
close all