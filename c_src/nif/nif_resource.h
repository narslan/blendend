#pragma once
#include <blend2d/blend2d.h>
#include <erl_nif.h>

template <typename T>
struct NifResource {
  // Resource type is shared per T, initialized when open/2 is called.
  static inline ErlNifResourceType* type = nullptr;

  static void dtor([[maybe_unused]] ErlNifEnv* env, void* obj)
  {
    T* res = static_cast<T*>(obj);
    res->destroy();
    res->~T();
  }

  static int open(ErlNifEnv* env, const char* module_name, const char* name)
  {
    ErlNifResourceFlags flags =
        static_cast<ErlNifResourceFlags>(ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER);

    type = enif_open_resource_type(env, module_name, name, &dtor, flags, nullptr);

    return type ? 0 : -1;
  }

  static T* get(ErlNifEnv* env, ERL_NIF_TERM term)
  {
    T* ptr = nullptr;
    if(!enif_get_resource(env, term, type, (void**)&ptr))
      return nullptr;
    return ptr;
  }

  static T* alloc()
  {
    if(!type)
      return nullptr;

    void* raw = enif_alloc_resource(type, sizeof(T));
    if(!raw)
      return nullptr;

    T* res = new(raw) T();
    return res;
  }

  // Box the resource into a term & hand ownership to BEAM.
  static ERL_NIF_TERM make(ErlNifEnv* env, T* res)
  {
    ERL_NIF_TERM term = enif_make_resource(env, res);
    enif_release_resource(res);
    return term;
  }
};
