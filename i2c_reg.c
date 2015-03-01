#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "lrotable.h"
#include "auxmods.h"
#include <platform_generic.h>
#include <string.h>
#include <stdint.h>
#include <interface.h>
#include <stdlib.h>
#include <libstorm.h>

#include "lrodefs.h"
#include "libstormarray.h"

#define I2C_START 1
#define I2C_RSTART 1
#define I2C_ACKLAST 2
#define I2C_STOP 4
#define I2C_OK 0

static int reg_r_entry(lua_State *L);
static int reg_r_tail1(lua_State *L);
static int reg_r_tail2(lua_State *L);
static int reg_w_entry(lua_State *L);
static int reg_w_tail(lua_State *L);

#define SVCD_SYMBOLS \
    { LSTRKEY( "reg_new"), LFUNCVAL ( reg_new ) }
    

static const LUA_REG_TYPE reg_meta_map[] =
  {
    {LSTRKEY( "r" ), LFUNCVAL( reg_r_entry )},
    {LSTRKEY( "w" ), LFUNCVAL( reg_w_entry)},
    {LNILKEY, LNILVAL}
  };

typedef struct i2c_reg{
  uint32_t port;
  uint32_t address;
  storm_array_t* arr1;
  storm_array_t* arr2;
} __attribute__((packed)) i2c_reg;
 
static int reg_new(lua_State *L, uint32_t port, uint32_t address){
  printf("reg_new(%d,%d)\n", port, address);
  i2c_reg *reg = lua_newuserdata(L, sizeof(i2c_reg));
  reg->port = port;
  reg->address = address;
  storm_array_nc_create(L, 1, ARR_TYPE_UINT8);
  reg->arr1 = lua_touserdata(L, -1)
  storm_array_nc_create(L, 2, ARR_TYPE_UINT8);
  reg->arr2 = lua_touserdata(L, -1);
  lua_pushrotable(L, (void*)reg_meta_map);
  lua_setmetatable(L, -4);
  return 1;
}

int test (lua_State *L){
  printf("test function!\n");
  return 0;
}

//Read a given register address (a num of bytes)
//Return an array of UNIT8

static void storm_array_set_as(storm_array_t *arr, int i, int val){
  lua_getglobal(L, "storm");
  lua_pushstring(L, "array");
  lua_rawget(L, -2);
  lua_pushstring(L, "set");
  lua_rawget(L, -2);
  lua_remove(L, -2);
  lua_pushlightuserdata(L, arr);
  lua_pushnumber(L, i);  
  lua_pushnumber(L, val);
  lua_call(L, 2, 0);
}

static int storm_array_get(storm_array_t *arr, int i){
  lua_getglobal(L, "storm");
  lua_pushstring(L, "array");
  lua_rawget(L, -2);
  lua_pushstring(L, "get");
  lua_rawget(L, -2);
  lua_remove(L, -2);
  lua_pushlightuserdata(L, arr);
  lua_pushnumber(L, i);
  lua_call(L, 1, 1);
  int ret = lua_tonumber(L, -1);
  lua_pop(L, 1);
  return ret;
}

static int reg_r_entry(lua_State *L){
  printf("reg_r_entry()\n");
  i2c_reg *self = lua_touserdata(L, 1);
  int reg = luaL_checkinteger(L, 2);
  int num = luaL_checkinteger(L, 3);
  if (num < 1){
    num = 1;
  }
  storm_array_set(self->arr1, 1, reg);
  lua_pushlightuserdata(L, self);
  lua_pushnumber(L, num);
  cord_set_continuation(L, reg_r_tail1, 2);
  return nc_invoke_i2c_write(L, self->port + self->address, I2C_START, self->arr1);
  //TODO: check return status in tail1
}

static int reg_r_tail1(lua_State *L){
  printf("reg_r_tail1()\n");
  i2c_reg *self = lua_touserdata(L, lua_upvalueindex(1));
  i2c_reg *num = lua_touserdata(L, lua_upvalueindex(2));
  storm_array_t arr;
  if (num == 1){
    arr = self->arr1;
  }else if (num == 2){
    arr = self->arr2;
  }else{
    storm_array_nc_create(L, num, ARR_TYPE_UINT8);
    arr = lua_touserdata(L, -1);
    lua_delete(L, -1);
  }
  lua_pushlightuserdata(L, arr);
  lua_number(L, num);
  cord_set_continuation(L, reg_r_tail2, 2);
  //TODO: 'num' argument, create a new array if > 1
  return nc_invoke_i2c_read(L,
			    self->port + self->address, 
			    I2C_START + I2C_RSTART + I2C_STOP,
			    arr);
  //TODO: check return status in tail2
}

static int reg_r_tail2(lua_State *L){
  printf("reg_r_tail2()\n");
  storm_array_t *arr = lua_touserdata(L, lua_upvalueindex(1));
  int num = lua_tonumber(L, lua_upvalueindex(2));
  if (num == 1){
    lua_pushnumber(L, storm_array_get(arr, 1));
  }else{
    lua_pushlightuserdata(L);
  }
  return 1;
}

static int reg_w_entry(lua_State *L){
  //TODO: multiple values
  printf("reg_w_entry()\n");
  i2c_reg *self = lua_touserdata(L, 1);
  int reg = luaL_checkinteger(L, 2);
  int len;
  storm_array_t *arr;
  if (lua_isnumber(L, 3)){
    printf("   single value");
    storm_array_nc_create(L, 2, ARR_TYPE_UINT8);
    arr = lua_touserdata(L, -1);
    storm_array_set(arr, 1, reg);
    storm_array_set(arr, 1, lua_tonumber(L, 3));
  }else{
    printf("   multiple values");
    size_t len = lua_objlen(L, 3); 
    storm_array_nc_create(L, len+1, ARR_TYPE_UINT8);
    arr = lua_touserdata(L, -1);
    storm_array_set(arr, 1, reg);
    for (int i=1;i <= len;){
      lua_pushnumber(L, i);
      lua_gettable(L, 3);
      i++;
      storm_array_set(arr, i+1, lua_tonumber(L, -1));
      lua_pop(L, 1);
    }
  }
  cord_set_continuation(L, reg_w_tail, 1);
  return nc_invoke_i2c_write(L, self->port + self->address, I2C_START + I2C_STOP, arr);
}

static int reg_w_tail(lua_State *L){
  return 1;///?
}
