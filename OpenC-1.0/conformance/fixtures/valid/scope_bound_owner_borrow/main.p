resource R{ptr byte p;}R make();void r_destroy(own R r){}void inspect(ref const R r){}i32 main(){R r=make();scope r_destroy(r);inspect(r);return 0;}
