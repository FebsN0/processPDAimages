from tifffile import TiffFile

tiffFile = TiffFile('1_save-2024.11.11-06.52.27.386 - Copy.jpk')

'''
# list all available tag of all pages
for page in tiffFile.pages:
    for tag in page.tags:
        tagID = None
        tagName = None
        try:
            tagID = int(tag.name)
            tagName = None
        except:
            tagID = None
            tagName = tag.name

        idString = ''
        if tagID:
            idString = ('%d (%s)' % (tagID, hex(tagID))).upper()
        else:
            idString = tagName
        print('Page %d \t|\t TagID: %s\t|\t Value: %s' % (page.index, idString, str(tag.value)))
    print('\n--------------------------------------------------------------------------------------\n')
'''

# calibration slots of feedback channel (contact mode -> vDelfection) 
# are stored @page-0
page0 = tiffFile.pages.get(0)
tags = page0.tags

feedbackMode = tags.get(0x8030).value
baselineAdjust = bool(tags.get(0x8034).value)
baselineVolts = tags.get(0x8035).value
absoluteSetpointVolts = tags.get(0x8033).value

if not baselineAdjust:
    baselineVolts = 0.

print('FeedbackMode = %s' % feedbackMode)
print('Absolute Setpoint = %.3f V' % absoluteSetpointVolts)
print('BaselineAdjust = %s' % baselineAdjust)
print('Baseline = %.3f [V]' % baselineVolts)

# feedback channel for 'contact' mode (vDeflection)
# can have multile calibration slots (e.g. V, m, N)
# read all slots into dictionary
# ATTENTION!!!!
# there is no guaranty that all slots are available (depending on available calibration)
# or the slots are given always in the same order

numSlots = tags.get(0x8080).value
slots = {}
for n in range (numSlots):
    slot = {}

    # necessary tags for the slot
    # the origin tag ID is 0x8090, all slots are offseted 
    # relative to this origin by n * 0x30

    slotNameTag = tags.get(0x8090 + n * 0x30)
    encoderNameTag = tags.get(0x80A1 + n * 0x30)
    encoderUnitTag = tags.get(0x80A2 + n * 0x30)
    scalingTypeTag = tags.get(0x80A3 + n * 0x30)
    scalingMultiplyerTag = tags.get(0x80A4 + n * 0x30)
    scalingOffsetTag = tags.get(0x80A5 + n * 0x30)

    # the sacling multiplyer and offet are used for converting raw integer 
    # pixel values (image channels) into physical units like [V], [m], [N]...
    # value[unit] = raw * multiplier + offset

    # read the final tag values
    # some tags might have a 'None' value which needs to be handled 
    slotName = slotNameTag.value
    encoderName = encoderNameTag.value
    if encoderUnitTag:
        encoderUnit = encoderUnitTag.value
    else:
        encoderUnit = 'None'
    scalingType = scalingTypeTag.value
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

print('\nAVAILABLE FEEDBACK CHANNEL CALIBRATION SLOTS: %s' % slots)

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

    print('')

    print('sensitivity = %.3f nm/V' % (sensitivity / 1e-9 ))
    print('springConstant = %.3f N/m' % springConstant)

    absoluteSetpointForce = absoluteSetpointVolts * sensitivity * springConstant
    baselineForce = baselineVolts * sensitivity * springConstant 

    relativeSetpointForce =  absoluteSetpointForce - baselineForce

    print('')

    print('Absolute Setpoint = %.3f [nN]' % (absoluteSetpointForce / 1e-9))
    print('Baseline = %.f [nN]' % (baselineForce / 1e-9))
    print('Relative Setpoint = %.3f [nN]' % (relativeSetpointForce / 1e-9))


