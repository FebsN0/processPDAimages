The MATLAB code "automateWedgeCalibration.m" consists of a user-friendly guided process
for calculating the calibration factor alpha, which must be entered in the post-processing
of non-calibration experiment data.

The theory behind the alpha factor calculation is taken from the following work
(https://pubs.acs.org/doi/full/10.1021/acs.jpcc.8b03583) by R.Ortuso and K.Sugihara and the
current code also considers the more recent work (https://doi.org/10.1021/acs.analchem.3c01433)
of J.Zheng and K.Sugihara.

%%%%%%%%%%%%%%%%%%%%%%% REQUIRED INPUT FILE %%%%%%%%%%%%%%%%%%%%%
--------- force curves data (optional in some circustances)
            (raw data, do not apply any modification by "JPKSPM Data Processing" software)
--------- height and lateral deflection (Trace and Retrace) cross-section files.
 
%%%%%%%%%%%%%%%%%%%%%%% REQUIRED OUPUT FILE %%%%%%%%%%%%%%%%%%%%%
--------- .mat file where all important data are saved
--------- .txt file where friction (slope and flat) coefficients and calibration factor
            are printed out.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
    TIPS ABOUT HEIGHT/TRACE/RETRACE DATA PRE-PROCESSING
	1) Upload in "JPKSPM Data Processing" software the .jpk file in which the calibration experiment
       raw results are saved; 

	2) Since the grating was likely tilted during the experiment, execute on "Height" data 
	   the "Plane Fit" tool with Degree 1. NOTE: to better fit, select the background as a
	   reference. In most cases, there is no need to execute the "Line Levelling" (See
	   the "JPKSPM Data Processing" manual for further information).

	3) The grating is likely not perfectly oriented vertically (between 1° and 2°
       to the vertical line). 
       It is possible to fix during the calibration experiment by entering the degree of the tip 
       scanning direction. 
       If not, to get corrected relative horizontal line data information along a single grate (i.e.
	   left slope + flat + right slope), manually identify the angle using the "Distance" tool.
	        Once the angle is known, open the "Cross-section" tool and select at least FIVE times
	   different single grates by choosing a starting coordinate (X1, Y1) and a final
	   coordinate (X2, Y2).
            NOTE: run the MATLAB function code "calcY2.m" by providing X1, X2, Y1 and the angle
       previously found to easily calculate Y2.
	   For every single grate, click "Save Cross Section Data".

	5) Using the SAME (very important!) coordinates X1, Y1, X2 and Y2 previously used to
	   extract Height data, also extract the lateral deflection cross-sections in Trace and
	   Retrace data.
	        NOTE 1: DO NOT EXECUTE ANY TOOLS (like "Plane Fit"). They may significantly alter 
	   the raw data and most of the experiment imperfections will be canceled out
	   automatically in the wedge method.
       Using the SAME (very important!) coordinates X1, Y1, X2, and Y2, previously used to extract
       height data, the lateral deflection cross-sections in trace and trace data were also extracted.
            NOTE 1: DO NOT EXECUTE ANY TOOLS (like "Plane Fit"). They may significantly alter the raw data,
       and the wedge method will cancel most of the experiment imperfections automatically.
	        NOTE 2: If there are more trace/retrace cross-sections for the same Height (for example, 
       from several different SETPOINTS or speed scan rates), currently, the code processes only one
       condition (single SETPOINT or single speed scan rate).
       To get the calibration factor using different setpoints/speed scan rates, re-run the code
       by selecting the same Height data but using different lateral deflection data.
       The main reason is that the cross-section files exported from the "JPKSPM Data Processing"
       software lack setpoint/speed scan rates information.
            NOTE 3: it is possible to use only one Height data when more Trace/Retrace
       data are used.

	   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% IMPORTANT!! %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       %%%%% BEFORE UPLOADING THE CROSS-SECTION FILES, CHECK IF THE COORDINATES
	   %%%%% ARE PERFECTLY THE SAME AMONG THE SAME CROSS-SECTION LINES.
       %%%%% It's important to note that sometimes, the 'JPKSPM Data Processing'
       %%%%% software does not write identical coordinates (i.e. 262.0 =/= 261.9999 or 262).
       %%%%% 
       %%%%% If this step is overlooked and incorrect data is uploaded, it can lead to system error.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% INSTRUCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

1) Upload Height/Trace/Retrace .cross files. Check automatically if something is wrong among 
   .cross files.

2) Decide whether to process only one Height Data point or every Height Data point
   (in the latter case, the number of Height Data points MUST be the same as the Trace Data point).
   
3) Choose if the plots during the run appear in a second monitor in the maximized window.

4) Choose if plot every availabe overlapped Height/Trace/Retrace Data

3) Input the value of the SETPOINT from which Trace and Retrace cross-section files originated.

4) Choose whether to manually input the Adhesion Force values or directly import the force curve files.
	- "manual": the averaged Adhesion Force value is given after inputting the Adhesion Force
	  values for each force curve
	- "import": after uploading the force curves .txt files, it will be asked to the user if
	  the calibration experiment was run in air or aqueous solution.
		- "air": after shifting the force values based on the approaching phase, the Adhesion 
		        Force is easily obtained by finding the minimum force value, because
	            it differs markedly from the noise.
		- "aqueous": Select the range where the minimum adhesion force is found. This option is possible
                to select even in air condition, but the final adhesion force will
                likely be the same as well as the "air" approach
            
            NOTE: In aqueous conditions, the force adhesion is minimal in nN and close to zero.
            The noise can be even higher. Therefore, the min function can lead to wrong force
            adhesion values. A user-guided selection will follow to find the force adhesion for any force
            curve, but remember that it is a minimal value.

5) Select the option for theta angle calculation:
    (1) enter manually only once the angle
    (2) calculate only once the theta angle and use it for the rest of the run
    (3) Calculate theta angle for each data

6) Process iteratively the Trace/Retrace/Height data
    %%%%%%%%%%%%%%% IMPORTANT NOTE %%%%%%%%%%%%%%%%%%%%

%   It is better not to average the data before calculating the friction coefficients and calibration
%   factor, because if it occurs, it will bring errors that are normally canceled when Delta and W of
%   the single data are used

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    A) From the Height Data, choose two coordinates to calculate the theta angle.
        NOTE: If only one Height Data, calculate the theta angle only once. Otherwise, calculate it
        for every Height Data. It will be asked of the calculated angle is ok
    B) Trace and Retrace are now plotted ==> select the range for the
        - Trace:    Left Slope
        - Trace:    Flat
        - Trace:    Right Slope
        - Retrace:  Left Slope
        - Retrace:  Flat
        - Retrace:  Right Slope
       Semi-trasparent rectangle appears to guide you which section are you taking into account.
       After the selection, it will be asked if the real index (i.e. the points closer to the manually
       selected points are ok. If not, re-iterate again automatically from the Trace - Left Slope
                   
            %%%%%%%%%%%%%%%%%% From this point, the rest is all automatic %%%%%%%%%%%
    C) Averaged lateral deflection voltage is automatically calculated for each selected section
        ==> the mean and standard deviation will be plotted
    D) Delta and W are automatically calculated ==> they will be plotted
    E) Solve the second order equation using all the entered and calculated variables
        (i.e. Setpoint, Adhesion Force, theta, W and Delta)
    F) Friction (slope and flat) coefficients and calibration factor are calculated!
            NOTE: if the solution of the second order equation is:
                        - outside the range 0<x<1
                                (negative or higher than 1 friction coefficient are no sense)
                        - a complex number
                    ==> then it will be rejected!

7) Save the results in .txt and .mat files






