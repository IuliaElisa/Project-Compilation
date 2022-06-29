D                       [0-9]
L                       [a-zA-Z_]
H                       [a-fA-F0-9]
IS                      (l|L)*

%{
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "structfe.tab.h"

/* Count number of lines & colummns.  */
int column = 1;
int prevCol = 1;
int line = 1;

void multi_line_comment();
void update_line_col(void);
extern void yyerror(char *);

int yyparse();

char keywords[10][10]={"extern", "int","void", "for", "while", "if", "else", "return", "struct","sizeof"};


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
"sizeof"                        { update_line_col(); return(SIZEOF); }
"return"						{ update_line_col(); return(RETURN); }

"struct"						{ update_line_col(); return(STRUCT); }

{L}({L}|{D})*                   {
                                for(int i=0;i<10;i++){
                                if(strcmp(yytext, keywords[i])==0)
                                    yyerror("Un identificateur ne peut pas prendre le nom d'un mot clé.");
                                }
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


void update_line_col(void)
{
	int i;
	//fprintf(yyout,"%s", yytext);
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
