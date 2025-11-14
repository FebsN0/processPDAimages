import numpy as np
import os
from scipy.ndimage import median_filter, gaussian_filter, binary_opening, binary_fill_holes
from skimage.filters import threshold_sauvola
# Non-interactive: It never opens a window and draws everything directly into a file buffer.
import matplotlib
matplotlib.use('Qt5Agg')
import matplotlib.pyplot as plt
print("---- PYTHON INPUT CHECK ----")

def binarize_stripe_image(image,
                          savepath=None,
                          stripe_size=51, 
                          gauss_sigma=1,
                          sauvola_window=25, 
                          sauvola_k=0.2):
    """
    Binarize an image with vertical stripe artifacts.
    
    Parameters
    ----------
    image : numpy array
        Input image, can be grayscale (H,W) or RGB (H,W,3).
    stripe_size : int
        Width of horizontal median filter used for stripe removal.
    gauss_sigma : float
        Sigma for gaussian smoothing.
    sauvola_window : int
        Window size for Sauvola thresholding.
    sauvola_k : float
        k-parameter for Sauvola thresholding.

    Returns
    -------
    BW : numpy array (dtype=bool)
        Binarized mask.
    corrected : numpy array
        Stripe-corrected grayscale image.
    """
    
    # ------------------------------
    # 1) DIAGNOSTIC CHECK
    # ------------------------------
    print("---- PYTHON INPUT CHECK ----")
    print("Type:", type(image))
    print("Shape:", getattr(image, "shape", None))
    print("Dtype:", getattr(image, "dtype", None))
    print("Savepath:", savepath)
    print("----------------------------")
    # Save diagnostic picture
    if savepath is not None:
        try:
            os.makedirs(savepath, exist_ok=True)  # ensure directory exists
            file_out = os.path.join(savepath, "diagnostic_input.png")

            plt.imshow(image, cmap='gray')
            plt.title("Input image received by Python")
            plt.axis('off')
            plt.savefig(file_out, dpi=200, bbox_inches='tight')
            plt.close()
            print("Diagnostic saved to:", file_out)
        except Exception as e:
            print("Error saving diagnostic image:", e)
    # ------------------------------
    # 2) PRE-PROCESSING: Convert to grayscale if RGB
    # ------------------------------
    if image.ndim == 3:
        gray = image.mean(axis=2)
    else:
        gray = image.astype(float)

    # Estimate vertical stripe background using horizontal median filter
    background = median_filter(gray, size=(1, stripe_size))
    corrected = gray - background
    corrected[corrected < 0] = 0

    # Smooth the corrected image
    smooth = gaussian_filter(corrected, sigma=gauss_sigma)

    # ------------------------------
    # 3) Sauvola thresholding
    # ------------------------------
    T = threshold_sauvola(smooth, window_size=sauvola_window, k=sauvola_k)
    BW = smooth > T

    # 5) Optional morphological cleanup
    BW = binary_opening(BW, structure=np.ones((3, 3)))
    BW = binary_fill_holes(BW)
    print("---- PYTHON BINARIZATION COMPLETED ----")
    print("Type:", type(BW))
    # BW        → numpy.ndarray of dtype bool
    # corrected → numpy.ndarray of dtype float64
    return BW