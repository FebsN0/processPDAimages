# Python code for ExperimentPlanner
# JPK Script
checkVersion('SPM', 6, 4, 32)
# IMPORTANT!!!!!!!!!!!!!!!
# DONT FORGET TO CHANGE DISTANCE X HOVER MODE ON 
# by default is 50 nm ==> too close to the sample

# PREMISE ON HOW TO USE THE SCRIPT AND WORKFLOW:
# 1 step : setup the AFM (calibration, HV distance, laser centering) ==> NOTE: only once for the entire sample scanning (NOT REPEAT FOR MULTIPLE SCANS ON THE SAME SAMPLES ==> no consistemcy anymore otherwise)
# 2 step : run xAFM_prepareSettings.py to prepare the scanning area depending on the parameters. Read the total estimated time for a single entire scan.
#	EXAMPLE : if total estimated time = 95 minutes -> change the value in NIKON macro (in seconds)
# 3 step : modify the parameters in the ExperimentPlanner script and NIKON macro script (especially the waiting NIKON time)
# 4 step : choose the potential scanning area on NIKON. Eventually correct the laser centering (no approach but close)
# 5 step : put far away the AFM tip (>4000 mm) MOTORS UP. Turn the LASER OFF
# 6 step : start the macro on NIKON software ==> automatic fast and saving acquisition (remember to move the data of the previous scan, otherwise overwritten!!!)
# 7 step : once the NIKON acquisition terminates, MOTORS DOWN the tip with safety distance of 200 um (4000 UP -> 3800 DOWN)
# 8 step : run the ExperimentPlanner script (current last version: 9)
# final step : just wait :)
# note: once the NIKON macro and ExperimentPlanner scripts are running, you dont have to do anything anymore.

# WHAT YOU HAVE TO MODIFY EVERYTIME (PARAMETERS)
# 1) setpointList (expressed in Newton unit)
#       ==> if you want 5 setpoint in 5 sections ==>  [30e-9, 50e-9, 70e-9, 90e-9, 110e-9]        # N
#       ==> if you want 5 setpoint in 10 sections ==> [30e-9, 30e-9, 50e-9, 50e-9, 70e-9, 70e-9, 90e-9, 90e-9, 110e-9, 110e-9]
#       ==> if you want 1 setpoint in 5 sections  ==> [30e-9, 30e-9, 30e-9, 30e-9, 30e-9 ]
# 2) springConstant (N/m)           ==> it is just a reminder. the script doesnt use it. Update when you calibrate
# 3) sensitivity    (nm/V)          ==> it is just a reminder. the script doesnt use it. Update when you calibrate
# 4) array = [<number>]             ==> ONLY TWO POSSIBLE VALUES:
#                                       # 0: HOVER MODE ON
#                                       # 1: HOVER MODE OFF
#					# version9 : run both 0 and 1 consecutively
# 5) scanSizeFast  	=  values in meter unit (example 50.0e-6  == 50 um)
# 6) fastPixels		= values in pixels (example 512)
# 7) scan_rate		= values in Hertz (example 0.18 Hz)
# 8) baseDirName	= <ENTIRE PATH>            where create the directory HOVER MODE <ON/OFF> in which the sections will be saved
#           EXAMPLE: '/home/jpkuser/jpkdata/Jianlu/20240528 Zhu'
#                    '/home/jpkuser/jpkdata/Fabiano/experiments/1_lipidEffects/2_6_2 TRCDA:DMPC/friction_BKonly/7'
# 9) waitingTime	= time lenght in which AFM does nothing after motors go up so give time for NIKON microscopy to make acquisition after scratching (HOVER MODE ON). After this time, start scan HVoff

from com.jpk.inst.lib import JPKScript
from com.jpk.spm.data import AmplitudeSetpointFeedbackSettings
from com.jpk.data import SetpointFeedbackSettings
from com.jpk.spm.data import HoverSpatialScanningStyle
from com.jpk.spm.data import SimpleSpatialScanningStyle
from datetime import datetime

