start: y.tab.c lex.yy.c y.tab.h
	gcc y.tab.c lex.yy.c -o ex -ll
lex.yy.c: ANSI-C.l
	lex ANSI-C.l
y.tab.c: structfe.y
	yacc -v -d structfe.y
	
clean:
	rm -f lex.yy.c y.tab.c y.tab.h ex y.output
