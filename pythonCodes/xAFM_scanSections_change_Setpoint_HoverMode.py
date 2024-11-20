# Python code for ExperimentPlanner
# JPK Script
checkVersion('SPM', 6, 1, 186)

from com.jpk.inst.lib import JPKScript
from com.jpk.spm.data import AmplitudeSetpointFeedbackSettings
from com.jpk.spm.data import HoverSpatialScanningStyle
from com.jpk.spm.data import SimpleSpatialScanningStyle

'''
Set amplitude setpoint for AC-Mode
Please note: setpoint MUST be given in the current scaling
of the setpoint (nm) or (V), depending on an active sensitivity
calibration
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
    setpointVolts = conversionSet.scale(value, calibrationSlot, setpointCalibrationSlot )

    #set new setpoint
    parameters = AmplitudeSetpointFeedbackSettings.Parameters(feedbackSettings)
    parameters.setRelativeSetpoint(setpointVolts)
    newFeedbackSettings = feedbackSettings.createModifiedSettings(parameters)
    feedbackModeInfo.setPrimaryFeedbackSettings(newFeedbackSettings)
    return value

'''
Enable/disable HoverMode
'''
def enableHoverMode(enable):
    print('ENABLE HOVER-MODE %s' % enable)
    instrument = JPKScript.getInstrument()
    style = instrument.getSpatialScanningStyleSupport().getValue().getStyle()
    mode = JPKScript.getMode()
    if enable == True:
        mode.setSpatialScanningStyle(HoverSpatialScanningStyle(style, True))
    else:
        mode.setSpatialScanningStyle(SimpleSpatialScanningStyle(style))

'''
Define a list of setpoints here in VOLTS scaling. If you have calibrated 
the sensitivity value, setpoint must be given in METER, 30 nm = 30e-9
Otherwise, enter the sensitivity and spring constant. Conver the nN into Volts
'''

setpointListNanoNewton = [20, 40, 60, 80, 100]   # nN
setpointListNewton=[x * 1e-9 for x in setpointListNanoNewton]   # N
springConstant= 0.264                                 # N/m
sensitivity=80.60                                       # nm/V
setpointListVolts=[x / (springConstant*sensitivity) for x in setpointListNanoNewton]

'''
setup the base directory for saving data
this will be extended later in the loop to
sort HoverMode ON/OFF scans
'''

baseDirName='/home/jpkuser/jpkdata/Fabiano/experiments/1_lipidEffects/2_2_TRCDA_DMPC_7525_10mM_22luglio2024/4_air_03Hz'
Imaging.setOutputDirectory(baseDirName)
Imaging.setAutosave(True)


'''
Setup the initial scan size of a single section at the current x,y offset position.
'''
scanSizeFast = 50.0e-6     # 50 um
# if 10 setpoints  ==> 10 slow direction scan sections with a size of 5 um if fast scan line direction is 50 um long
scanSizeSlow = scanSizeFast / len(setpointListVolts)

# extract the origin of scanning
xOffset = Imaging.getXOffset()
yOffset = Imaging.getYOffset()
# save the origin of y axis, so when the first entire scan is completed, switch hover mode and come back to the y origin
yOffset_origin = yOffset                             
Scanner.retractPiezo()
Imaging.setScanSize(scanSizeFast, scanSizeSlow)

'''
Set other parameters (pixel size, scan line rate)
'''
fastPixels=600			# 512 for 8 sections ==> 512+64+64 = 640 pixels
slowPixels= fastPixels/len(setpointListVolts)
Imaging.setScanPixels(fastPixels, slowPixels)
scan_rate=0.5	# 1 Hz
Imaging.setLineRate(scan_rate)

'''
Start the measurement
'''

# define mode Hover Mode
textToPrint = ["START SCAN 1 HOVER MODE ON", "START SCAN 2 HOVER MODE OFF"]
textDirectory = ["/HoverMode_ON", "/HoverMode_OFF"]
conditionHVmode = [True, False]

# two for cycles:
# Cycle 1 HoverMode ON
# Cycle 2 HoverMode OFF 
for i in range(0,1):
    Imaging.setOutputDirectory(baseDirName+textDirectory[i])
    enableHoverMode(conditionHVmode[i])

    for setpoint in setpointListVolts:
        print(yOffset)
        Imaging.setScanOffset(xOffset, yOffset)
        # Set setpoint
        setAmplitudeSetpoint(setpoint)    
        Scanner.approachPiezo()
        Imaging.startScanning(1)
        Scanner.retractPiezo()    
        # Move the scan in the slow scan direction by scanSizeSlow 
        yOffset += scanSizeSlow

    
    yOffset=yOffset_origin
    Imaging.setScanOffset(xOffset, yOffset)
print('DONE....')