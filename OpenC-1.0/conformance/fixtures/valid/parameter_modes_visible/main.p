resource R { ptr byte p; } status fill(out i32 x){x=1;return status{code=0,message=""};} void read(ref const i32 x){} void consume(own R r){}
