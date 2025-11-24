#pragma once
#include <algorithm>
#include <blend2d/blend2d.h>
#include <cmath>
#include <optional>

// ============================================================================
// Cartesian — Defines a coordinate system mapping between mathematical space and
// Blendend canvas pixel coordinates.
//
// A Cartesian describes a continuous "math" region (x_min..x_max, y_min..y_max)
// that will be drawn inside a discrete canvas area (width x height).
// It provides conversion utilities for mapping coordinates back and forth.
//
// Example:
//   Cartesian f(-M_PI, M_PI, -1.0, 1.0, 500, 500);
//   BLPoint p = f.to_canvas(0.0, 1.0);  // -> maps (0, 1) to pixel space
// ============================================================================

struct Cartesian {
  // domain
  double x_min, x_max;
  double y_min, y_max;

  // canvas size (store as double to avoid accidental int division anywhere)
  double width, height;

  // config
  bool flip_y;

  // precomputed scales / inverses
  double sx, sy; // pixels per math unit
  double isx, isy; // math units per pixel

  Cartesian() = default;

  Cartesian(double x_min_,
            double x_max_,
            double y_min_,
            double y_max_,
            int width_,
            int height_,
            bool flip_y_ = true) noexcept
      : x_min(x_min_)
      , x_max(x_max_)
      , y_min(y_min_)
      , y_max(y_max_)
      , width(static_cast<double>(width_))
      , height(static_cast<double>(height_))
      , flip_y(flip_y_)
  {

    const double dx = (x_max - x_min);
    const double dy = (y_max - y_min);
    // guard against degenerate frames (avoid div-by-zero)
    sx = width / (dx != 0.0 ? dx : 1.0);
    sy = height / (dy != 0.0 ? dy : 1.0);
    isx = 1.0 / sx;
    isy = 1.0 / sy;
  }

  void destroy() noexcept { }

  // math -> pixel
  BLPoint to_canvas(double x, double y) const noexcept
  {
    const double px = (x - x_min) * sx;
    const double py = flip_y ? (y_max - y) * sy : (y - y_min) * sy;
    return BLPoint(px, py);
  }

  // pixel -> math (inverse)
  BLPoint to_math(double px, double py) const noexcept
  {
    const double x = x_min + px * isx;
    const double y = flip_y ? (y_max - py * isy) : (y_min + py * isy);
    return BLPoint(x, y);
  }

  BLPoint clamp_to_bounds(double x, double y) const noexcept
  {
    const double cx = std::clamp(x, x_min, x_max);
    const double cy = std::clamp(y, y_min, y_max);
    return BLPoint(cx, cy);
  }

  // Maps a mathematical x-coordinate to the corresponding pixel x-coordinate
  // within the canvas. It interpolates between the frame's x_min/x_max
  // and the pixel range [0, width].
  inline double x_to_canvas(double x) const noexcept
  {
    // Example:
    // if x_min = -10, x_max = 10, width = 500
    // then x = 0 -> 250 px, x = 10 -> 500 px, x = -10 -> 0 px
    return (x - x_min) / (x_max - x_min) * width;
  }

  // Maps a mathematical y-coordinate to the corresponding pixel y-coordinate.
  // Note that the y-axis in image coordinates grows downward, so this function
  // flips the direction.
  inline double y_to_canvas(double y) const noexcept
  {
    // Example:
    // if y_min = -10, y_max = 10, height = 500
    // then y = 0 -> 250 px, y = 10 -> 0 px, y = -10 -> 500 px
    return height - (y - y_min) / (y_max - y_min) * height;
  }

  // Maps a pixel canvas coordinate to the corresponding cartesian x-coordinate.
  inline double canvas_to_x(double px) const noexcept
  {
    return x_min + px / width * (x_max - x_min);
  }

  // Maps a pixel canvas coordinate to the corresponding cartesian y-coordinate.
  inline double canvas_to_y(double py) const noexcept
  {
    return y_min + (height - py) / height * (y_max - y_min);
  }
};

struct CartesianRes {
  Cartesian* cartesian;
  void destroy()
  {
    delete cartesian;
    cartesian = nullptr;
  }
};