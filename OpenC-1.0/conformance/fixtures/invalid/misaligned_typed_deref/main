import system.memory;unsafe i32 bad(ptr byte p){ptr i32 q=reinterpret(ptr i32,p+1);return *q;}unsafe i32 main(){ptr byte p=memory.alloc(4);scope memory.free(p);return bad(p);}
