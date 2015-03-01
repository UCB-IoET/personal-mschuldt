
#include "libstormarray.h"

//#include "I2C.h"
#define I2C_START 1
#define I2C_RSTART 1
#define I2C_ACKLAST 2
#define I2C_STOP 4
#define I2C_OK 0

static int reg_r(lua_State *L);
static int reg_w(lua_State *L);
static int reg_r_entry(lua_State *L);
static int reg_r_tail1(lua_State *L);
static int reg_r_tail2(lua_State *L);
static int reg_w_entry(lua_State *L);
static int reg_w_tail(lua_State *L);

#define I2CREG_SYMBOLS \
  { LSTRKEY( "reg_new"), LFUNCVAL ( reg_new ) },



static const LUA_REG_TYPE reg_meta_map[] =
  {
    {LSTRKEY("r"), LFUNCVAL(reg_r_entry)},
    {LSTRKEY("w"), LFUNCVAL(reg_w_entry)},
    //{LSTRKEY("r"), LFUNCVAL(reg_r)},
    //{LSTRKEY("w"), LFUNCVAL(reg_w)},
    {LSTRKEY("__index"), LROVAL(reg_meta_map)},
    {LNILKEY, LNILVAL}
  };

typedef struct i2c_reg{
  uint32_t port;
  uint32_t address;
  storm_array_t* arr1;
  storm_array_t* arr2;
  char* name;
} __attribute__((packed)) i2c_reg;

int _init = 0;
static void init(lua_State *L){
  storm_array_nc_create(L, 1, ARR_TYPE_UINT8);
  lua_getmetatable(L, -1);
  lua_pushstring(L, "set");
  lua_rawget(L, -2);
  lua_setglobal(L, "__set");
  lua_pushstring(L, "get");
  lua_rawget(L, -2);
  lua_setglobal(L, "__get");
  //stack: arr, set, get
  lua_getglobal(L, "storm");
  lua_pop(L, 1);
  _init = 1;
}

static void storm_array_set(lua_State *L, storm_array_t *arr, int i, int val){
  printf("storm_array_set()\n");
  /*
    printf("arr = %d\n", arr);
  printf("arr->len = %d\n", arr->len);
  printf("i = %d\n", i);
  printf("val = %d\n", val);
  */
  lua_getglobal(L, "__set");
  lua_pushlightuserdata(L, arr);
  lua_pushnumber(L, i);
  lua_pushnumber(L, val);
  lua_call(L, 3, 0);
}

static int storm_array_get(lua_State *L, storm_array_t *arr, int i){
  printf("storm_array_get()\n");
  lua_getglobal(L, "__get");
  lua_pushlightuserdata(L, arr);
  lua_pushnumber(L, i);
  lua_call(L, 2, 1);
  int ret = lua_tonumber(L, -1);
  lua_pop(L, 1);
  return ret;
}


static int reg_new(lua_State *L){
  int port = lua_tonumber(L, 1);
  int address = lua_tonumber(L, 2);
  char* name = lua_tostring(L, 3);
  if (!_init){ init(L); }

  i2c_reg *reg = lua_newuserdata(L, sizeof(i2c_reg));
  reg->port = port;
  reg->address = address;
  reg->name = name;
  storm_array_nc_create(L, 1, ARR_TYPE_UINT8);
  reg->arr1 = lua_touserdata(L, -1);
  storm_array_nc_create(L, 2, ARR_TYPE_UINT8);
  reg->arr2 = lua_touserdata(L, -1);
  lua_pushlightuserdata(L, reg);
  lua_pushrotable(L, (void*)reg_meta_map);
  lua_setmetatable(L, -2);

  i2c_reg *r = lua_touserdata(L, -1);
  printf("created new reg:\n");
  printf("  p = %d\n", r->port);
  printf("  a = %d\n", r->address);
  printf("  name = %s", r->name);

  return 1;
}

int test (lua_State *L){
  printf("test function!\n");
  return 0;
}

//Read a given register address (a num of bytes)
//Return an array of UNIT8

static int reg_r_entry(lua_State *L){
  printf("reg_r_entry()\n");
  i2c_reg *self = lua_touserdata(L, 1);
  int reg = luaL_checkinteger(L, 2);
  int num = luaL_checkinteger(L, 3);
  if (num < 1){
    num = 1;
  }
  printf("self->arr1 = %p\n", self->arr1);
  storm_array_set(L, self->arr1, 1, reg);
  lua_pushlightuserdata(L, self);
  lua_pushnumber(L, num);
  cord_set_continuation(L, reg_r_tail1, 2);
  printf("reg_r_entry end\n");
  return nc_invoke_i2c_write(L, self->port + self->address, I2C_START, self->arr1);
  //TODO: check return status in tail1
}

static int reg_r_tail1(lua_State *L){
  printf("reg_r_tail1()\n");
  i2c_reg *self = lua_touserdata(L, lua_upvalueindex(1));
  int num = lua_tonumber(L, lua_upvalueindex(2));
  storm_array_t *arr;
  if (num == 1){
    arr = self->arr1;
  }else if (num == 2){
    arr = self->arr2;
  }else{
    storm_array_nc_create(L, num, ARR_TYPE_UINT8);
    arr = lua_touserdata(L, -1);
    lua_remove(L, -1);
  }
  lua_pushlightuserdata(L, arr);
  lua_pushnumber(L, num);
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
    lua_pushnumber(L, storm_array_get(L, arr, 1));
  }else{
    lua_pushlightuserdata(L, arr);
  }
  return cord_return(L, 1);
}

