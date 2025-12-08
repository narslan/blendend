#pragma once
#include <blend2d/blend2d.h>
#include <erl_nif.h>
#include <functional>
#include <initializer_list>
#include <type_traits>
#include <utility>

inline ERL_NIF_TERM make_result_ok(ErlNifEnv* env, ERL_NIF_TERM term)
{
  return enif_make_tuple2(env, enif_make_atom(env, "ok"), term);
}

// Helper: {:error, "reason"}
inline ERL_NIF_TERM make_result_error(ErlNifEnv* env, const char* reason)
{
  return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_atom(env, reason));
}

inline ERL_NIF_TERM make_binary_from_str(ErlNifEnv* env, const char* str)
{
  ErlNifBinary bin;
  size_t len = strlen(str);
  enif_alloc_binary(len, &bin);
  memcpy(bin.data, str, len);
  return enif_make_binary(env, &bin);
}

template <typename T>
ERL_NIF_TERM map_from_fields(
    ErlNifEnv* env,
    const T& obj,
    std::initializer_list<std::pair<const char*, std::function<double(const T&)>>> fields)
{
  ERL_NIF_TERM map = enif_make_new_map(env);

  for(auto& f : fields) {
    const char* name = f.first;
    const auto& accessor = f.second; // std::function<double(const T&)>
    double val = accessor(obj);
    ERL_NIF_TERM key = make_binary_from_str(env, name);
    ERL_NIF_TERM erl_val = enif_make_double(env, val);
    enif_make_map_put(env, map, key, erl_val, &map);
  }

  return map;
}

template <typename T>
static void map_put_number(ErlNifEnv* env, ERL_NIF_TERM& map, const char* key, T value)
{
  ERL_NIF_TERM k = make_binary_from_str(env, key);

  if constexpr(std::is_integral_v<T>) {
    enif_make_map_put(env, map, k, enif_make_int(env, static_cast<int>(value)), &map);
  }
  else if constexpr(std::is_floating_point_v<T>) {
    enif_make_map_put(env, map, k, enif_make_double(env, static_cast<double>(value)), &map);
  }
}

template <typename PointT>
static ERL_NIF_TERM point_to_map_impl(ErlNifEnv* env, const PointT* p)
{
  ERL_NIF_TERM map = enif_make_new_map(env);
  map_put_number(env, map, "x", p->value->x);
  map_put_number(env, map, "y", p->value->y);
  return map;
}

// Small macro helpers
#define PUT_STR(env, map, key, val) \
  enif_make_map_put(env, map, make_binary_from_str(env, key), val, &map)

#define PUT_NUM(env, map, key, val) map_put_number(env, map, key, val)
