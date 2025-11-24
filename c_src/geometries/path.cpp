#include "path.h"
#include "../canvas/canvas.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"
#include "../styles/styles.h"
#include "matrix2d.h"

#include <blend2d/core/path.h>
#include <cmath>
#include <cstring>

template <>
const char* NifResource<Path>::resource_name = "Path";

// -----------------------------------------------------------------------------
// 2) path_new/0  → {:ok, path_resource}
// -----------------------------------------------------------------------------

ERL_NIF_TERM
path_new(ErlNifEnv* env, int argc, [[maybe_unused]] const ERL_NIF_TERM argv[])
{
  if(argc != 0) {
    return enif_make_badarg(env);
  }

  auto res = NifResource<Path>::alloc();
  // BLPath is default-constructed as part of Path; no heap alloc needed.

  return make_result_ok(env, NifResource<Path>::make(env, res));
}

bool cmd_from_term(ErlNifEnv* env, ERL_NIF_TERM term, uint32_t* out)
{
  char atom[32];
  if(!enif_get_atom(env, term, atom, sizeof(atom), ERL_NIF_UTF8)) {
    return false;
  }

  if(std::strcmp(atom, "move_to") == 0) {
    *out = BL_PATH_CMD_MOVE;
    return true;
  }
  if(std::strcmp(atom, "line_to") == 0) {
    *out = BL_PATH_CMD_ON;
    return true;
  }
  if(std::strcmp(atom, "quad_to") == 0) {
    *out = BL_PATH_CMD_QUAD;
    return true;
  }
  if(std::strcmp(atom, "cubic_to") == 0) {
    *out = BL_PATH_CMD_CUBIC;
    return true;
  }
  if(std::strcmp(atom, "conic_to") == 0) {
    *out = BL_PATH_CMD_CONIC;
    return true;
  }
  if(std::strcmp(atom, "weight") == 0) {
    *out = BL_PATH_CMD_WEIGHT;
    return true;
  }
  if(std::strcmp(atom, "close") == 0) {
    *out = BL_PATH_CMD_CLOSE;
    return true;
  }
  if(std::strcmp(atom, "preserve") == 0) {
    *out = BL_PATH_CMD_PRESERVE;
    return true;
  }

  return false;
}
// -----------------------------------------------------------------------------
// 4) path_vertex_count(path) → integer
// -----------------------------------------------------------------------------

ERL_NIF_TERM path_vertex_count(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "invalid_path_resource");
  }

  return make_result_ok(env, enif_make_uint(env, path->value.size()));
}

// -----------------------------------------------------------------------------
// 5) path_set_vertex_at(path, index, cmd, x, y)
// -----------------------------------------------------------------------------

ERL_NIF_TERM path_set_vertex_at(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 5) {
    return enif_make_badarg(env);
  }

  unsigned idx;
  uint32_t cmd;
  double x, y;

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "invalid_path_set_vertex_at_resource");
  }

  if(!enif_get_uint(env, argv[1], &idx) || !cmd_from_term(env, argv[2], &cmd) ||
     !enif_get_double(env, argv[3], &x) || !enif_get_double(env, argv[4], &y)) {
    return make_result_error(env, "invalid_path_set_vertex_at_args");
  }

  BLPathView view = path->value.view();

  if(idx >= view.size)
    return make_result_error(env, "path_set_vertex_index_out_of_range");

  BLResult r = path->value.set_vertex_at(idx, cmd, BLPoint(x, y));

  if(r != BL_SUCCESS)
    return make_result_error(env, "path_set_vertex_failed");

  return enif_make_atom(env, "ok");
}

// path_shrink(path) -> :ok | {:error, reason}
ERL_NIF_TERM path_shrink(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "invalid_path_resource");
  }

  BLResult r = path->value.shrink();
  if(r != BL_SUCCESS)
    return make_result_error(env, "path_shrink_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_fill_path(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc < 2) {
    return enif_make_badarg(env);
  }

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "fill_path_invalid_canvas");
  }

  auto path = NifResource<Path>::get(env, argv[1]);
  if(path == nullptr) {
    return make_result_error(env, "fill_path_invalid_path");
  }

  // optional style in argv[2], like the rest of your code
  if(argc == 3 && enif_is_list(env, argv[2])) {
    Style style;
    parse_style(env, argv, argc, 2, &style);
    canvas->ctx.save();
    style.apply(&canvas->ctx);
    BLResult r = canvas->ctx.fill_path(path->value);
    canvas->ctx.restore();

    if(r != BL_SUCCESS)
      return make_result_error(env, "fill_path_failed");

    return enif_make_atom(env, "ok");
  }
  else {
    BLResult r = canvas->ctx.fill_path(path->value);
    if(r != BL_SUCCESS)
      return make_result_error(env, "fill_path_failed");
    return enif_make_atom(env, "ok");
  }
}

