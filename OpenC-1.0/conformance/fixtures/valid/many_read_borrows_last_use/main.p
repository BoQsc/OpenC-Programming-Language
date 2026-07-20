struct P{i32 x;}i32 main(){P p=P{x=1};ref const P a=p;ref const P b=p;i32 n=a.x+b.x;p.x=3;return n;}
