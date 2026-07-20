import system.io; bool mark(){io.print("bad");return true;} i32 main(){if false && mark(){} if true || mark(){} return 0;}
