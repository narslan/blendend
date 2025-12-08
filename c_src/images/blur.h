#pragma once
#include <blend2d/blend2d.h>

// In-place blur of PRGB32 or A8 images using a 3-pass box approximation of a Gaussian.
// If width/height are <= 0, the full image dimensions are used.
BLResult blur_image_inplace(BLImage& img, double sigma, int width = -1, int height = -1);