ERL_NIF_TERM canvas_stroke_path(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc < 2) {
    return enif_make_badarg(env);
  }

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "stroke_path_invalid_canvas");
  }

  auto path = NifResource<Path>::get(env, argv[1]);
  if(path == nullptr) {
    return make_result_error(env, "stroke_path_invalid_path");
  }

  // with style
  if(argc == 3 && enif_is_list(env, argv[2])) {
    Style style;
    // your existing helper
    parse_style(env, argv, argc, 2, &style);

    canvas->ctx.save();
    style.apply(&canvas->ctx);

    BLResult r = canvas->ctx.stroke_path(path->value);

    canvas->ctx.restore();

    if(r != BL_SUCCESS)
      return make_result_error(env, "stroke_path_failed");

    return enif_make_atom(env, "ok");
  }
  else {
    // no style → just stroke with whatever is currently set on the context
    BLResult r = canvas->ctx.stroke_path(path->value);
    if(r != BL_SUCCESS)
      return make_result_error(env, "stroke_path_failed");
    return enif_make_atom(env, "ok");
  }
}

ERL_NIF_TERM path_debug_dump(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "path_debug_dump_invalid_resource");
  }

  BLPathView view = path->value.view();
  enif_fprintf(stderr, "[path_debug_dump] path size = %u\n", view.size);

  unsigned limit = view.size < 200 ? view.size : 200;
  for(unsigned i = 0; i < limit; ++i) {
    uint8_t cmd = view.command_data[i];
    const BLPoint& pt = view.vertex_data[i];
    enif_fprintf(stderr, "  [%3u] cmd=%u x=%f y=%f\n", i, (unsigned)cmd, pt.x, pt.y);
  }

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM path_vertex_at(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  unsigned idx = 0;

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "path_vertex_at_invalid_path");
  }

  if(!enif_get_uint(env, argv[1], &idx)) {
    return make_result_error(env, "path_vertex_at_invalid_index");
  }

  BLPathView view = path->value.view();

  if(idx >= view.size) {
    return make_result_error(env, "path_vertex_at_invalid_index");
  }
  const uint8_t cmd = view.command_data[idx];
  const BLPoint& pt = view.vertex_data[idx];

  ERL_NIF_TERM cmd_term;
  ERL_NIF_TERM x_term;
  ERL_NIF_TERM y_term;

  switch(cmd) {
  case BL_PATH_CMD_MOVE:
    cmd_term = enif_make_atom(env, "move_to");
    x_term = enif_make_double(env, pt.x);
    y_term = enif_make_double(env, pt.y);
    break;

  case BL_PATH_CMD_ON: // line-to
    cmd_term = enif_make_atom(env, "line_to");
    x_term = enif_make_double(env, pt.x);
    y_term = enif_make_double(env, pt.y);
    break;

  case BL_PATH_CMD_QUAD:
    cmd_term = enif_make_atom(env, "quad_to");
    x_term = enif_make_double(env, pt.x);
    y_term = enif_make_double(env, pt.y);
    break;

  case BL_PATH_CMD_CONIC:
    cmd_term = enif_make_atom(env, "conic_to");
    x_term = enif_make_double(env, pt.x);
    y_term = enif_make_double(env, pt.y);
    break;

  case BL_PATH_CMD_CUBIC:
    cmd_term = enif_make_atom(env, "cubic_to");
    x_term = enif_make_double(env, pt.x);
    y_term = enif_make_double(env, pt.y);
    break;

  case BL_PATH_CMD_WEIGHT:
    cmd_term = enif_make_atom(env, "weight");
    x_term = enif_make_double(env, pt.x);
    //y term has no meaning here, Blend2D sets it NaN
    y_term = enif_make_double(env, 0.0);
    break;

  case BL_PATH_CMD_CLOSE: {

    // For CLOSE, Blend2D doesn't guarantee a meaningful vertex.
    // Easiest fix: reuse previous point (or 0,0 if this is the first).
    double sx = 0.0;
    double sy = 0.0;
    if(idx > 0) {
      const BLPoint& prev = view.vertex_data[idx - 1];
      sx = prev.x;
      sy = prev.y;
    }
    cmd_term = enif_make_atom(env, "close");
    x_term = enif_make_double(env, sx);
    y_term = enif_make_double(env, sy);
    break;
  }

  default:
    // unknown command -> still return *something* valid
    cmd_term = enif_make_atom(env, "unknown");
    x_term = enif_make_double(env, 0.0);
    y_term = enif_make_double(env, 0.0);
    break;
  }

  return make_result_ok(env, enif_make_tuple3(env, cmd_term, x_term, y_term));
}

