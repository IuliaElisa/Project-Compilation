D                       [0-9]
L                       [a-zA-Z_]
H                       [a-fA-F0-9]
IS                      (l|L)*

%{
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "structfe.tab.h"
//#include "y.tab.h"
#include "definitions.h"

int column = 1;
int prevCol = 1;
int line = 1;

void actualiser(int n);
extern void yyerror(char *);

int yyparse();


char keywords[10][10]={"extern", "int","void", "for", "while", "if", "else", "return", "struct","sizeof"};

%}

%option noyywrap

%%

"while"							{ actualiser(0); return(WHILE);}
"for"							{ actualiser(0); return(FOR); }
"else"							{ actualiser(0); return(ELSE); }
"if"							{ actualiser(0); return(IF); }
"sizeof"                        { actualiser(0); return(SIZEOF); }
"return"						{ actualiser(0); return(RETURN); }
"int"							{ actualiser(0); return(INT); }
"void"							{ actualiser(0); return(VOID); }
"extern"                        { actualiser(0); return(EXTERN);}

"struct"						{ actualiser(0); return(STRUCT); }

{L}({L}|{D})*                   {
                                for(int i=0;i<10;i++){
                                if(strcmp(yytext, keywords[i])==0)
                                    yyerror("Un identificateur ne peut pas prendre le nom d'un mot clé.");
                                }
                                  strcpy(yylval.ystr,yytext);
                                  actualiser(0);
                                  return(IDENTIFIER);}

([1-9]{D}*{IS}?)|(0{IS}?)		{yylval.yint=atoi(yytext);
                                 actualiser(0);
                                 return(CONSTANT);}

"->"                            { actualiser(0); return(PTR_OP); }
"."                             { actualiser(0); return('.'); }
"&&"                        	{ actualiser(0); return(AND_OP); }
"||"							{ actualiser(0); return(OR_OP); }
"<="							{ actualiser(0); return(LE_OP); }
">="							{ actualiser(0); return(GE_OP); }
"=="							{ actualiser(0); return(EQ_OP); }
"!="							{ actualiser(0); return(NE_OP); }

";"								{ actualiser(0); return(';'); }
("{"|"<%")			             { actualiser(0); return('{'); }
("}"|"%>")			             { actualiser(0); return('}'); }
","								{ actualiser(0); return(','); }

"="								{ actualiser(0); return('='); }
"("								{ actualiser(0); return('('); }
")"								{ actualiser(0); return(')'); }

"&"								{ actualiser(0); return('&'); }
"!"								{ actualiser(0); return('!'); }

"-"								{ actualiser(0); return('-'); }
"+"								{ actualiser(0); return('+'); }
"*"								{ actualiser(0); return('*'); }
"/"								{ actualiser(0); return('/'); }

"<"								{actualiser(0); return('<'); }
">"								{ actualiser(0); return('>'); }

[ \t\v\n\r]             { actualiser(0);}
.                       { printf("Erreur lexicale à la ligne %d:%d\n", line, column); existe_erreur();}

"/*"                    {actualiser(1);}
%%
    int existe_erreur(){
        return 1;
    }
void actualiser(int n)
{
	char c, prev = 0;
	int i;
	int startLine = line, startCol = prevCol;

	if(n==0){
	for (i = 0; yytext[i] != '\0'; i++)
	{
		prevCol = column;
		if (yytext[i] == '\n'){
			column = 1;
			line++;
		}
		else if (yytext[i] == '\t')
		{
			column += 5;
		}
		else
		{
			column++; 
		}
	}
	}

	if(n==1){
	while ((c = input()) != 0)     
	{
		if (prev == '*' && c == '/' ) 
			return;
		prev = c;
		prevCol = column;
		if (c == '\n'){
			column = 1;
			line++;
		}
		else if (c == '\t')
		{
			column += 4;
		}
		else
		{
			column++;
		}
	}
	exit (0);
	}
	
}
