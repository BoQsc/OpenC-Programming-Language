struct P{i32 x;}P make(){storage P s;ref P p=construct(s,P{x=1});scope destroy(p);return P{x=p.x};}i32 main(){P p=make();return p.x;}