ERL_NIF_TERM path_move_to(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc != 3)
    return enif_make_badarg(env);

  double x, y;

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "path_move_to_invalid_path");
  }

  if(!enif_get_double(env, argv[1], &x) || !enif_get_double(env, argv[2], &y)) {
    return make_result_error(env, "path_move_to_invalid_coords");
  }

  BLResult r = path->value.move_to(x, y);
  if(r != BL_SUCCESS)
    return make_result_error(env, "move_to_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM path_line_to(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc != 3) {
    return enif_make_badarg(env);
  }

  double x, y;

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "path_line_to_invalid_path");
  }

  if(!enif_get_double(env, argv[1], &x) || !enif_get_double(env, argv[2], &y)) {
    return make_result_error(env, "path_line_to_invalid_coords");
  }

  BLResult r = path->value.line_to(x, y);
  if(r != BL_SUCCESS)
    return make_result_error(env, "path_line_to_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM path_arc_quadrant_to(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 5) {
    return enif_make_badarg(env);
  }

  double x1, y1, x2, y2;

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "path_arc_quadrant_invalid_path");
  }

  if(!enif_get_double(env, argv[1], &x1) || !enif_get_double(env, argv[2], &y1) ||
     !enif_get_double(env, argv[3], &x2) || !enif_get_double(env, argv[4], &y2)) {
    return make_result_error(env, "path_arc_quadrant_invalid_coord");
  }

  BLResult r = path->value.arc_quadrant_to(x1, y1, x2, y2);
  if(r != BL_SUCCESS)
    return make_result_error(env, "arc_quadrant_to_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM path_add_circle(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 4) {
    return enif_make_badarg(env);
  }

  double cx, cy, r;

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "path_add_circle_invalid_path");
  }

  if(!enif_get_double(env, argv[1], &cx) || !enif_get_double(env, argv[2], &cy) ||
     !enif_get_double(env, argv[3], &r)) {
    return make_result_error(env, "path_add_circle_invalid_coords");
  }

  BLCircle c(cx, cy, r);

  BLResult rc = path->value.add_circle(c);
  if(rc != BL_SUCCESS)
    return make_result_error(env, "add_circle_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM path_close(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "path_close_invalid_path");
  }

  BLResult r = path->value.close();
  if(r != BL_SUCCESS)
    return make_result_error(env, "close_failed");

  return enif_make_atom(env, "ok");
}

// path_quad_to(PathRes, x1, y1, x2, y2)
ERL_NIF_TERM path_quad_to(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 5) {
    return enif_make_badarg(env);
  }

  double x1, y1, x2, y2;

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "path_quad_to_invalid_path");
  }

  if(!enif_get_double(env, argv[1], &x1) || !enif_get_double(env, argv[2], &y1) ||
     !enif_get_double(env, argv[3], &x2) || !enif_get_double(env, argv[4], &y2)) {
    return make_result_error(env, "path_quad_to_invalid_args");
  }

  BLResult r = path->value.quad_to(x1, y1, x2, y2);
  if(r != BL_SUCCESS)
    return make_result_error(env, "quad_to_failed");

  return enif_make_atom(env, "ok");
}

