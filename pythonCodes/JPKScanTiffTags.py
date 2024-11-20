# the following python script assumes that the scan in contact mode

from tifffile import TiffFile
import sys

def extractSlotsData(tags):
    # data are stored as tiff tag ID, and they are given as hex value

    # feedback channel for 'contact' mode (vDeflection) can have multiple calibration slots 
    # (e.g. V, m, N) ==> read all the slots and store them into a dictionary
    # ATTENTION!!!!
    # There is NO GUARANTY that all slots are available (depending on available calibration
    # and whenever is not available, is defined as "None") or the slots are given always
    # in the same order (usually "raw -> volts -> distance -> force", but it may be scrambled),
    
    # necessary tags for the slot (the origin tag ID is 0x8090) are offseted relative to
    # this origin by n * 0x30 for each cycle, n is updated up to numSlots
    numSlots = tags.get(0x8080).value
    slots = {}
    # to properly convert raw pixel into a desired unit pixel of each channel
    for n in range (numSlots):
        slotNameTag          = tags.get(0x8090 + n * 0x30)
        encoderNameTag       = tags.get(0x80A1 + n * 0x30)       
        encoderUnitTag       = tags.get(0x80A2 + n * 0x30)
        scalingTypeTag       = tags.get(0x80A3 + n * 0x30)
    # the scaling multiplier and offset are used for converting raw integer 
    # pixel values (image channels) into physical units like [V], [m], [N]...
    # NOTE: scalingTypeTag = 'None' | 'NullScaling' (raw) | 'LinearScaling' (volts, etc)
    #           if scalingTypeTag = 'LinearScaling' ==> value[unit] = raw * multiplier + offset,
    # otherwise if scalingTypeTag = 'NullScaling'   ==> value[unit] = raw
        scalingMultiplyerTag = tags.get(0x80A4 + n * 0x30)  
        scalingOffsetTag     = tags.get(0x80A5 + n * 0x30)

        slotName = slotNameTag.value
        # Some tags might have a 'None' value, which needs to be handled; otherwise will result in error
        if encoderNameTag:
            encoderName = encoderNameTag.value
        else:
            encoderName = 'None'        # if empty
        if encoderUnitTag:
            encoderUnit = encoderUnitTag.value
        else:
            encoderUnit = 'None'        # if empty
        if scalingTypeTag:
            scalingType = scalingTypeTag.value
        else:
            scalingType = 'None'        # if empty
        # Extract multiplier and offset, respectively
        if scalingMultiplyerTag:
            scalingMultiplyer = scalingMultiplyerTag.value
        else:
            scalingMultiplyer = 1.      # if empty or raw 
    
        if scalingOffsetTag:
            scalingOffset = scalingOffsetTag.value
        else:
            scalingOffset = 0.          # if empty or raw

        # For each slot, append to the existing slots dictionary object, which store all slots
        slots.update({
            slotName: {
                'slotName'          : slotName,
                'encoderName'       : encoderName,
                'encoderUnit'       : encoderUnit,
                'scalingType'       : scalingType,
                'scalingMultiplyer' : scalingMultiplyer,
                'scalingOffset'     : scalingOffset
            }
        })
    return slots


# upload the inputs from MATLAB
tiffFile = TiffFile(sys.argv[1])
# if page = 1 ==> process metadata
# if page = 2 to last page ==> process each channel metadata
pageIdx=sys.argv[2]
# For some reason a ' char appears together with the uploaded number
pageIdx=int(pageIdx.strip("'"))

# process metadata
if pageIdx == 1:
    # calibration slots of feedback channel (contact mode -> vDelfection) 
    # are stored @page-0
    page0 = tiffFile.pages.get(0)
    tags = page0.tags
    # extract feedback information
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
    # Angle of the fast axis measured relative to the x-axis, in radians
    scanangle=tags.get(0x8044).value
    # if the baseline correction was not active
    if not baselineAdjust:
        baselineVolts = 0.
    
    # create a dictionary called metadata that store the previous extracted data
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
    
    # extract other information to extrapolate vertical parameters to convert volt into force
    slots=extractSlotsData(tags)
    
    # extract the single slot dictionary 'distance' and 'force' from the 'slots' dictionary
    # In case one of them doesn't exist, it will result as 'None'
    slotVolts = slots.get('volts')
    slotDistance = slots.get('distance')
    slotForce = slots.get('force')
    
    # recompute the sensitivity [m/v] and spring constant [N/m] as a 
    # ratio of the scaling multipliers V -> Distance and Distance -> Force
    # The scaling offset does not need to be taken into account!!!!
    # If one of the dictionaries is missing, it is impossible to extract vertical parameters.
    # It is improbable that this will happen.. but still...
    if slotVolts  and slotDistance and slotForce:
    
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
        raise ValueError("One of the slots is missing; it is not possible to extract vertical parameters! Something went wrong in the experiment")
else:
    # Each page contains metadata for a specific channel
    # es. lateralDeflection in Trace mode is 2nd page
    # es. vaerticallDeflection in ReTrace mode is 3rd page

    pageI = tiffFile.pages.get(pageIdx-1)
    tags = pageI.tags
    # extract basic info on the i-channel
    # extract the name of the channel (es Lateral Deflection)
    ChannelFancyName   = tags.get(0x8052).value
    # check if the scan is retrace or trace and make a flag
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
    # Extract multiplier and offset to convert the image into the proper unit from the new dictionaries
    slots=extractSlotsData(tags)
    # In case one of them doesn't exist, it will result as 'None'
    slotRaw = slots.get('raw')
    slotVolts = slots.get('volts')
    slotDistance = slots.get('distance')
    slotForce = slots.get('force')
    slotNominal = slots.get('nominal')          # x Height (measured) channel
    slotCalibrated = slots.get('calibrated')    # x Height            channel
    
    if slotForce and slotDistance and slotVolts:
        if slotForce.get("scalingType") == "LinearScaling":
            multiplier =  slotForce.get("scalingMultiplyer")
            offset =      slotForce.get("scalingOffset")
            type_of_ch = 'Force_N'
        elif slotDistance.get("scalingType") == "LinearScaling":
            multiplier =  slotDistance.get("scalingMultiplyer")
            offset =      slotDistance.get("scalingOffset")
            type_of_ch = 'Distance_m'
        elif slotVolts.get("scalingType") == "LinearScaling":
            multiplier =  slotVolts.get("scalingMultiplyer")
            offset =      slotVolts.get("scalingOffset")
            type_of_ch = 'Volt_V'
        else:
            print('No one slot is available to convert raw data!')
            multiplier = 1
            offset = 0
            type_of_ch = 'Raw'
    elif slotCalibrated and ChannelFancyName == "Height":
        type_of_ch = 'Calibrated'
        multiplier = slotCalibrated.get('scalingMultiplyer')
        offset =   slotCalibrated.get('scalingOffset')
    
    elif slotNominal and ChannelFancyName == "Height (measured)":
            type_of_ch = 'Nomimal'
            multiplier = slotNominal.get('scalingMultiplyer')
            offset =   slotNominal.get('scalingOffset')
    else:
        raise ValueError('No available slots (even raw pixel), something went wrong in the experiment!')

    # add multiplier and offset in the final data
    dataChannel.update({
        'multiplier' : multiplier,
        'offset'     : offset,
        'type_of_ch' : type_of_ch
    })
