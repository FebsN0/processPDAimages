# Python code for ExperimentPlanner : prepare the scanning area
# JPK Script
checkVersion('SPM', 6, 4, 32)

setpointList = [30e-9, 40e-9, 50e-9, 60e-9, 70e-9, 80e-9, 90e-9]  # N
scanSizeFast = 80.0e-6  # 50 um
scanSizeSlow = scanSizeFast / len(setpointList)
fastPixels = 1024  # 640 for 5 sections ==> 140*5 = 640 pixels
slowPixels = fastPixels / len(setpointList)
scan_rate = 0.18  # Hz

# extract the origin of the scanning
xOffset = Imaging.getXOffset()
yOffset = Imaging.getYOffset()

Imaging.setScanSize(scanSizeFast, scanSizeSlow)
Imaging.setScanPixels(fastPixels, slowPixels)
Imaging.setLineRate(scan_rate)

print('slow scan line numbers: %d' % slowPixels)
print('TOTAL TIME SINGLE SCAN: %f secoconds' % (slowPixels*len(setpointList)/scan_rate))
print('TOTAL TIME SINGLE SCAN: %f minutes' % (slowPixels*len(setpointList)/scan_rate/60))