// -----------------------------------------------------------------------------
// conic_to(path, x1, y1, x2, y2, w)
// -----------------------------------------------------------------------------
ERL_NIF_TERM path_conic_to(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc != 6)
    return enif_make_badarg(env);

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "conic_to_args_invalid_path");
  }

  double x1, y1, x2, y2, w;

  if(!enif_get_double(env, argv[1], &x1) || !enif_get_double(env, argv[2], &y1) ||
     !enif_get_double(env, argv[3], &x2) || !enif_get_double(env, argv[4], &y2) ||
     !enif_get_double(env, argv[5], &w)) {
    return make_result_error(env, "invalid_conic_to_args");
  }

  BLResult r = path->value.conic_to(x1, y1, x2, y2, w);
  if(r != BL_SUCCESS)
    return make_result_error(env, "conic_to_failed");

  return enif_make_atom(env, "ok");
}

// -----------------------------------------------------------------------------
// smooth_quad_to(path, x2, y2)
// -----------------------------------------------------------------------------
ERL_NIF_TERM path_smooth_quad_to(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc != 3)
    return enif_make_badarg(env);

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "path_smooth_quad_to_invalid_path");
  }
  double x2, y2;

  if(!enif_get_double(env, argv[1], &x2) || !enif_get_double(env, argv[2], &y2)) {
    return make_result_error(env, "invalid_smooth_quad_to_args");
  }

  BLResult r = path->value.smooth_quad_to(x2, y2);
  if(r != BL_SUCCESS)
    return make_result_error(env, "smooth_quad_to_failed");

  return enif_make_atom(env, "ok");
}

// -----------------------------------------------------------------------------
// smooth_cubic_to(path, x2, y2, x3, y3)
// -----------------------------------------------------------------------------
ERL_NIF_TERM path_smooth_cubic_to(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc != 5)
    return enif_make_badarg(env);

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "invalid_smooth_cubic_to_path");
  }
  double x2, y2, x3, y3;

  if(!enif_get_double(env, argv[1], &x2) || !enif_get_double(env, argv[2], &y2) ||
     !enif_get_double(env, argv[3], &x3) || !enif_get_double(env, argv[4], &y3)) {
    return make_result_error(env, "invalid_smooth_cubic_to_args");
  }

  BLResult r = path->value.smooth_cubic_to(x2, y2, x3, y3);
  if(r != BL_SUCCESS)
    return make_result_error(env, "smooth_cubic_to_failed");

  return enif_make_atom(env, "ok");
}

// -----------------------------------------------------------------------------
// arc_to(path, cx, cy, rx, ry, start, sweep, force_move_to)
// -----------------------------------------------------------------------------
ERL_NIF_TERM path_arc_to(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc != 8)
    return enif_make_badarg(env);

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "invalid_arc_to_path");
  }

  double cx, cy, rx, ry, start, sweep;
  bool forceMove = false;

  if(!enif_get_double(env, argv[1], &cx) || !enif_get_double(env, argv[2], &cy) ||
     !enif_get_double(env, argv[3], &rx) || !enif_get_double(env, argv[4], &ry) ||
     !enif_get_double(env, argv[5], &start) || !enif_get_double(env, argv[6], &sweep)) {
    return make_result_error(env, "invalid_arc_to_args");
  }

  ERL_NIF_TERM t_true = enif_make_atom(env, "true");
  ERL_NIF_TERM t_false = enif_make_atom(env, "false");

  if(enif_is_identical(argv[7], t_true))
    forceMove = true;
  else if(enif_is_identical(argv[7], t_false))
    forceMove = false;
  else
    return make_result_error(env, "invalid_arc_to_force_flag");

  BLResult r = path->value.arc_to(cx, cy, rx, ry, start, sweep, forceMove);
  if(r != BL_SUCCESS)
    return make_result_error(env, "arc_to_failed");

  return enif_make_atom(env, "ok");
}

