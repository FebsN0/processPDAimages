# Python code for ExperimentPlanner
# JPK Script
checkVersion('SPM', 6, 4, 25)

from com.jpk.inst.lib import JPKScript
from com.jpk.spm.data import AmplitudeSetpointFeedbackSettings
from com.jpk.data import SetpointFeedbackSettings
from com.jpk.spm.data import HoverSpatialScanningStyle
from com.jpk.spm.data import SimpleSpatialScanningStyle

from datetime import datetime

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
    setpointVolts = conversionSet.scale(value, calibrationSlot, setpointCalibrationSlot)

    #set new setpoint
    parameters = AmplitudeSetpointFeedbackSettings.Parameters(feedbackSettings)
    parameters.setRelativeSetpoint(setpointVolts)
    newFeedbackSettings = feedbackSettings.createModifiedSettings(parameters)
    feedbackModeInfo.setPrimaryFeedbackSettings(newFeedbackSettings)
    return value

'''
Set vertical deflection setpoint for Contact-Mode
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

     #set new setpoint
    parameters = SetpointFeedbackSettings.Parameters(feedbackSettings)
    parameters.setRelativeSetpoint(setpointVolts)
    newFeedbackSettings = feedbackSettings.createModifiedSettings(parameters)
    feedbackModeInfo.setPrimaryFeedbackSettings(newFeedbackSettings)
    return value

'''
Get current vertical deflection baseline in current vertical
deflection unit, depending on calibration
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
    print('GET BASELINE = %.2e' % baseline)
    return baseline

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
setpointList = [10e-9, 20e-9, 30e-9, 40e-9, 50e-9]

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
scanSizeFast = 10.0e-6
scanSizeSlow = 2.0e-6

xOffset = Imaging.getXOffset()
yOffset = Imaging.getYOffset()
Scanner.retractPiezo()
Imaging.setScanSize(scanSizeFast, scanSizeSlow)
Imaging.setOutputDirectory(baseDirName+'/')
scanIndex = 0

# create textfile for meta data
f = open(baseDirName+'/baseline.txt', 'w')
# write headder
f.write('# Start time = %s' % datetime.now())
f.write('# Scan output directory = %s\n' % baseDirName)
f.write('# ScanSizeFast (X) = %e\n' % scanSizeFast)
f.write('# ScanSizeSlow (Y) = %e\n' % scanSizeSlow)
f.write('# ScanIndex Setpoint BaselineStart BaselineEnd XOffset YOffset\n')

try:
    '''
    Start the measurement
    '''
    for setpoint in setpointList:

        #increment scan index
        scanIndex += 1

        # Set setpoint
        #setAmplitudeSetpoint(setpoint)
        setVDeflectionSetpoint(setpoint)
    
        # approach and measure current baseline
        Scanner.approachPiezo()
        baselineStart = getBaseline()
       
        # start image scan
        Imaging.startScanning(1)

        # retract piezo and update baseline
        Scanner.retractPiezo()
        Scanner.approachPiezo()
        baselineEnd = getBaseline()
        Scanner.retract()

        # write meta data to text file
        f.write('%d %e %e %e %e %e\n' % (scanIndex, setpoint, baselineStart, baselineEnd, xOffset, yOffset))
        f.flush()

        # Move the scan in the slow scanDirection by scanSizeSlow 
        yOffset += scanSizeSlow
        Imaging.setScanOffset(xOffset, yOffset)

finally:
    f.close()
    
print('DONE....')
    
    
    