static int reg_w_entry(lua_State *L){
  //TODO: multiple values
  printf("reg_w_entry()\n");
  i2c_reg *self = lua_touserdata(L, 1);
  int reg = luaL_checkinteger(L, 2);
  int len;
  storm_array_t *arr;
  if (lua_isnumber(L, 3)){
    printf("   single value\n");
    storm_array_nc_create(L, 2, ARR_TYPE_UINT8);
    arr = lua_touserdata(L, -1);
    storm_array_set(L, arr, 1, reg);
    storm_array_set(L, arr, 1, lua_tonumber(L, 3));
  }else{
    printf("   multiple values\n");
    size_t len = lua_objlen(L, 3);
    storm_array_nc_create(L, len+1, ARR_TYPE_UINT8);
    arr = lua_touserdata(L, -1);
    storm_array_set(L, arr, 1, reg);
    int i;
    printf("here\n");
    for (i=1;i <= len;){
      printf("...%d\n", i);
      lua_pushnumber(L, i);
      lua_gettable(L, 3);
      i++;
      storm_array_set(L, arr, i, lua_tonumber(L, -1));
      lua_pop(L, 1);
    }
  }
  cord_set_continuation(L, reg_w_tail, 0);
  return nc_invoke_i2c_write(L, self->port + self->address, I2C_START + I2C_STOP, arr);
}

static int reg_w_tail(lua_State *L){
  printf("reg_w_tail()\n");
  return cord_return(L, 0);
}

////////////////////////////////////////////////////////////////////////////////

static int reg_r(lua_State *L){
  printf("reg_r()\n");
  i2c_reg *self = lua_touserdata(L, 1);
  int reg = luaL_checkinteger(L, 2);
  int num = luaL_checkinteger(L, 3);
  storm_array_t *arr;
  if (num < 1){
    num = 1;
  }
  printf("self->arr1 = %p\n", self->arr1);
  storm_array_set(L, self->arr1, 1, reg);
  lua_pushlightfunction(L, libstorm_i2c_write);
  printf("p = %d\n", self->port);
  printf("a = %d\n", self->address);
  lua_pushnumber(L, self->port + self->address);
  lua_pushnumber(L, I2C_START);
  lua_pushlightuserdata(L, self->arr1);
  lua_pushnil(L);
  printf("here\n");
  lua_call(L, 4, 1);
  //TODO: check ret val
  if (num == 1){
    arr = self->arr1;
  }else if (num == 2){
    arr = self->arr2;
  }else{
    storm_array_nc_create(L, num, ARR_TYPE_UINT8);
    arr = lua_touserdata(L, -1);
    lua_remove(L, -1);
  }
  lua_pushlightfunction(L, libstorm_i2c_read);
  lua_pushnumber(L, self->port + self->address);
  lua_pushnumber(L, I2C_START + I2C_RSTART + I2C_STOP);
  lua_pushlightuserdata(L, arr);
  lua_pushnil(L);
  lua_call(L, 4, 1);
  //TODO: check return val
  if (num == 1){
    lua_pushnumber(L, storm_array_get(L, arr, 1));
  }else{
    lua_pushlightuserdata(L, arr);
  }
  return 1;
}

void cb(void){
  printf("CALLBACK!\n");
}
static int reg_w(lua_State *L){
  printf("reg_w()\n");
  i2c_reg *self = lua_touserdata(L, 1);
  int reg = luaL_checkinteger(L, 2);
  int len;
  storm_array_t *arr;
  if (lua_isnumber(L, 3)){
    printf("   single value\n");
    storm_array_nc_create(L, 2, ARR_TYPE_UINT8);
    arr = lua_touserdata(L, -1);
    storm_array_set(L, arr, 1, reg);
    storm_array_set(L, arr, 1, lua_tonumber(L, 3));
  }else{
    printf("   multiple values\n");
    size_t len = lua_objlen(L, 3);
    storm_array_nc_create(L, len+1, ARR_TYPE_UINT8);
    arr = lua_touserdata(L, -1);
    storm_array_set(L, arr, 1, reg);
    int i;
    for (i=1;i <= len;){
      printf("...%d\n", i);
      lua_pushnumber(L, i);
      lua_gettable(L, 3);
      i++;
      storm_array_set(L, arr, i, lua_tonumber(L, -1));
      lua_pop(L, 1);
    }
  }
  lua_pushlightfunction(L, libstorm_i2c_write);
  printf("p = %d\n", self->port);
  printf("a = %d\n", self->address);
  printf("name = %s", self->name);
  lua_pushnumber(L, self->port + self->address);
  lua_pushnumber(L, I2C_START + I2C_STOP);
  lua_pushlightuserdata(L, arr);
  lua_pushlightfunction(L, cb);
  printf("_x_\n");
  lua_call(L, 4, 1);
  //TODO: check return val
  return 0;
}
