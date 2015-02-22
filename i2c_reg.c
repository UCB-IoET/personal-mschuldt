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
 

storm_array_t* make_lua_array(lua_State *L, uint32_t len, uint32_t element_size){
  //call storm.array.create(count, default_element_size)
  lua_getglobal(L, "storm");
  lua_pushstring(L, "array");
  lua_rawget(L, -2);
  lua_remove(L, -2);
  lua_pushstring(L, "create");
  lua_rawget(L, -2);
  lua_remove(L, -2);
  lua_pushnumber(L, element_size);
  lua_pushnumber(L, len);
  lua_call(L, 2,1);
  storm_array_t *arr = lua_touserdata(L, 1);
  lua_remove(L, -1);
  return arr;
}

static int reg_new(lua_State *L, uint32_t port, uint32_t address){
  printf("reg_new(%d,%d)\n", port, address);
  i2c_reg *reg = lua_newuserdata(L, sizeof(i2c_reg));
  reg->port = port;
  reg->address = address;
  reg->arr1 = make_lua_array(L, 1, ARR_TYPE_UINT8);
  reg->arr2 = make_lua_array(L, 2, ARR_TYPE_UINT8);
  lua_pushrotable(L, (void*)reg_meta_map);
  lua_setmetatable(L, -2);
  return 1;
}

int test (lua_State *L){
  printf("test function!\n");
  storm_array_t a = make_lua_array(L, 1, ARR_TYPE_UINT8);
  storm_array_set(1, 234);
  printf("set value (should be 234) = %d\n", storm_array_get(1));
  return 0;
}

//Read a given register address (a num of bytes)
//Return an array of UNIT8

static int reg_r_entry(lua_State *L){
  printf("reg_r_entry()\n");
  i2c_reg *self = lua_touserdata(L, 1); //does this pop the value?
  int reg = luaL_checkinteger(L, 2); //or this?
  lua_remove(L, 2);
  storm_array_set(self->arr1, 1, reg);
  cord_set_continuation(L, reg_r_tail1, 1);
  return nc_invoke_i2c_write(L, self->port + self->address, I2C_START, self->arr1);
  //TODO: check return status in tail1
}

static int reg_r_tail1(lua_State *L){
  printf("reg_r_tail1()\n");
  i2c_reg *self = lua_touserdata(L, lua_upvalueindex(1));
  cord_set_continuation(L, reg_r_tail2, 1);
  return nc_invoke_i2c_read(L,
			    self->port + self->address, 
			    I2C_START + I2C_RSTART + I2C_STOP,
			    self->arr1);
  //TODO: check return status in tail2
}

static int reg_r_tail2(lua_State *L){
  printf("reg_r_tail2()\n");
  i2c_reg *self = lua_touserdata(L, lua_upvalueindex(1));
  return storm_array_get(self->arr1, 1);
}


static int reg_w_entry(lua_State *L){
  i2c_reg *self = lua_touserdata(L, lua_upvalueindex(1));
  int reg = luaL_checkinteger(L, 2);
  int value = luaL_checkinteger(L, 3);
  storm_array_set(self->arr2, 1, reg);
  storm_array_set(self->arr2, 2, value);
  cord_set_continuation(L, reg_w_tail, 1);
  return nc_invoke_i2c_write(L, self->port + self->address, I2C_START + I2C_STOP, self->arr2);
}

static int reg_w_tail(lua_State *L){
  return 1;///?
}