// -----------------------------------------------------------------------------
// elliptic_arc_to(path, rx, ry, xAxisRotation, large_arc_flag, sweep_flag, x1, y1)
// SVG-style endpoint-based elliptical arc.
// -----------------------------------------------------------------------------
ERL_NIF_TERM path_elliptic_arc_to(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 8)
    return enif_make_badarg(env);

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "invalid_eliptic_arc_to_path");
  }

  double rx, ry, xAxisRotation, x1, y1;
  bool largeArcFlag = false;
  bool sweepFlag = false;

  if(!enif_get_double(env, argv[1], &rx) || !enif_get_double(env, argv[2], &ry) ||
     !enif_get_double(env, argv[3], &xAxisRotation) || !enif_get_double(env, argv[6], &x1) ||
     !enif_get_double(env, argv[7], &y1)) {
    return make_result_error(env, "invalid_elliptic_arc_to_args");
  }

  ERL_NIF_TERM t_true = enif_make_atom(env, "true");
  ERL_NIF_TERM t_false = enif_make_atom(env, "false");

  if(enif_is_identical(argv[4], t_true))
    largeArcFlag = true;
  else if(enif_is_identical(argv[4], t_false))
    largeArcFlag = false;
  else
    return make_result_error(env, "invalid_elliptic_large_arc_flag");

  if(enif_is_identical(argv[5], t_true))
    sweepFlag = true;
  else if(enif_is_identical(argv[5], t_false))
    sweepFlag = false;
  else
    return make_result_error(env, "invalid_elliptic_sweep_flag");

  BLResult r = path->value.elliptic_arc_to(rx, ry, xAxisRotation, largeArcFlag, sweepFlag, x1, y1);

  if(r != BL_SUCCESS)
    return make_result_error(env, "elliptic_arc_to_failed");

  return enif_make_atom(env, "ok");
}

// path_cubic_to(PathRes, x1, y1, x2, y2, x3, y3)
ERL_NIF_TERM path_cubic_to(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc != 7) {
    return enif_make_badarg(env);
  }

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "invalid_cubic_to_path");
  }
  double x1, y1, x2, y2, x3, y3;

  if(!enif_get_double(env, argv[1], &x1) || !enif_get_double(env, argv[2], &y1) ||
     !enif_get_double(env, argv[3], &x2) || !enif_get_double(env, argv[4], &y2) ||
     !enif_get_double(env, argv[5], &x3) || !enif_get_double(env, argv[6], &y3)) {
    return make_result_error(env, "path_cubic_to_invalid_args");
  }

  BLResult r = path->value.cubic_to(x1, y1, x2, y2, x3, y3);
  if(r != BL_SUCCESS)
    return make_result_error(env, "cubic_to_failed");

  return enif_make_atom(env, "ok");
}

// path_hit_test(PathRes, x, y)
// path_hit_test(PathRes, x, y, FillRule)
ERL_NIF_TERM path_hit_test(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc < 3) {
    return enif_make_badarg(env);
  }

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "invalid_path_hit_test_path");
  }
  double x, y;

  if(!enif_get_double(env, argv[1], &x) || !enif_get_double(env, argv[2], &y)) {
    return make_result_error(env, "path_hit_test_invalid_args");
  }

  BLFillRule fill_rule = BL_FILL_RULE_NON_ZERO;

  if(argc == 4) {
    char rule_atom[32];
    if(!enif_get_atom(env, argv[3], rule_atom, sizeof(rule_atom), ERL_NIF_UTF8)) {
      return make_result_error(env, "path_hit_test_invalid_fill_rule_atom");
    }

    if(std::strcmp(rule_atom, "non_zero") == 0 || std::strcmp(rule_atom, "nonzero") == 0) {
      fill_rule = BL_FILL_RULE_NON_ZERO;
    }
    else if(std::strcmp(rule_atom, "even_odd") == 0 || std::strcmp(rule_atom, "evenodd") == 0) {
      fill_rule = BL_FILL_RULE_EVEN_ODD;
    }
    else {
      return make_result_error(env, "invalid_fill_rule");
    }
  }

  BLHitTest ht = path->value.hit_test(BLPoint(x, y), fill_rule);

  ERL_NIF_TERM res_atom;
  switch(ht) {
  case BL_HIT_TEST_IN:
    res_atom = enif_make_atom(env, "in");
    break;
  case BL_HIT_TEST_PART:
    res_atom = enif_make_atom(env, "part");
    break;
  case BL_HIT_TEST_OUT:
    res_atom = enif_make_atom(env, "out");
    break;
  case BL_HIT_TEST_INVALID:
  default:
    res_atom = enif_make_atom(env, "invalid");
    break;
  }

  return make_result_ok(env, res_atom);
}

