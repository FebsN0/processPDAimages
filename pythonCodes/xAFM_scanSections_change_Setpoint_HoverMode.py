# Python code for ExperimentPlanner
# JPK Script
checkVersion('SPM', 6, 4, 32)

from com.jpk.inst.lib import JPKScript
from com.jpk.spm.data import AmplitudeSetpointFeedbackSettings
from com.jpk.data import SetpointFeedbackSettings
from com.jpk.spm.data import HoverSpatialScanningStyle
from com.jpk.spm.data import SimpleSpatialScanningStyle
    
from datetime import datetime

'''
Set vertical deflection setpoint for AC- Mode
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

     #set new setpoint (changed here!)
    parameters = SetpointFeedbackSettings.Parameters(feedbackSettings)
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
    print('GET BASELINE = %.2e' % baseline)
    return baseline

'''
Define a list of setpoints, here in VOLTS scaling. If you have calibrated 
the sensitivity value, setpoint must be given in METER, 30 nm = 30e-9
'''
setpointList = [30e-9, 50e-9, 70e-9, 90e-9, 110e-9]
springConstant= 0.452                                # N/m
sensitivity=63.65
array = [0]         # 0: HOVER MODE ON      # 1: HOVER MODE OFF
'''
setup the base direcory for saving data
this will be extended later in the loop to
sort HoverMode ON/OFF scans
'''
baseDirName='/home/jpkuser/jpkdata/Fabiano/experiments/1_lipidEffects/3_3_1 TRCDA:DOPC/4'
Imaging.setOutputDirectory(baseDirName+'/')
Imaging.setAutosave(True)

'''
Setup the initial scan parameters at the current x,y offset position
'''
# if 5 different setpoints  ==> 5 slow direction scan sections
# if the fast size is 50um ==>  slow size = 5um
scanSizeFast =  80.0e-6     # 50 um
scanSizeSlow =  scanSizeFast / len(setpointList)          
fastPixels=     1024           # 640 for 5 sections ==> 140*5 = 640 pixels
slowPixels=     fastPixels/len(setpointList)
scan_rate=      0.18    # Hz

# extract the origin of the scanning
xOffset = Imaging.getXOffset()
yOffset = Imaging.getYOffset()
# save the origin of the y axis, so when the first entire scan is completed,
# switch hover mode and come back to the y origin
yOffset_origin = yOffset   

Scanner.retractPiezo()
Imaging.setScanSize(scanSizeFast, scanSizeSlow)
Imaging.setScanPixels(fastPixels, slowPixels)
Imaging.setLineRate(scan_rate)

# create textfile for metadata
f = open(baseDirName+'/baseline.txt', 'w')
# write start info and add a header
f.write('# Start time = %s' % datetime.now())
f.write('# Scan output directory = %s\n' % baseDirName)
f.write('# ScanSizeFast (X) = %e\n' % scanSizeFast)
f.write('# ScanSizeSlow (Y) = %e\n' % scanSizeSlow)
f.write('# ScanIndex\tSetpoint\tBaselineStart\tBaselineEnd\tXOffset\tYOffset\n')

scanIndex = 0
try:
    '''
    Start the measurement
    '''
    # define mode Hover Mode
    textToPrint = ["START SCAN 1 HOVER MODE ON", "START SCAN 2 HOVER MODE OFF"]
    textDirectory = ["/HoverMode_ON", "/HoverMode_OFF"]
    conditionHVmode = [True, False]
    # two for cycles (for now only first cycle)
        # Cycle 1 HoverMode ON
        # Cycle 2 HoverMode OFF
    for i in array:
        Imaging.setOutputDirectory(baseDirName+textDirectory[i])
        enableHoverMode(conditionHVmode[i])
        for setpoint in setpointList:
            print('yOFFSET: %e' % yOffset)
            Imaging.setScanOffset(xOffset, yOffset)
            
            # Set setpoint
            #setAmplitudeSetpoint(setpoint)
            setVDeflectionSetpoint(setpoint)
            # approach and measure current baseline
            Scanner.approachPiezo()
            baselineStart = getBaseline()
            # start image scan
            Imaging.startScanning(1)
            # after finishing the entire section scan, retract piezo and update baseline　at the
            # end of the scan to compare how they changed
            Scanner.retractPiezo()
            Scanner.approachPiezo()
            baselineEnd = getBaseline() # not sure if it should be placed after approaching.. ###################
            Scanner.retract()
            
            #increment scan index
            scanIndex += 1
            # write metadata to text file for each scan
            f.write('%d\t%e\t%e\t%e\t%e\t%e\n' % (scanIndex, setpoint, baselineStart, baselineEnd, xOffset, yOffset))
            f.flush()
    
            # Move the scan in the slow scan direction by scanSizeSlow 
            yOffset += scanSizeSlow
    # once finished the entire scan for specific hover mode, let's back to the y offset origin 
    yOffset=yOffset_origin
    Imaging.setScanOffset(xOffset, yOffset)
    
    finally:
        f.close()
    
print('DONE....')
    
    
    
