void use(ref i32 x){}i32 main(){ref i32 r;{i32 x=1;r=x;}scope use(r);return 0;}
