#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <assert.h>
#include "julia.h"
#include "julia_internal.h"

DLLEXPORT jl_sv_t *jl_sv(size_t n, ...)
{
    va_list args;
    if (n == 0) return jl_emptysv;
    va_start(args, n);
    jl_tuple_t *jv = jl_alloc_sv_uninit(n);
    for(size_t i=0; i < n; i++) {
        jl_svset(jv, i, va_arg(args, jl_value_t*));
    }
    va_end(args);
    return jv;
}

jl_sv_t *jl_sv1(void *a)
{
#ifdef OVERLAP_SV_LEN
    jl_sv_t *v = (jl_sv_t*)alloc_2w();
#else
    jl_sv_t *v = (jl_sv_t*)alloc_3w();
#endif
    v->type = (jl_value_t*)jl_simplevector_type;
    jl_sv_set_len_unsafe(v, 1);
    jl_svset(v, 0, a);
    return v;
}

jl_sv_t *jl_sv2(void *a, void *b)
{
#ifdef OVERLAP_TUPLE_LEN
    jl_sv_t *v = (jl_sv_t*)alloc_3w();
#else
    jl_sv_t *v = (jl_sv_t*)alloc_4w();
#endif
    v->type = (jl_value_t*)jl_simplevector_type;
    jl_sv_set_len_unsafe(v, 2);
    jl_svset(v, 0, a);
    jl_svset(v, 1, b);
    return v;
}

jl_sv_t *jl_alloc_sv_uninit(size_t n)
{
    if (n == 0) return jl_emptysv;
#ifdef OVERLAP_TUPLE_LEN
    jl_sv_t *jv = (jl_tuple_t*)newobj((jl_value_t*)jl_simplevector_type, n);
#else
    jl_sv_t *jv = (jl_tuple_t*)newobj((jl_value_t*)jl_simplevector_type, n+1);
#endif
    jl_sv_set_len_unsafe(jv, n);
    return jv;
}

jl_tuple_t *jl_alloc_sv(size_t n)
{
    if (n == 0) return jl_emptysv;
    jl_sv_t *jv = jl_alloc_sv_uninit(n);
    for(size_t i=0; i < n; i++) {
        jl_svset(jv, i, NULL);
    }
    return jv;
}

jl_sv_t *jl_sv_append(jl_sv_t *a, jl_sv_t *b)
{
    jl_sv_t *c = jl_alloc_sv_uninit(jl_sv_len(a) + jl_sv_len(b));
    size_t i=0, j;
    for(j=0; j < jl_sv_len(a); j++) {
        jl_svset(c, i, jl_svref(a,j));
        i++;
    }
    for(j=0; j < jl_sv_len(b); j++) {
        jl_svset(c, i, jl_svref(b,j));
        i++;
    }
    return c;
}

jl_sv_t *jl_sv_fill(size_t n, jl_value_t *x)
{
    if (n==0) return jl_emptysv;
    jl_sv_t *v = jl_alloc_sv_uninit(n);
    for(size_t i=0; i < n; i++) {
        jl_svset(v, i, x);
    }
    return v;
}