'''
Set vertical deflection setpoint for AC-Mode. Depending on the activated calibration constant,
convert the volt value into the specified unit (meter or newton)
'''
def setAmplitudeSetpoint(value):
    print('SET SETPOINT %e' % value)
    instrument = JPKScript.getInstrument()
    feedbackModeInfo = instrument.getCurrentFeedbackModeInfo()
    feedbackSettings = feedbackModeInfo.getPrimaryFeedbackSettings()
    feedbackChannel = feedbackModeInfo.getFeedbackChannel()

    # scale setpoint value to base volts
    conversionSet = instrument.getChannelInfo(feedbackChannel).getConversionSet()
    calibrationSlot = conversionSet.getDefaultCalibrationSlot()
    setpointCalibrationSlot = feedbackSettings.getSetpointCalibrationSlot()
    setpointVolts = conversionSet.scale(value, calibrationSlot, setpointCalibrationSlot)

    # set new setpoint
    parameters = AmplitudeSetpointFeedbackSettings.Parameters(feedbackSettings)
    parameters.setRelativeSetpoint(setpointVolts)
    newFeedbackSettings = feedbackSettings.createModifiedSettings(parameters)
    feedbackModeInfo.setPrimaryFeedbackSettings(newFeedbackSettings)
    return value

'''
Set vertical deflection setpoint for Contact-Mode. Depending on the activated calibration constant,
convert the volt value into the specified unit (meter or newton)
'''
def setVDeflectionSetpoint(value):
    print('SET SETPOINT %.2e' % value)
    instrument = JPKScript.getInstrument()
    feedbackModeInfo = instrument.getCurrentFeedbackModeInfo()
    feedbackSettings = feedbackModeInfo.getPrimaryFeedbackSettings()
    feedbackChannel = feedbackModeInfo.getFeedbackChannel()

    # scale setpoint value to base volts
    conversionSet = instrument.getChannelInfo(feedbackChannel).getConversionSet()
    calibrationSlot = conversionSet.getDefaultCalibrationSlot()
    setpointCalibrationSlot = feedbackSettings.getSetpointCalibrationSlot()
    setpointVolts = conversionSet.scale(value, calibrationSlot, setpointCalibrationSlot)

    # 　set new setpoint
    parameters = SetpointFeedbackSettings.Parameters(feedbackSettings)
    parameters.setRelativeSetpoint(setpointVolts)
    newFeedbackSettings = feedbackSettings.createModifiedSettings(parameters)
    feedbackModeInfo.setPrimaryFeedbackSettings(newFeedbackSettings)
    return value

'''
Get the current vertical deflection baseline in the current vertical
deflection unit, depending on the calibration
'''
def getBaseline():
    instrument = JPKScript.getInstrument()
    feedbackModeInfo = instrument.getCurrentFeedbackModeInfo()
    feedbackSettings = feedbackModeInfo.getPrimaryFeedbackSettings()
    baselineVolts = feedbackSettings.getBaseline()

    feedbackChannel = feedbackModeInfo.getFeedbackChannel()
    conversionSet = instrument.getChannelInfo(feedbackChannel).getConversionSet()
    calibrationSlot = conversionSet.getDefaultCalibrationSlot()

    baseline = conversionSet.scale(baselineVolts, calibrationSlot)
    #print('GET BASELINE = %.2e' % baseline)
    return baseline

'''
Enable/Disable HoverMode
'''
def enableHoverMode(enable):
    print('HOVER-MODE %s' % enable)
    instrument = JPKScript.getInstrument()
    style = instrument.getSpatialScanningStyleSupport().getValue().getStyle()
    mode = JPKScript.getMode()
    if enable == True:
        mode.setSpatialScanningStyle(HoverSpatialScanningStyle(style, True))
    else:
        mode.setSpatialScanningStyle(SimpleSpatialScanningStyle(style))

'''
Turn On/Turn Off the laser
'''
def setLaserEnable(enable=True):
    print('LASER STATE %s' % enable)
    instrument = JPKScript.getInstrument()
    dspManager = instrument.getDSPManager()
    dspManager.setLaserEnable(int(enable))

'''
Define a list of setpoints for each section, here in Newton scaling (sensitivity and spring constant activated)
If you have calibrated only the sensitivity value, setpoint must be given in METER, 30 nm = 30e-9
'''
setpointList = [30e-9, 40e-9, 50e-9, 60e-9, 70e-9, 80e-9, 90e-9]  # N
springConstant = 0.249  # N/m
sensitivity = 80.44  # nm/V
array = [0, 1]  # 0: HOVER MODE ON      # 1: HOVER MODE OFF
waitingTime = 600 # seconds. 10 minutes
'''
setup the base direcory for saving data
this will be extended later in the loop to
sort HoverMode ON/OFF scans
'''
baseDirName = '/home/jpkuser/jpkdata/Fabiano/experiments/1_lipidEffects/1_1_2_TRCDA_5_4mN_m/1'
Imaging.setOutputDirectory(baseDirName + '/')
Imaging.setAutosave(True)

