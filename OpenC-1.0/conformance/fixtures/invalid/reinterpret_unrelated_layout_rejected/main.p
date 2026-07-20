struct A { i32 x; } struct B { i32 y; } i32 main(){ A a=A{x=1}; B b=reinterpret(B,a); return b.y; }
