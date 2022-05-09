D                       [0-9]
L                       [a-zA-Z_]
H                       [a-fA-F0-9]
IS                      (l|L)*

%{
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "y.tab.h"

/* Count number of lines & colummns.  */
int column = 1;
int prevCol = 1;
int line = 1;

void multi_line_comment();
void update_line_col(void);


int yyparse();

char keywords[][10]={ "auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else", "enum", "extern", "float", "for", "goto", "if", "int", "long", "register", "return", "short", "signed", "sizeof", "static", "struct", "switch", "typedef", "union", "unsigned", "void", "volatile", "while"};
// extern, int, void, goto, if, return


%}

%option noyywrap

%%
"int"							{ update_line_col(); return(INT); }
"void"							{ update_line_col(); return(VOID); }
"extern"                        { update_line_col(); return(EXTERN);}

"while"							{ update_line_col(); return(WHILE);}
"for"							{ update_line_col(); return(FOR); }
"else"							{ update_line_col(); return(ELSE); }
"if"							{ update_line_col(); return(IF); }

"return"						{ update_line_col(); return(RETURN); }

"struct"						{ update_line_col(); return(STRUCT); }

{L}({L}|{D})*                   {
                                  strcpy(yylval.ystr,yytext);
                                  update_line_col();
                                  return(IDENTIFIER);}

([1-9]{D}*{IS}?)|(0{IS}?)		{yylval.yint=atoi(yytext);
                                 update_line_col();
                                 return(CONSTANT);}

"->"                            { update_line_col(); return(PTR_OP); }
"."                             { update_line_col(); return('.'); }
"&&"                        	{ update_line_col(); return(AND_OP); }
"||"							{ update_line_col(); return(OR_OP); }
"<="							{ update_line_col(); return(LE_OP); }
">="							{ update_line_col(); return(GE_OP); }
"=="							{ update_line_col(); return(EQ_OP); }
"!="							{ update_line_col(); return(NE_OP); }

";"								{ update_line_col(); return(';'); }
("{"|"<%")			             { update_line_col(); return('{'); }
("}"|"%>")			             { update_line_col(); return('}'); }
","								{ update_line_col(); return(','); }

"="								{ update_line_col(); return('='); }
"("								{ update_line_col(); return('('); }
")"								{ update_line_col(); return(')'); }

"&"								{ update_line_col(); return('&'); }
"!"								{ update_line_col(); return('!'); }

"-"								{ update_line_col(); return('-'); }
"+"								{ update_line_col(); return('+'); }
"*"								{ update_line_col(); return('*'); }
"/"								{ update_line_col(); return('/'); }

"<"								{ update_line_col(); return('<'); }
">"								{ update_line_col(); return('>'); }

[ \t\v\n\r]             { update_line_col();}
.                       { return yytext[0];}

"/*"                    {multi_line_comment();}
%%

int main (int argc, char* argv[]) {

    extern FILE *yyin,*yyout;

		if(argc<2)
		{
		printf("Input C file(s) expected.\n");
		exit(0);
		}
        
		yyin=fopen(argv[1], "r");
		//yyout=fopen(argv[2], "w");

	  yyparse(yyin);
	  return 0;
}


void update_line_col(void)
{
	int i;
	fprintf(yyout,"%s", yytext);
	for (i = 0; yytext[i] != '\0'; i++) // read current string=token
	{
		prevCol = column;
		if (yytext[i] == '\n'){ // new line
			column = 1;
			line++;
		}
		else if (yytext[i] == '\t') //tab => +4/5 spaces
		{
			column += 4;
		}
		else
		{
			column++; //1 char
		}
	}

}


void multi_line_comment()
{
	char c, prev = 0;

	int startLine = line, startCol = prevCol;
	while ((c = input()) != 0)      /* until EOF, 0 */
	{
		if (prev == '*' && c == '/' ) // end of comment
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

  printf("%d:%d: \033[25mError: Unterminated comment.\n", startLine, startCol);
	exit (0);
}
