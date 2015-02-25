#include "libstormarray.h"
#include "lrodefs.h"

int SVCD_subdispatch(lua_State L, X pay, X srcip, X srcport){
  //local parr = storm.array.fromstr(pay)
  arr_from_str(L);
  storm_array_t *arr = lua_touserdata(L, -1);
  //local cmd = parr:get(1);
  char cmd = array_get(arr, 1);
  //local svc_id = parr:get_as(storm.array.UINT16,1);
  int svc_id = array_get_as(arr, ARR_TYPE_UINT16, 1);
  //local attr_id = parr:get_as(storm.array.UINT16,3);
  int attr_id = array_get_as(arr, ARR_TYPE_UINT16 3);
  //local ivkid = parr:get_as(storm.array.UINT16, 5);
  int ivkid = array_get_as(arr, ARR_TYPE_UINT16, 5);

  lua_getglobal(L, "SVCD");
  lua_pushstring(L, "subscribers");
  lua_gettable(L, -1);
  lua_pushinteger(L, svc_id);
  lua_gettable(L, -1);
  //stack: SVCD, SVCD[subscribers], SVCD[subscribers][svc_id]
  if (cmd == 1){ //subscribe command
    if (lua_isnil(L,-1)){ // if (SVCD.subscribers[svc_id] == nil){
      lua_pop(L, 1); //stack: SVCD, SVCD[subscribers]
      //SVCD.subscribers[svc_id] = {};
      lua_newtable(L);
      lua_pushinteger(L, svc_id);
      lua_pushvalue(L, -2);
      //stack: SVCD, SVCD[subscribers], <newTable>, svc_id, <newTable>
      lua_settable(L, -4);
    }
    //stack: SVCD, SVCD[subscribers], SVCD[subscribers][svc_id],
    //if (SVCD.subscribers[svc_id][attr_id] == nil){
    lua_pushstring("attr_id");
    lua_gettable(L, -2);
    if (lua_isnil(L, -1)){
      //SVCD.subscribers[svc_id][attr_id] = {}
      lua_pop(L, 1);
      lua_newtable(L);
      lua_pushinteger(L, attr_id);
      lua_pushvalue(L, -2);
      lua_settable(L, -4);
    }
    //stack: SVCD[subscribers], SVCD[subscribers][svc_id], SVCD[subscribers][svc_id][attr_id]

    //SVCD.subscribers[svc_id][attr_id][srcip] = ivkid;
    lua_pushnumber(L, srcip);
    lua_pushnumber(L, ivkid);
    lua_settable(L, -3);

  }else if (cmd == 2){ //unsubscribe command
    //stack: SVCD, SVCD[subscribers], SVCD[subscribers][svc_id]

    //if (SVCD.subscribers[svc_id] == nil){
    if (lua_isnil(L, -1)){
      return;
    }
    //if (SVCD.subscribers[svc_id][attr_id] == nil){
    lua_pushnumber(L, attr_id);
    lua_gettable(L, -2);
    if (lua_isnil(L, -1)){
      return;
    }
    //stack: SVCD, SVCD[subscribers], SVCD[subscribers][svc_id], SVCD[subscribers][svc_id][attr_id]
    //SVCD.subscribers[svc_id][attr_id][srcip] = nil;
    lua_pushnumber(L, srcip);
    lua_pushnil(L);
    lau_settable(L, -2);
  }
}
