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
of the setpoint (nm) or (V), depending on a active sensitivity
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
Enable / disable HoverMode
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
Define a list of setpoints, here in VOLTS scaling. If you have calibrated 
the sensitivity value, setpoint must be given in METER, 30 nm = 30e-9
'''
setpointList = [0.1, 0.2, 0.3, 0.5, 0.6, 0.7, 0.8, 0.9]


'''
setup the base direcory for saving data
this will be extended later in the loop to
sort HoverMode ON/OFF scans
'''
baseDirName = '/home/barner/test'
Imaging.setOutputDirectory(baseDirName)
Imaging.setAutosave(True)

'''
Setup the inital scan size at the current x,y offset position
'''
scanSizeFast = 40.0e-6
scanSizeSlow = 5.0e-6

xOffset = Imaging.getXOffset()
yOffset = Imaging.getYOffset()
Scanner.retractPiezo()
Imaging.setScanSize(scanSizeFast, scanSizeSlow)

'''
Start the measurement
'''
for setpoint in setpointList:

    # Set setpoint
    setAmplitudeSetpoint(setpoint)
    
    # Scan 1 HoverMode ON
    Imaging.setOutputDirectory(baseDirName+'/HoverMode_ON')
    enableHoverMode(True)
    Scanner.approachPiezo()
    print('START SCAN 1')
    Imaging.startScanning(1)
    Scanner.retractPiezo()

    # Scan 2 HoverMode OFF
    Imaging.setOutputDirectory(baseDirName+'/HoverMode_OFF')
    enableHoverMode(False)
    Scanner.approachPiezo()
    print('START SCAN 2')
    Imaging.startScanning(1)
    Scanner.retractPiezo()

    # Move the scan in the slow scanDirection by scanSizeSlow 
    yOffset += scanSizeSlow
    Imaging.setScanOffset(xOffset, yOffset)

    
print('DONE....')
    
    
    
