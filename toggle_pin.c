int toggle_pin(lua_State *L){
  //simplegpio_set_mode(0, pinspec_map[2]); //setting  pinstate from lua
#define bit 1 << 16;
  uint32_t volatile *reg = (uint32_t volatile *)(0x400E1000+0x005c);
#define toggle *reg = bit;
  while (1) {
  toggle toggle toggle toggle toggle toggle toggle toggle 
  toggle toggle toggle toggle toggle toggle toggle toggle
  }
}