'''
Setup the initial scan parameters at the current x,y offset position
'''
# if 5 different setpoints  ==> 5 slow direction scan sections
# if the fast size is 50um ==>  slow size = 5um
scanSizeFast = 80.0e-6  # 50 um
scanSizeSlow = scanSizeFast / len(setpointList)
fastPixels = 1024  # 640 for 5 sections ==> 140*5 = 640 pixels
slowPixels = fastPixels / len(setpointList)
scan_rate = 0.18  # Hz

# when start, the laser is supposed to be already active
laserOn= True

# extract the origin of the scanning
xOffset = Imaging.getXOffset()
yOffset = Imaging.getYOffset()
# save the origin of the y axis, so when the first entire scan is completed,
# come back to the y origin for the next scan
yOffset_origin = yOffset

# Scanner.retractPiezo()
Imaging.setScanSize(scanSizeFast, scanSizeSlow)
Imaging.setScanPixels(fastPixels, slowPixels)
Imaging.setLineRate(scan_rate)

# create textfile for metadata (if exist, append, to avoid overwrite in case of forgetting to change directory
f = open(baseDirName + '/baseline.txt', 'a')
# write start info and add a header
dateStart = datetime.now()
f.write('\n# Start time = %s\n' % dateStart)
f.write('# Scan output directory = %s\n' % baseDirName)
f.write('# ScanSizeFast (X) = %e\n' % scanSizeFast)
f.write('# ScanSizeSlow (Y) = %e\n' % scanSizeSlow)
f.write('# ScanIndex\tSetpoint\tBaselineStart\tBaselineEnd\tXOffset\tYOffset\n')
f.flush()

scanIndex = 0
try:
    '''
    Start the measurement
    '''
    textDirectory = ["/HoverMode_ON", "/HoverMode_OFF"]
    conditionHVmode = [True, False]
    # two for cycles
    # Cycle 1 HoverMode ON
    # Cycle 2 HoverMode OFF
    for i in array:
        Imaging.setOutputDirectory(baseDirName + textDirectory[i])
        # check the status of the laser. If off, turn it on. Usually off after end first cycle
        if laserOn==False:
            laserOn=True
        setLaserEnable(laserOn)
        # change Hover Mode Status
        enableHoverMode(conditionHVmode[i])
	# ensure to be in position
        Scanner.approach()
	# retract by default by 8um
        Scanner.retract()
        for setpoint in setpointList:
            print('yOFFSET: %e' % yOffset)
            Imaging.setScanOffset(xOffset, yOffset)
            # Set setpoint
            setVDeflectionSetpoint(setpoint)
            # approach (complete) and measure current baseline
            Scanner.approach()
            baselineStart = getBaseline()
            # start image scan
            Imaging.startScanning(1)
            # after finishing the entire section scan, retract and approach piezo to update baseline　at the
            # end of the scan to compare how they changed
            Scanner.retractPiezo()
            Scanner.approachPiezo()
            baselineEnd = getBaseline()
            Scanner.retract()
            # increment scan index
            scanIndex += 1
            # write metadata to text file for each scan
            f.write('%d\t%e\t%e\t%e\t%e\t%e\n' % (scanIndex, setpoint, baselineStart, baselineEnd, xOffset, yOffset))
            f.flush()
            # Move the scan in the slow scan direction by scanSizeSlow
            yOffset += scanSizeSlow

        # once finished the entire scan for specific hover mode, let's back to the y offset origin
        yOffset = yOffset_origin
        Imaging.setScanOffset(xOffset, yOffset)
        # turn off the laser
        laserOn=False
        setLaserEnable(laserOn)
	# move far away the tip so better NIKON acquisition can be performed
        Scanner.moveMotorsUp(4e-3) # 4000 um equal to 4 mm 

        # The reason of turning off the laser is when NIKON script perform all the required fluorescence post scan automatically without light interference
    	# wait for the NIKON acquisition after completing the first cycle
        if i==array[0]:
            print('WAITING ACQUISITION COMPLETATION')
            time.sleep(waitingTime)
            print('STARTING SECOND SCAN HVoff')
	# put tip closer using motors but with a safety distance of 200 um. approach will put the tip closer safely
            Scanner.moveMotorsDown(3.8e-3) 
    
finally:
    dateEnd = datetime.now()
    f.write('\n# End time = %s\n' % dateEnd)
    td = dateEnd - dateStart
    duration_in_s = (td.microseconds + (td.seconds + td.days * 24 * 3600) * 10 ** 6) / 10 ** 6
    duration_in_min = divmod(duration_in_s, 60)[0]
    f.write('# Total time (min)= %d\n' % duration_in_min)
    f.close()

print('SCANNING COMPLETE! GOOD JOB. Hope your data is good! Dont forget to cite me in your works...')
