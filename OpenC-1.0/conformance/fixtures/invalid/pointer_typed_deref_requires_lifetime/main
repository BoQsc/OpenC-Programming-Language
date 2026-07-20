import system.memory;unsafe i32 bad(){ptr byte p=memory.alloc(4);scope memory.free(p);ptr i32 q=reinterpret(ptr i32,p);return *q;}unsafe i32 main(){return bad();}