ERL_NIF_TERM path_clear(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "path_clear_invalid_path");
  }

  path->value.clear();
  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM path_equals(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2) {
    return enif_make_badarg(env);
  }

  auto a = NifResource<Path>::get(env, argv[0]);
  auto b = NifResource<Path>::get(env, argv[1]);
  if(a == nullptr || b == nullptr) {
    return make_result_error(env, "path_equals_invalid_path");
  }

  bool eq = a->value.equals(b->value);
  return eq ? enif_make_atom(env, "true") : enif_make_atom(env, "false");
}

ERL_NIF_TERM path_fit_to(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2) {
    return enif_make_badarg(env);
  }

  auto path = NifResource<Path>::get(env, argv[0]);
  if(path == nullptr) {
    return make_result_error(env, "invalid_fit_to_path");
  }

  // Expect {X, Y, W, H}
  const ERL_NIF_TERM* rect_tpl;
  int arity;
  if(!enif_get_tuple(env, argv[1], &arity, &rect_tpl) || arity != 4) {
    return make_result_error(env, "invalid_path_fit_to_rectangle");
  }

  double x, y, w, h;
  if(!enif_get_double(env, rect_tpl[0], &x) || !enif_get_double(env, rect_tpl[1], &y) ||
     !enif_get_double(env, rect_tpl[2], &w) || !enif_get_double(env, rect_tpl[3], &h)) {
    return make_result_error(env, "path_fit_to_invalid_rectangle");
  }

  BLRect rect(x, y, w, h);

  BLResult r = path->value.fit_to(rect, 0u); // fit_flags unused

  if(r != BL_SUCCESS)
    return make_result_error(env, "path_fit_to_failed");

  return enif_make_atom(env, "ok");
}

// path_add_path(dst, src)
ERL_NIF_TERM path_add_path(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  auto dst = NifResource<Path>::get(env, argv[0]);
  auto src = NifResource<Path>::get(env, argv[1]);
  if(dst == nullptr || src == nullptr) {
    return make_result_error(env, "invalid_add_path_resources");
  }

  BLResult r = dst->value.add_path(src->value);
  if(r != BL_SUCCESS)
    return make_result_error(env, "add_path_failed");

  return enif_make_atom(env, "ok");
}

// path_add_path_transform(dst, src, matrix)
ERL_NIF_TERM path_add_path_transform(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc != 3)
    return enif_make_badarg(env);

  auto dst = NifResource<Path>::get(env, argv[0]);
  auto src = NifResource<Path>::get(env, argv[1]);
  auto m = NifResource<Matrix2D>::get(env, argv[2]);

  if(dst == nullptr || src == nullptr || m == nullptr) {
    return make_result_error(env, "invalid_add_path_transform_resources");
  }

  BLResult r = dst->value.add_path(src->value, m->value);
  if(r != BL_SUCCESS)
    return make_result_error(env, "add_path_transform_failed");

  return enif_make_atom(env, "ok");
}

