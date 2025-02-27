# Python code for ExperimentPlanner
# JPK Script
checkVersion('SPM', 6, 4, 32)

# WHAT YOU HAVE TO MODIFY EVERYTIME
# 1) setpointList (expressed in Newton unit)
#       ==> if you want 5 setpoint in 5 sections ==>  [30e-9, 50e-9, 70e-9, 90e-9, 110e-9]        # N
#       ==> if you want 5 setpoint in 10 sections ==> [30e-9, 30e-9, 50e-9, 50e-9, 70e-9, 70e-9, 90e-9, 90e-9, 110e-9, 110e-9]
#       ==> if you want 1 setpoint in 5 sections  ==> [30e-9, 30e-9, 30e-9, 30e-9, 30e-9 ]
# 2) springConstant (N/m)           ==> it is just a reminder. the script doesnt use it. Update when you calibrate
# 3) sensitivity    (nm/V)          ==> it is just a reminder. the script doesnt use it. Update when you calibrate
# 4) array = [<number>]             ==> ONLY TWO POSSIBLE VALUES:
#                                       # 0: HOVER MODE ON
#                                       # 1: HOVER MODE OFF
# scanSizeFast =  values in meter unit (example 50.0e-6  == 50 um)
# fastPixels=     values in pixels (example 512)
# scan_rate=      values in Hertz (example 0.18 Hz)
# baseDirName= <ENTIRE PATH>            where create the directory HOVER MODE <ON/OFF> in which the sections will be saved
#           EXAMPLE: '/home/jpkuser/jpkdata/Jianlu/20240528 Zhu'
#                    '/home/jpkuser/jpkdata/Fabiano/experiments/1_lipidEffects/2_6_2 TRCDA:DMPC/friction_BKonly/7'

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
    print('GET BASELINE = %.2e' % baseline)
    return baseline

'''
Enable/Disable HoverMode
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
Turn On/Turn Off the laser
'''
def setLaserEnable(enable=True):
    instrument = JPKScript.getInstrument()
    dspManager = instrument.getDSPManager()
    dspManager.setLaserEnable(int(enable))

'''
Define a list of setpoints for each section, here in Newton scaling (sensitivity and spring constant activated)
If you have calibrated only the sensitivity value, setpoint must be given in METER, 30 nm = 30e-9
'''
setpointList = [30e-9, 50e-9, 70e-9, 90e-9, 110e-9]  # N
springConstant = 0.405  # N/m
sensitivity = 55.86  # nm/V
array = [1]  # 0: HOVER MODE ON      # 1: HOVER MODE OFF

'''
setup the base direcory for saving data
this will be extended later in the loop to
sort HoverMode ON/OFF scans
'''
baseDirName = '/home/jpkuser/jpkdata/Fabiano/experiments/1_lipidEffects/2_6_2 TRCDA:DMPC/friction_BK_PDAmasking/5'
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
    # define mode Hover Mode
    textToPrint = ["START SCAN 1 HOVER MODE ON", "START SCAN 2 HOVER MODE OFF"]
    textDirectory = ["/HoverMode_ON", "/HoverMode_OFF"]
    conditionHVmode = [True, False]
    # two for cycles (for now only first cycle)
    # Cycle 1 HoverMode ON
    # Cycle 2 HoverMode OFF
    for i in array:
        Imaging.setOutputDirectory(baseDirName + textDirectory[i])
        # check the status of the laser
        if laserOn==False:
            laserOn=True
        # change Hover Mode Status
        enableHoverMode(conditionHVmode[i])
        Scanner.approach()
        Scanner.retractPiezo()
        for setpoint in setpointList:
            print('yOFFSET: %e' % yOffset)
            Imaging.setScanOffset(xOffset, yOffset)
            # Set setpoint
            setVDeflectionSetpoint(setpoint)
            # approach and measure current baseline
            Scanner.approachPiezo()
            baselineStart = getBaseline()
            # start image scan
            Imaging.startScanning(1)
            # after finishing the entire section scan, retract and approach piezo to update baseline　at the
            # end of the scan to compare how they changed
            Scanner.retractPiezo()
            Scanner.approachPiezo()
            baselineEnd = getBaseline()
            Scanner.retractPiezo()

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
    # when the NIKON script will be made, modify the following snippet.
    # The concept is when NIKON script perform all the required fluorescence and BF images which took some time ==> that time is the waiting time
    # the AFM machine is awating before start the HOVER MODE OFF new scan on the same scan spot
    # time.sleep(0.5)

finally:
    dateEnd = datetime.now()
    f.write('\n# End time = %s\n' % dateEnd)
    td = dateEnd - dateStart
    duration_in_s = (td.microseconds + (td.seconds + td.days * 24 * 3600) * 10 ** 6) / 10 ** 6
    duration_in_min = divmod(duration_in_s, 60)[0]
    f.write('# Total time (min)= %d\n' % duration_in_min)
    f.close()
    Scanner.moveMotorsUp(5e-3)

print('DONE....')
