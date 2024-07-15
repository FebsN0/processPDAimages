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

setpointListNewton = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]   # N
setpointListNanoNewton=[x * 1e-9 for x in setpointListNewton]   # nN
springConstant= 0.227                                         # N/m
sensitivity=72.47e-9                                             # nm/V
setpointListVolts=[x / (springConstant*sensitivity) for x in setpointListNanoNewton]

'''
setup the base directory for saving data
this will be extended later in the loop to
sort HoverMode ON/OFF scans
'''

baseDirName='/home/jpkuser/jpkdata/Fabiano/5_20240712_DEMO3_ExperimentPlannerFirstTime'
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
fastPixels=640			# 512 for 8 sections ==> 512+64+64 = 640 pixels
slowPixels= fastPixels/len(setpointListVolts)
Imaging.setScanPixels(fastPixels, slowPixels)
scan_rate=1	# 1 Hz

'''
Save all parameters in a txt file. If already exists it the dir, overwrite
'''
text = """
( setpoint [N] / springConstant [N/m] / sensitivity [nm/V] )
setpoint [nN]\t\t\t= {}
setpoint [V]\t\t\t= {}
scanSizeFast [m]\t\t= {:.3g}
scanSizeSlow [m]\t\t= {:.3g}
xOffset origin\t\t\t= {}
yOffset origin\t\t\t= {}
Fast scan line pixels\t\t= {}
Slow scan line pixels\t\t= {}
scan Rate [Hz]\t\t\t= {}
""".format(setpointListNewton, [round(x,3) for x in setpointListVolts], scanSizeFast, scanSizeSlow, xOffset, yOffset, fastPixels, slowPixels, scan_rate)

with open(baseDirName+'/variables.txt', 'w') as file:
    file.write(text)

'''
Start the measurement
'''

# define mode Hover Mode
textToPrint = ["START SCAN 1", "START SCAN 2"]
textDirectory = ["/HoverMode_ON", "/HoverMode_OFF"]
conditionHVmode = [True, False]

# two for cycles:
# Cycle 1 HoverMode ON
# Cycle 2 HoverMode OFF 
for i in range(0,2):
    print(textToPrint[i])
    Imaging.setOutputDirectory(baseDirName+textDirectory[i])
    enableHoverMode(conditionHVmode[i])

    for setpoint in setpointListVolts:
        # Set setpoint
        setAmplitudeSetpoint(setpoint)    
        Scanner.approachPiezo()
        Imaging.startScanning(1)
        Scanner.retractPiezo()
    
        # Move the scan in the slow scan direction by scanSizeSlow 
        yOffset += scanSizeSlow
        Imaging.setScanOffset(xOffset, yOffset)

print('DONE....')

