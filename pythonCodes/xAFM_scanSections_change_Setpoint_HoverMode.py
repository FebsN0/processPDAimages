# Python code for ExperimentPlanner
# JPK Script
checkVersion('SPM', 6, 4, 25)

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
'''
setpointList = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]


'''
setup the base directory for saving data
this will be extended later in the loop to
sort HoverMode ON/OFF scans
'''
baseDirName=input(f"Enter the path of the folder where save the scanned AFM section .jpk images (example: \"/home/name/.../destination\").")
Imaging.setOutputDirectory(baseDirName)
Imaging.setAutosave(True)


'''
Setup the initial scan size of a single section at the current x,y offset position.
'''
scanSizeFast = 50.0e-6     # 50 um
# if 10 setpoints  ==> 10 slow direction scan sections with a size of 5 um if fast scan line direction is 50 um long
scanSizeSlow = scanSizeFast / len(setpointList)

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
slowPixels= fastPixels/len(setpointList)
Imaging.setScanPixels(fastPixels, slowPixels)
scan_rate=1	# 1 Hz

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
for i in range(2)
    
    print(textToPrint[i])
    Imaging.setOutputDirectory(baseDirName+textDirectory[i])
    enableHoverMode(conditionHVmode[i])

    for setpoint in setpointList:
        # Set setpoint
        setAmplitudeSetpoint(setpoint)    
        Scanner.approachPiezo()
        Imaging.startScanning(1)
        Scanner.retractPiezo()
    
        # Move the scan in the slow scan direction by scanSizeSlow 
        yOffset += scanSizeSlow
        Imaging.setScanOffset(xOffset, yOffset)

    
print('DONE....')

