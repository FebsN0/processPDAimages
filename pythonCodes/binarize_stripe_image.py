from scipy.ndimage import median_filter, gaussian_filter, binary_opening, binary_fill_holes
import matplotlib
# Non-interactive: It never opens a window and draws everything directly into a file buffer.
matplotlib.use('Qt5Agg')
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider

import numpy as np
import cv2
from skimage import filters, morphology, exposure
from skimage.filters import threshold_sauvola, threshold_niblack, threshold_yen, threshold_li, threshold_triangle, threshold_isodata, threshold_multiotsu
from skimage.segmentation import watershed
from skimage.feature import peak_local_max
from scipy import ndimage as ndi

def binarize_stripe_image(image, methodUser='Otsu', **kwargs):
    """
    Binarize an AFM height image using different methods.

    Parameters:
    - image: 2D numpy array, grayscale AFM height image
    - method: str, binarization method
    - kwargs: additional parameters for specific methods

    Returns:
    - binary: 2D numpy array of dtype bool
    """    

    
    method=methodUser.lower()
    # Ensure image is float
    img = image.astype(np.float32)
    mask = ~np.isnan(img)
    img -= np.nanmin(img)
    img /= np.nanmax(img)  # normalize to 0-1

    # for those who does not accept nan values or masked
    img2 = np.copy(img)
    median_val = np.nanmedian(img)
    img2[np.isnan(img2)] = median_val


    # ------------------------------
    # 3) Find the threshold
    # ------------------------------

    print("-----------------------------------------")
    print("------- BINARIZATION  WITH PYTHON -------")
    print("-----------------------------------------")
    match method:
        case 'sauvola':
            return interactive_threshold_gui(img2, method='Sauvola')
        case 'niblack':
            return interactive_threshold_gui(img2, method='Niblack')
        case 'bradley-roth':
            return interactive_threshold_gui(img2, method='Bradley-Roth')
        case 'otsu':
            # True for valid pixels            
            thresh = filters.threshold_otsu(img2)
            binary = img > thresh     
        case 'multi-otsu':
            classes = kwargs.get('classes', 3)
            thresholds = threshold_multiotsu(img2, classes=classes)
            # Choose highest threshold to separate foreground
            binary = img > thresholds[-1]
        
        case 'adaptive-gaussian':
            block_size = kwargs.get('block_size', 25)
            C = kwargs.get('C', 0)
            binary = cv2.adaptiveThreshold((img2*255).astype(np.uint8), 255,
                                           cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                           cv2.THRESH_BINARY, block_size, C).astype(bool)
        case 'yen':
            thresh = threshold_yen(img2)
            binary = img > thresh
        case 'li':
            thresh = threshold_li(img2)
            binary = img > thresh
        case 'triangle':
            thresh = threshold_triangle(img2)
            binary = img > thresh
        case 'isodata':
            thresh = threshold_isodata(img2)
            binary = img > thresh
        case 'watershed':
            # Use distance transform for watershed
            mask = img2 > filters.threshold_otsu(img2)
            distance = ndi.distance_transform_edt(mask)
            coords = peak_local_max(distance, footprint=np.ones((3, 3)), labels=mask)
            # convert coords → marker image
            markers = np.zeros_like(distance, dtype=int)
            markers[tuple(coords.T)] = np.arange(1, len(coords) + 1)
            labels = watershed(-distance, markers, mask=mask)
            # Combine all non-background labels as foreground
            binary = labels > 0        
        case _:
            raise ValueError(f"Unknown method: {method}")
    return binary
   

def interactive_threshold_gui(image, method='sauvola'):
    """
    Opens an interactive window to tune windowSize and k for Sauvola / Niblack.
    Returns the final binary mask after the user closes the window.
    """
    window_default = 25
    k_default = 0.2 if method in ('Sauvola', 'Bradley-Roth') else -0.2
    match method:
        case 'Sauvola':              
            thresh = threshold_sauvola(image, window_size=window_default, k=k_default)            
        case 'Niblack':                      
            thresh = threshold_niblack(image, window_size=window_default, k=k_default)
        case 'Bradley-Roth':
            mean = cv2.boxFilter(image, ddepth=-1, ksize=(window_default,window_default))
            thresh = mean * (1 - k_default)
    binary = image > thresh
    # --- Build UI ---
    fig, ax = plt.subplots(figsize=(6,10))
    plt.subplots_adjust(left=0.25, bottom=0.25)
    im_handle = ax.imshow(binary, cmap='gray')
    ax.set_title(f"{method.capitalize()} threshold")
    # Sliders
    ax_window = plt.axes([0.25, 0.15, 0.65, 0.03])
    ax_k      = plt.axes([0.25, 0.10, 0.65, 0.03])

    s_window = Slider(ax_window, 'Window', 3, 300, valinit=window_default, valstep=2)
    s_k      = Slider(ax_k, 'k', -3.0, 3.0, valinit=k_default, valstep=0.01)
    # Update function
    def update(val):
        win = int(s_window.val)
        k   = float(s_k.val)

        if method == 'Sauvola':
            t = threshold_sauvola(image, window_size=win, k=k)
        elif 'Niblack':
            t = threshold_niblack(image, window_size=win, k=k)
        else:
            mean = cv2.boxFilter(image, ddepth=-1, ksize=(win,win))
            thresh = mean * (1 - k)
        # update with the new parameters
        new_bin = image > t
        im_handle.set_data(new_bin)
        fig.canvas.draw_idle()
        
    s_window.on_changed(update)
    s_k.on_changed(update)

    # Show the window (user interacts here)
    plt.show()

    # After closing, recompute final binary mask
    win = int(s_window.val)
    k   = float(s_k.val)
    if method == 'Sauvola':
            final_thresh = threshold_sauvola(image, window_size=win, k=k)
    elif 'Niblack':
        final_thresh = threshold_niblack(image, window_size=win, k=k)
    else:
        mean = cv2.boxFilter(image, ddepth=-1, ksize=(win,win))
        final_thresh = mean * (1 - k)
    return (image > final_thresh).astype(np.uint8)