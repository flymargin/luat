/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    bit.cpp
 * Author:  panjun
 * Version: V0.1
 * Date:    2016/10/19
 *
 * Description:
 *     Bitwise operations library
 *     (c) Reuben Thomas 2000-2008, See README for license.
 * History:
 *     panjun 16/10/19 Initially create file.
 *     Modified by BogdanM for eLua
 **************************************************************************/


#include "stdafx.h"
#include "lua.hpp"
#include "platform.h"
#include "platform_conf.h"
#include "auxmods.h"

/* FIXME: Assume size_t is an unsigned lua_Integer */
typedef size_t lua_UInteger;
#define LUA_UINTEGER_MAX SIZE_MAX

/* Define TOBIT to get a bit value */
#define TOBIT(L, n, res)                    \
  ((void)(res), luaL_checkinteger((L), (n)))

/* Operations

   The macros MONADIC and VARIADIC only deal with bitwise operations.

   LOGICAL_SHIFT truncates its left-hand operand before shifting so
   that any extra bits at the most-significant end are not shifted
   into the result.

   ARITHMETIC_SHIFT does not truncate its left-hand operand, so that
   the sign bits are not removed and right shift work properly.
   */
  
#define MONADIC(name, op)                                       \
  static int bit_ ## name(lua_State *L) {                       \
    lua_Integer f;                                              \
    lua_pushinteger(L, op TOBIT(L, 1, f));                      \
    return 1;                                                   \
  }

#define VARIADIC(name, op)                      \
  static int bit_ ## name(lua_State *L) {       \
    lua_Integer f;                              \
    int n = lua_gettop(L), i;                   \
    lua_Integer w = TOBIT(L, 1, f);             \
    for (i = 2; i <= n; i++)                    \
      w op TOBIT(L, i, f);                      \
    lua_pushinteger(L, w);                      \
    return 1;                                   \
  }

#define LOGICAL_SHIFT(name, op)                                         \
  static int bit_ ## name(lua_State *L) {                               \
    lua_Integer f;                                                      \
    lua_pushinteger(L, (lua_UInteger)TOBIT(L, 1, f) op                  \
                          (unsigned)luaL_checknumber(L, 2));            \
    return 1;                                                           \
  }

#define ARITHMETIC_SHIFT(name, op)                                      \
  static int bit_ ## name(lua_State *L) {                               \
    lua_Integer f;                                                      \
    lua_pushinteger(L, (lua_Integer)TOBIT(L, 1, f) op                   \
                          (unsigned)luaL_checknumber(L, 2));            \
    return 1;                                                           \
  }

MONADIC(bnot,  ~)
VARIADIC(band, &=)
VARIADIC(bor,  |=)
VARIADIC(bxor, ^=)
ARITHMETIC_SHIFT(lshift,  <<)
LOGICAL_SHIFT(rshift,     >>)
ARITHMETIC_SHIFT(arshift, >>)

// Lua: res = bit( position )
static int bit_bit( lua_State* L )
{
  lua_pushinteger( L, ( lua_Integer )( 1 << luaL_checkinteger( L, 1 ) ) );
  return 1;
}

// Lua: res = isset( value, position )
static int bit_isset( lua_State* L )
{
  lua_UInteger val = ( lua_UInteger )luaL_checkinteger( L, 1 );
  unsigned pos = ( unsigned )luaL_checkinteger( L, 2 );
  
  lua_pushboolean( L, val & ( 1 << pos ) ? 1 : 0 );
  return 1;
}

// Lua: res = isclear( value, position )
static int bit_isclear( lua_State* L )
{
  lua_UInteger val = ( lua_UInteger )luaL_checkinteger( L, 1 );
  unsigned pos = ( unsigned )luaL_checkinteger( L, 2 );
  
  lua_pushboolean( L, val & ( 1 << pos ) ? 0 : 1 );
  return 1;
}

// Lua: res = set( value, pos1, pos2, ... )
static int bit_set( lua_State* L )
{ 
  lua_UInteger val = ( lua_UInteger )luaL_checkinteger( L, 1 );
  unsigned total = lua_gettop( L ), i;
  
  for( i = 2; i <= total; i ++ )
    val |= 1 << ( unsigned )luaL_checkinteger( L, i );
  lua_pushinteger( L, ( lua_Integer )val );
  return 1;
}

// Lua: res = clear( value, pos1, pos2, ... )
static int bit_clear( lua_State* L )
{
  lua_UInteger val = ( lua_UInteger )luaL_checkinteger( L, 1 );
  unsigned total = lua_gettop( L ), i;
  
  for( i = 2; i <= total; i ++ )
    val &= ~( 1 << ( unsigned )luaL_checkinteger( L, i ) );
  lua_pushinteger( L, ( lua_Integer )val );
  return 1; 
}

#define MIN_OPT_LEVEL 2
const luaL_Reg bit_map[] = {
  {"bnot",    bit_bnot},
  {"band",    bit_band},
  {"bor",     bit_bor},
  {"bxor",    bit_bxor},
  {"lshift",  bit_lshift},
  {"rshift",  bit_rshift},
  {"arshift", bit_arshift},
  {"bit",     bit_bit},
  {"set",     bit_set},
  {"clear",   bit_clear},
  {"isset",   bit_isset},
  {"isclear", bit_isclear},
  {NULL, NULL}
};

LUALIB_API int luaopen_bit (lua_State *L) {
  luaL_register( L, "bit", bit_map );
  return 1;
}
