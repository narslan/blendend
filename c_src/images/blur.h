#pragma once
#include <blend2d/blend2d.h>

// In-place blur of PRGB32 or A8 images using a 3-pass box approximation of a Gaussian.
BLResult blur_image_inplace(BLImage& img, double sigma);
