library(rgee)
# ee_reattach() # reattach ee as a reserved word

ee_Initialize()

# Center-pivot Irrigation Detector.
#
# Finds circles that are 500m in radius.
Map$setCenter(-106.06, 37.71, 12)

# A nice NDVI palette.
palette <- c(
  "FFFFFF", "CE7E45", "DF923D", "F1B555", "FCD163", "99B718",
  "74A901", "66A000", "529400", "3E8601", "207401", "056201",
  "004C00", "023B01", "012E01", "011D01", "011301"
)

# Just display the image with the palette.
image <- ee$Image("LANDSAT/LC08/C01/T1_TOA/LC08_034034_20170608")
ndvi <- image$normalizedDifference(c("B5", "B4"))
vizParams <- list(min = 0, max = 1, palette = palette)
Map$addLayer(ndvi, vizParams, "Landsat NDVI")

# Find the difference between convolution with circles and squares.
# This difference, in theory, will be strongest at the center of
# circles in the image. This region is filled with circular farms
# with radii on the order of 500m.
farmSize <- 500 # Radius of a farm, in meters.
circleKernel <- ee$Kernel$circle(farmSize, "meters")
squareKernel <- ee$Kernel$square(farmSize, "meters")
circles <- ndvi$convolve(circleKernel)
squares <- ndvi$convolve(squareKernel)
diff <- circles$subtract(squares)

# Scale by 100 and find the best fitting pixel in each neighborhood.
diff <- diff$abs()$multiply(100)$toByte()
max <- diff$focal_max(radius = farmSize * 1.8, units = "meters")
# If a pixel isn't the local max, set it to 0.
local <- diff$where(diff$neq(max), 0)
thresh <- local$gt(2)

# Here, we highlight the maximum differences as "Kernel Peaks"
# and draw them in red.
peaks <- thresh$focal_max(kernel = circleKernel)
Map$addLayer(peaks$updateMask(peaks), list(palette = "FF3737"), "Kernel Peaks")

# Detect the edges of the features.  Discard the edges with lower intensity.
canny <- ee$Algorithms$CannyEdgeDetector(ndvi, 0)
canny <- canny$gt(0.3)

# Create a "ring" kernel from two circular kernels.
inner <- ee$Kernel$circle(farmSize - 20, "meters", FALSE, -1)
outer <- ee$Kernel$circle(farmSize + 20, "meters", FALSE, 1)
ring <- outer$add(inner, TRUE)

# Highlight the places where the feature edges best match the circle kernel.
centers <- canny$convolve(ring)$gt(0.5)$focal_max(kernel = circleKernel)
Map$addLayer(
  centers$updateMask(centers),
  list(palette = "4285FF"),
  "Ring centers"
)
