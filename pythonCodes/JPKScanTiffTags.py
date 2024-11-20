# the following python script assumes that the scan in contact mode

from tifffile import TiffFile
import sys


# load the input from MATLAB
tiffFile = TiffFile(sys.argv[1])
pageIdx=sys.argv[2]

if pageIdx == 1:
    # calibration slots of feedback channel (contact mode -> vDelfection) 
    # are stored @page-0
    page0 = tiffFile.pages.get(0)
    tags = page0.tags
    # information are stored as tiff tag ID and they are given as hex value
    # extract feedback information expressed in Volts
    feedbackMode = tags.get(0x8030).value
    scanrate = tags.get(0x8049).value
    baselineAdjust = bool(tags.get(0x8034).value)
    baselineVolts = tags.get(0x8035).value
    absoluteSetpointVolts = tags.get(0x8033).value
    P_Gain = tags.get(0x8031).value
    I_Gain = tags.get(0x8032).value
    # origin axis in meter units
    x_Origin=tags.get(0x8040).value
    y_Origin=tags.get(0x8041).value
    # section lengths in meter units
    x_scan_length=tags.get(0x8042).value # fast direction
    y_scan_length=tags.get(0x8043).value # slow direction
    # section lengths in pixel units
    x_scan_pixels=int(tags.get(0x8046).value) # fast direction
    y_scan_pixels=int(tags.get(0x8047).value) # slow direction
    # Angle of the fast axis measured relative to the x axis, in radians
    scanangle=tags.get(0x8044).value
    
    if not baselineAdjust:
        baselineVolts = 0.
    
    # create a dictionary called metadata where store the previous extracted data ==> first output
    metadata ={
        'scan_rate'         : scanrate,
        'P_Gain'            : P_Gain,
        'I_Gain'            : I_Gain,
        'x_Origin'          : x_Origin,
        'y_Origin'          : y_Origin,
        'x_scan_length'     : x_scan_length,
        'y_scan_length'     : y_scan_length,
        'x_scan_pixels'     : x_scan_pixels,
        'y_scan_pixels'     : y_scan_pixels,
        'scanangle'         : scanangle,
        'FeedbackMode'      : feedbackMode,
        'AbsoluteSetpoint'  : absoluteSetpointVolts,
        'BaselineAdjust'    : baselineAdjust,
        'BaselineV'         : baselineVolts,
    }
    
    # feedback channel for 'contact' mode (vDeflection)
    # can have multile calibration slots (e.g. V, m, N)
    # read all slots into dictionary
    # ATTENTION!!!!
    # there is no guaranty that all slots are available (depending on available calibration)
    # or the slots are given always in the same order
    
    numSlots = tags.get(0x8080).value # previously known as 32896
    slots = {}
    # for each slot (usually "raw -> volts -> distance -> force"), extract the values needed
    # to properly convert raw pixel into desired unit pixel of each channel
    for n in range (numSlots):
        slot = {}
    
        # necessary tags for the slot the origin tag ID is 0x8090, all slots
        # are offseted relative to this origin by n * 0x30
        # for each cycle, n is updated up to numSlots
        slotNameTag = tags.get(0x8090 + n * 0x30)
        encoderNameTag = tags.get(0x80A1 + n * 0x30)
        encoderUnitTag = tags.get(0x80A2 + n * 0x30)
        scalingTypeTag = tags.get(0x80A3 + n * 0x30)
        scalingMultiplyerTag = tags.get(0x80A4 + n * 0x30)
        scalingOffsetTag = tags.get(0x80A5 + n * 0x30)
    
        # the scaling multiplyer and offet are used for converting raw integer 
        # pixel values (image channels) into physical units like [V], [m], [N]...
        # value[unit] = raw * multiplier + offset
    
        # read the final tag values
        # some tags might have a 'None' value which needs to be handled 
        slotName = slotNameTag.value
        encoderName = encoderNameTag.value
        if encoderUnitTag:  
            encoderUnit = encoderUnitTag.value
        else:                   # if empty
            encoderUnit = 'None'
        
        # NullScaling OR LinearScaling
        scalingType = scalingTypeTag.value
        # extract multiplier and offset respectively
        # if None => value = 1 and 0
        # else    => value = multiplier AND offset
        if scalingMultiplyerTag:
            scalingMultiplyer = scalingMultiplyerTag.value
        else:
            scalingMultiplyer = 1.
    
        if scalingOffsetTag:
            scalingOffset = scalingOffsetTag.value
        else:
            scalingOffset = 0.
    
        # append slot to 'slots' dictionary for easier
        # handling
        slots.update({
            slotName: {
                'slotName' : slotName,
                'encoderName' : encoderName,
                'encoderUnit' : encoderUnit,
                'scalingType' : scalingType,
                'scalingMultiplyer' : scalingMultiplyer,
                'scalingOffset' : scalingOffset
            }
        })
    
    
    # find slots 'distance' and 'force' in the 'slots' dictionary
    slotVolts = slots.get('volts')
    slotDistance = slots.get('distance')
    slotForce = slots.get('force')
    
    # recompute the sensitivity [m/v] and spring constant [N/m] as a 
    # ratio of the scaling multipliers V -> Distance and Distance -> Force
    # the scaling offset is not needed to be taken into account!!!!
    if slotVolts and slotDistance and slotForce:
    
        sensitivity = slotDistance.get('scalingMultiplyer') / slotVolts.get('scalingMultiplyer')
        springConstant = slotForce.get('scalingMultiplyer') / slotDistance.get('scalingMultiplyer')
    
        absoluteSetpointForce = absoluteSetpointVolts * sensitivity * springConstant
        baselineForce = baselineVolts * sensitivity * springConstant 
        relativeSetpointForce =  absoluteSetpointForce - baselineForce
        
        metadata.update({
            'sensitivity_m_V' : sensitivity,
            'springConstant_N_m' : springConstant,
            'absoluteSetpointForce_N' : absoluteSetpointForce,
            'BaselineForce_N' : baselineForce,
            'relativeSetpointForce_N' : relativeSetpointForce
        })
else:
    # each page contains data for specific channel
    # es. lateralDeflection in Trace mode is 2nd page
    # es. lateralDeflection in ReTrace mode is 3rd page
    pageI = tiffFile.pages.get(pageIdx-1)
    tags = pageI.tags
    # extract basic info of the i-channel
    ChannelFancyName   = tags.get(0x8052).value         # es Lateral Deflection
    Channel_retrace    = bool(tags.get(0x8051).value)   # es True x Retrace or False x Trace
    if Channel_retrace:
        trace_type_flag = 'Trace'
    else:
        trace_type_flag = 'ReTrace'
    # store basic info
    dataChannel ={
        'Channel_Name' : ChannelFancyName,
        'trace_type_flag' : trace_type_flag
    }

        