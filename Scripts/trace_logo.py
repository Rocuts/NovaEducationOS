import sys
import numpy as np
try:
    import cv2
except ImportError:
    print("cv2 not installed")
    sys.exit(1)

img = cv2.imread('Assets.xcassets/AppLogo.imageset/logo.png', cv2.IMREAD_UNCHANGED)
if img is None:
    print("Could not load logo")
    sys.exit(1)

height, width = img.shape[:2]
print(f"Loaded logo: {width}x{height}")

# Logo has transparent background and solid colors. 
# We want to trace the outlines. The outlines are dark blue.
# Let's get the alpha channel.
alpha = img[:,:,3]
_, thresh = cv2.threshold(alpha, 127, 255, cv2.THRESH_BINARY)

# Find all contours (external and internal)
contours, hierarchy = cv2.findContours(thresh, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
print(f"Found {len(contours)} contours")

# Approximate contours and print their bounding boxes and number of points
for i, c in enumerate(contours):
    epsilon = 0.005 * cv2.arcLength(c, True)
    approx = cv2.approxPolyDP(c, epsilon, True)
    x, y, w, h = cv2.boundingRect(approx)
    area = cv2.contourArea(approx)
    if area > 100:
        print(f"Contour {i}: x={x}, y={y}, w={w}, h={h}, points={len(approx)}")