// Path flatten
static BL_INLINE BLPoint mix(const BLPoint& a, const BLPoint& b, double t) noexcept
{
  return BLPoint(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
}

static double quadFlatness(const BLPoint& p0, const BLPoint& p1, const BLPoint& p2) noexcept
{
  // distance of control point from line p0-p2
  double ux = p2.x - p0.x;
  double uy = p2.y - p0.y;
  double vx = p1.x - p0.x;
  double vy = p1.y - p0.y;

  double area2 = std::abs(ux * vy - uy * vx);
  double len = std::sqrt(ux * ux + uy * uy);
  return len > 0.0 ? area2 / len : 0.0;
}

static double
cubicFlatness(const BLPoint& p0, const BLPoint& p1, const BLPoint& p2, const BLPoint& p3) noexcept
{
  double ux = p3.x - p0.x;
  double uy = p3.y - p0.y;
  double len = std::sqrt(ux * ux + uy * uy);
  if(len == 0.0)
    return 0.0;

  auto dist = [&](const BLPoint& p) {
    double vx = p.x - p0.x;
    double vy = p.y - p0.y;
    double area2 = std::abs(ux * vy - uy * vx);
    return area2 / len;
  };

  return std::max(dist(p1), dist(p2));
}

static void flattenQuadRecursive(
    BLPath& dst, const BLPoint& p0, const BLPoint& p1, const BLPoint& p2, double tol)
{
  if(quadFlatness(p0, p1, p2) <= tol) {
    dst.line_to(p2);
    return;
  }

  BLPoint p01 = mix(p0, p1, 0.5);
  BLPoint p12 = mix(p1, p2, 0.5);
  BLPoint p012 = mix(p01, p12, 0.5);

  flattenQuadRecursive(dst, p0, p01, p012, tol);
  flattenQuadRecursive(dst, p012, p12, p2, tol);
}

static void flattenCubicRecursive(BLPath& dst,
                                  const BLPoint& p0,
                                  const BLPoint& p1,
                                  const BLPoint& p2,
                                  const BLPoint& p3,
                                  double tol)
{
  if(cubicFlatness(p0, p1, p2, p3) <= tol) {
    dst.line_to(p3);
    return;
  }

  BLPoint p01 = mix(p0, p1, 0.5);
  BLPoint p12 = mix(p1, p2, 0.5);
  BLPoint p23 = mix(p2, p3, 0.5);

  BLPoint p012 = mix(p01, p12, 0.5);
  BLPoint p123 = mix(p12, p23, 0.5);
  BLPoint p0123 = mix(p012, p123, 0.5);

  flattenCubicRecursive(dst, p0, p01, p012, p0123, tol);
  flattenCubicRecursive(dst, p0123, p123, p23, p3, tol);
}

static BLResult flattenPath(const BLPath& src, BLPath& dst, double tol)
{
  dst.clear();

  size_t n = src.size();
  const uint8_t* cmdData = src.command_data();
  const BLPoint* vtxData = src.vertex_data();

  BLPoint lastOn(0.0, 0.0);
  BLPoint subStart(0.0, 0.0);
  bool hasSub = false;

  for(size_t i = 0; i < n; ++i) {
    uint8_t cmd = cmdData[i];
    const BLPoint& v = vtxData[i];

    switch(cmd) {
    case BL_PATH_CMD_MOVE: {
      dst.move_to(v);
      lastOn = v;
      subStart = v;
      hasSub = true;
      break;
    }

    case BL_PATH_CMD_ON: {
      dst.line_to(v);
      lastOn = v;
      break;
    }

    case BL_PATH_CMD_QUAD: {
      if(i + 1 >= n || cmdData[i + 1] != BL_PATH_CMD_ON)
        return BL_ERROR_INVALID_STATE;

      const BLPoint& p1 = vtxData[i]; // control
      const BLPoint& p2 = vtxData[i + 1]; // end

      flattenQuadRecursive(dst, lastOn, p1, p2, tol);
      lastOn = p2;
      i += 1;
      break;
    }

    case BL_PATH_CMD_CUBIC: {
      if(i + 2 >= n || cmdData[i + 1] != BL_PATH_CMD_CUBIC || cmdData[i + 2] != BL_PATH_CMD_ON)
        return BL_ERROR_INVALID_STATE;

      const BLPoint& p1 = vtxData[i];
      const BLPoint& p2 = vtxData[i + 1];
      const BLPoint& p3 = vtxData[i + 2];

      flattenCubicRecursive(dst, lastOn, p1, p2, p3, tol);
      lastOn = p3;
      i += 2;
      break;
    }

    case BL_PATH_CMD_CLOSE: {
      if(hasSub) {
        dst.close();
        lastOn = subStart;
      }
      break;
    }

    default:
      break;
    }
  }

  return BL_SUCCESS;
}

ERL_NIF_TERM path_flatten(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return make_result_error(env, "bad_arity");

  auto srcPath = NifResource<Path>::get(env, argv[0]);
  if(srcPath == nullptr) {
    return make_result_error(env, "path_flatten_bad_src_path");
  }

  double tolerance = 0.25; // default
  {
    if(!enif_get_double(env, argv[1], &tolerance)) {
      return make_result_error(env, "path_flatten_invalid_tolerance");
    }
  }

  // allocate new Path resource
  auto dstPath = NifResource<Path>::alloc();
  if(!dstPath) {
    return make_result_error(env, "dst_path_alloc_failed");
  }

  BLResult res = flattenPath(srcPath->value, dstPath->value, tolerance);
  if(res != BL_SUCCESS) {
    return make_result_error(env, "flatten_failed");
  }

  ERL_NIF_TERM term = enif_make_resource(env, dstPath);
  return make_result_ok(env, term);
}
