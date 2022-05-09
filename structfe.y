%{
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "definitions.h"
    

extern int line,prevCol;
char *strucit_frontend;
char message[100]; // for more info regardind errors.
void yyerror(char *);
void warning(char *); // ?
int yylex();
    
/* ----------------------------declarations--------------------------------- */
    
enum Type type;
int nb_params=0, nb_args=0, nb_fields=0; // check nb_params = nb_args when calling function
int struct_id;
struct Ast_node *ast_root;
struct Hash_Table Symbols_Table;

int is_in_structure=0; // when declaring pointers to functions
struct Symbol *curFunctionSym = NULL;

int whileTop=-1,vtop=-1,return_top=-1;

struct Symbol *while_stack[20],*return_stack[20],*var_stack[253];

int verif_postexpr = 0;
     
%}

/* ------------------------------------------------------------- */


/* YYSTYPE union */
%union {
  int yint;
  char ystr[30];
  struct Ast_node* node;
}

%token<ystr> IDENTIFIER
%token<yint> CONSTANT
%token SIZEOF
%token PTR_OP LE_OP GE_OP EQ_OP NE_OP AND_OP OR_OP
%token EXTERN INT VOID STRUCT
%token IF ELSE WHILE FOR BREAK RETURN

%type <node> primary_expression postfix_expression argument_expression_list
%type <node> unary_expression unary_operator
%type <node> multiplicative_expression additive_expression relational_expression equality_expression
%type <node> logical_and_expression logical_or_expression expression
%type <node> type_specifier declaration_specifiers
%type <node> struct_specifier struct_declaration_list var_declaration function_declaration
%type <node> declarator parameter_list function_parameter
%type <node> statement compound_statement declaration_list statement_list
%type <node> expression_statement selection_statement iteration_statement
%type <node> program external_declaration start

%right '='
%left '+' '-'
%left '*' '/'
%nonassoc UNARY_MINUS
%nonassoc PRIORITY_LOWER_THAN_ELSE
%nonassoc PRIORITY_LOWER_THAN_COMPOUND_STMT
%nonassoc '{'
%nonassoc '('
%nonassoc ELSE
%start start
%%

start : program { ast_root = makeNode (astStart, NULL, $1, NULL, NULL, NULL);
      }
      ;
program
      : external_declaration {
    $$ = makeNode (astProgram, NULL, $1, NULL, NULL, NULL);
      }
      | program external_declaration {
    $$ = makeNode (astProgram, NULL, $1, $2, NULL, NULL);
      }
      ;
            
primary_expression
     : IDENTIFIER {
        //verif if IDENT declared or accessible
        struct Symbol *sym;
        sym = find_variable($1);
        if(sym == NULL){
            sprintf(message,"Usage d'un identificateur nedéclaré '%s' \n",$1);
            yyerror(message);
        }
        
        $$ = makeNode (astId, sym, NULL, NULL, NULL, NULL);
       // $$ = makeNode(astPrimExp, sym, )
    }//symbol
    | CONSTANT {
        struct Symbol *sym;
        char temp[10] = "intCONST";
        sym = makeSymbol (temp, isINT, $1, 4, 'c', 0); // don't add to sym_tab
        $$ = makeNode (astConst, sym, NULL, NULL, NULL, NULL);
    }//symbol
    | '(' expression ')' {
        $$ = $2;
        $$ ->node_type = astExpr;
    }
    ;

postfix_expression
    : primary_expression { // $1 = astId/ astConst/ astExpr
        $$ = $1;
        verif_postexpr++;
    }//symbol
    
    | postfix_expression '(' ')' { //verif nb_args = 0
        if($1->node_type == astId){
        struct Symbol *sym;
        sym = find_variable ($1->symbol_node->name);
        if(sym == NULL || (sym !=NULL && sym->type != FUNCTION)){
            sprintf(message,"Declaration implicte de fonction '%s' est invalide. \n",$1->symbol_node->name);
            yyerror(message);
        }
        }
        if ($1->node_type == astExpr || $1->node_type == astConst){
            yyerror("Objet appelé de type 'int' n'est pas une fonction ou pointeur sur function");
        }
        if ($1->node_type == astFuncCall){ // = f(...)(...)
            yyerror("Objet appelé de type 'return type' n'est pas une fonction ou pointeur sur function");
        }
    
        $$ = makeNode(astFuncCall, $1->symbol_node, $1, NULL, NULL, NULL);
        verif_postexpr++; // delete?
    }//symbol
    | postfix_expression '(' argument_expression_list ')' { // verif nb_args = nb_params
        if($1->node_type == astId){
        struct Symbol *sym;
        sym = find_variable ($1->symbol_node->name); // && sym->is_in_func = 1
        if(sym == NULL){
            sprintf(message,"Declaration implicte de fonction '%s' est invalide. \n",$1->symbol_node->name);
            yyerror(message);
        }
        }
        if ($1->node_type == astExpr || $1->node_type == astConst){
            yyerror("Objet appelé de type 'int' n'est pas une fonction ou pointeur sur function");
        }
        if ($1->node_type == astFuncCall){ // = f(...)(...)
            yyerror("Objet appelé de type 'return type' n'est pas une fonction ou pointeur sur function");
        }
        
        $1->node_type = astFuncCall;
        $$ = makeNode(astFuncCall, $1->symbol_node, $1, NULL, NULL, NULL);
        verif_postexpr++;
    }//symbol
    
    | postfix_expression PTR_OP IDENTIFIER {
        
        if($1->node_type != astId){ // 12->id / (2+3)->id
            yyerror("Membre reference type 'int' n'est pas un pointeur");
        }
        
        struct Symbol *from_struct;
        from_struct = $1->symbol_node->pointed_struct; // find name of structure pointed by id
        
        struct Symbol **fields;
        fields = from_struct->fields_list;
        int found = 0;
        int i;
        for (i=0;i<from_struct->nb_elements;i++){
            if(strcmp(fields[i]->name, $3) == 0)
            found=1;
            break;
        }
          
        if (found == 0){
            sprintf(message,"Pas de membre %s dans 'struct %s' \n", $3, from_struct->name);
            yyerror(message);
        }
        else{
            
            struct Ast_node *field = malloc(sizeof(struct Ast_node));
            assert(field != NULL);
            field->node_type = astId;
            field->symbol_node = malloc(sizeof(struct Symbol));
            assert(field->symbol_node != NULL);
            strcpy(field->symbol_node->name, $3);
            field->symbol_node->type = fields[i]->type;
            
            $$ = makeNode(astPointerTo, $1->symbol_node, field, NULL, NULL, NULL);
        }
    }//symbol
    ;


argument_expression_list
    : expression {
        $$ = $1;
        nb_args = 1;
    }
    | argument_expression_list ',' expression{
        $$ = makeNode(astArgs, NULL, $1, $3, NULL, NULL);
        nb_args++; // to verify if nb args = nb_param of function
    }
    ;

unary_expression
    : postfix_expression {
        $$ = $1;
    }//symbol?
    | unary_operator unary_expression{
        $$ = analyse_unary($1, $2);
    }//symbol
    
    | SIZEOF unary_expression {
       if($2->node_type != astId) // astConst/ astFuncCall/astPointerTo/ (expression)
       yyerror("L'argument de la fonction prédéfinie 'sizeof' n'est pas un pointeur sur une structure.");
       if($2->symbol_node->type != POINTER_TO_STRUCT)
           yyerror("L'argument de la fonction prédéfinie 'sizeof' n'est pas un pointeur sur structure.");
        //else
        struct Symbol *sym = malloc(sizeof(struct Symbol));
        assert (sym!=NULL);
        sym->size = sizeof($2->symbol_node->pointed_struct->size); // calculated size of struct IDENT
        $$ = makeNode (astSize, sym, $2, NULL, NULL, NULL);
    }
    ;

unary_operator
    : '&' {
        $$ = makeNode (astAdress, NULL, NULL, NULL, NULL, NULL);
    }
    | '*' {
        $$ = makeNode (astStar, NULL, NULL, NULL, NULL, NULL);
    }
    
    ;

multiplicative_expression
    : unary_expression {
        $$ = $1;
    }
    | multiplicative_expression '*' unary_expression{
        if ($1->expression_type == POINTER || $3->expression_type == POINTER)
        yyerror("Operands invalids pour une expression binaire.");
        $$ = makeNode (astMul, NULL, $1, $3, NULL, NULL);
        $$->expression_type = isINT;
    }
    | multiplicative_expression '/' unary_expression {
        if ($1->expression_type == POINTER || $3->expression_type == POINTER)
        yyerror("Operands invalids pour une expression binaire.");
        $$ = makeNode (astDiv, NULL, $1, $3, NULL, NULL);
        $$->expression_type = isINT;
    }
    ;

additive_expression
    : '-' multiplicative_expression %prec UNARY_MINUS {
        if($2->expression_type == isINT) // -int
            $$->expression_type = isINT;
        if($2->expression_type == POINTER) // -p
            $$->expression_type = POINTER;
    $$ = makeNode (astUnaryM, NULL, $2, NULL, NULL, NULL);
}
    | multiplicative_expression{
        $$ = $1;
    }
    | additive_expression '+' multiplicative_expression{
        $$ = makeNode (astAdd, NULL, $1, $3, NULL, NULL);
        if($1->expression_type == isINT && $3->expression_type == isINT) // int + int
            $$->expression_type = isINT;
        if($1->expression_type == isINT && $3->expression_type == POINTER || ($3->expression_type == isINT && $1->expression_type == POINTER )) // pointer+int
            $$->expression_type = POINTER;
    }
    | additive_expression '-' multiplicative_expression{
        $$ = makeNode (astSub, NULL, $1, $3, NULL, NULL);
        if($1->expression_type == isINT && $3->expression_type == isINT) // int - int
            $$->expression_type = isINT;
        if($1->expression_type == isINT && $3->expression_type == POINTER || ($3->expression_type == isINT && $1->expression_type == POINTER )) // pointer-int
            $$->expression_type = POINTER;
    }
    ;

relational_expression
    : additive_expression {
        $$ = $1;
    }
    | relational_expression '<' additive_expression{
        if($3->expression_type == isINT && $1->expression_type == POINTER || ($1->expression_type == isINT && $3->expression_type == POINTER))
        yyerror("Comparaison entre pointeur et entier.");
        $$->expression_type = $1->expression_type;
        
    }
    | relational_expression '>' additive_expression{
        if($3->expression_type == isINT && $1->expression_type == POINTER || ($1->expression_type == isINT && $3->expression_type == POINTER))
        yyerror("Comparaison entre pointeur et entier.");
        $$->expression_type = $1->expression_type;
    }
    | relational_expression LE_OP additive_expression{
        if($3->expression_type == isINT && $1->expression_type == POINTER || ($1->expression_type == isINT && $3->expression_type == POINTER))
        yyerror("Comparaison entre pointeur et entier.");
        $$->expression_type = $1->expression_type;
        
    }
    | relational_expression GE_OP additive_expression{
        if($3->expression_type == isINT && $1->expression_type == POINTER || ($1->expression_type == isINT && $3->expression_type == POINTER))
        yyerror("Comparaison entre pointeur et entier.");
        $$->expression_type = $1->expression_type;
    }
    ;

equality_expression
:    relational_expression {
        $$ = $1;
}
    | equality_expression EQ_OP relational_expression {
        if($3->expression_type == isINT && $1->expression_type == POINTER || ($1->expression_type == isINT && $3->expression_type == POINTER))
        yyerror("Comparaison entre pointeur et entier.");
        $$ = makeNode (astEq, NULL, $1, $3, NULL, NULL);
}
    | equality_expression NE_OP relational_expression {
        if($3->expression_type == isINT && $1->expression_type == POINTER || ($1->expression_type == isINT && $3->expression_type == POINTER))
        yyerror("Comparaison entre pointeur et entier.");
        $$ = makeNode (astNeq, NULL, $1, $3, NULL, NULL);
}
    ;

logical_and_expression
    : equality_expression {
        $$ = $1;
}
    | logical_and_expression AND_OP equality_expression {
        $$ = makeNode (astAnd, NULL, $1, $3, NULL, NULL);
        $$->expression_type = isINT;
    }
    ;

logical_or_expression
    : logical_and_expression {
        $$ = $1;
}
    | logical_or_expression OR_OP logical_and_expression {
        $$ = makeNode (astOr, NULL, $1, $3, NULL, NULL);
        $$->expression_type = isINT;
}
    ;

expression
    : logical_or_expression {
        $$ = $1;
}

// error: illegal initializer (only variables can be initialized) -> int f() = 10;
    | unary_expression '=' expression { // expression cannot contain &&/ || - verif children
        
        $$ = makeNode (astExpr, NULL, $1, $3, NULL, NULL); // !
        if($1->node_type == astConst || $1->node_type == astFuncCall || $1->node_type == astSize)
                yyerror("Operands invalids pour une expression binaire. "); // f() = / 3 = / sizeof(p) =
        if($1->node_type == astId){ // id/func. =
            struct Symbol *sym;
            sym = find_variable ($1->symbol_node->name);
            if(sym == NULL){
                sprintf(message, "Variable '%s' utilisé non-déclarée.", $1->symbol_node->name);
                yyerror(message);
            }
            if(sym->type == FUNCTION) {// func =
                sprintf(message, "Fonction %s n'est pas assignable.", $1->symbol_node->name);
                yyerror(message);
            }
               
            
        }
        
        if($1->symbol_node->type >= 5)
            $$->expression_type = POINTER;
        else
            $$->expression_type = isINT;
        if($1->node_type == astPointerTo){
            if($1->child_node[0]->symbol_node->type >= 5)
                $$->expression_type = POINTER;
            else
                $$->expression_type = isINT;
        }
    }
    ;


var_declaration
    : declaration_specifiers declarator {
        if($1->child_node[0]->node_type == astExt){ // is_extern is 1st child. check 2nd
              $2->symbol_node->is_extern = 1;
            complete_type($2->symbol_node,$1->child_node[1]);
}
        else // variable is not EXTERN
            complete_type($2->symbol_node, $1->child_node[0]);

        $$ = makeNode (astVarDecl, $2->symbol_node, $1, $2, NULL, NULL);
}
    ;
    
declaration_specifiers
    : EXTERN type_specifier {
        struct Ast_node *ext_node = makeNode(astExt, NULL, NULL, NULL, NULL, NULL);
        $$ = makeNode(astDeclSpecs, NULL, ext_node, $2, NULL, NULL);
    }
    | type_specifier {
        $$ = makeNode(astDeclSpecs, NULL, $1, NULL, NULL, NULL);
    }
    ;
            
type_specifier
    : VOID {
        $$ = makeNode (astVoid, NULL, NULL, NULL, NULL, NULL); // verify type when reducing
    }
    
    | INT {
        $$ = makeNode (astInt, NULL, NULL, NULL, NULL, NULL);
    }
    | struct_specifier {
        $$ = $1; // where is size calculated ?
    }
    ;
            

struct_specifier
    : STRUCT IDENTIFIER '{' struct_declaration_list '}' {
        struct Symbol *sym=malloc(sizeof(struct Symbol));
        assert(sym!=NULL);
        sym = makeSymbol($2, isSTRUCT, 0, 0, 's', nb_params);
        sym->fields_list = var_stack;
        for (int i=0;i<=vtop;i++){
            printf("\n var[%d], %s", i, var_stack[i]->name);
        }
        printf("\n0000000 nb fields %d 00000\n", nb_fields);
        printVStack();
        Empty_Stack(nb_fields);
        printf("\n0000000 stack is epmty ?00000\n");
        printVStack();
        sym->from_function = curFunctionSym;
        if(curFunctionSym !=NULL)
        printf("----- Surrent func - %s -----", curFunctionSym->name);
        $$ = makeNode(astStruct, sym, NULL, NULL, NULL, NULL);
        nb_fields=0;
    }
    | STRUCT '{' struct_declaration_list '}' {
        struct Symbol *sym=malloc(sizeof(struct Symbol));
        assert(sym!=NULL);
        
        char temp[5];
        sprintf(temp, "%d", struct_id);
        sym = makeSymbol(temp, isSTRUCT, 0, 0, 's', nb_params);
        sym->fields_list = var_stack;
        printVStack();
        Empty_Stack(nb_fields);
        sym->from_function = curFunctionSym;
        printf("----- Surrent func - %s -----", curFunctionSym->name);
        $$ = makeNode(astStruct, sym, NULL, NULL, NULL, NULL);
        nb_fields=0;
    }
    | STRUCT IDENTIFIER %prec PRIORITY_LOWER_THAN_COMPOUND_STMT {
        struct Symbol *sym=malloc(sizeof(struct Symbol));
        assert(sym!=NULL);
        sym = makeSymbol($2, isSTRUCT, 0, 0, 's', 0);
        sym->fields_list= NULL;
        $$ = makeNode (astStruct, sym, NULL, NULL, NULL, NULL);
        nb_fields=0;
    }
    ;
    
/* Types des variables et des champs des structures : int et pointeur sur structure, sur fonction ou sur int. */
struct_declaration_list
    : var_declaration ';' { // not a POINTER_TO_FUNC
        $1->symbol_node->from_struct = 1;
        if($1->symbol_node->type != isINT && $1->symbol_node->type != POINTER_TO_STRUCT && $1->symbol_node->type != POINTER_TO_INT)
            yyerror("Variable avec un type illegale déclarée dans une structure.");
            $$ = $1;
            pushV($1->symbol_node);
        nb_fields++;
}
    
    | function_declaration ';' {
        $1->symbol_node->from_struct = 1;
        pushV($1->symbol_node);
        nb_fields++;
}
    | struct_declaration_list var_declaration ';' {
        $2->symbol_node->from_struct = 1;
        $$ = makeNode (astStructList, NULL, $1, $2, NULL, NULL);
        pushV($2->symbol_node);
        nb_fields++;
    }
    | struct_declaration_list function_declaration ';' {
        $2->symbol_node->from_struct = 1;
        $$ = makeNode (astStructList, NULL, $1, $2, NULL, NULL);
        pushV($2->symbol_node);
        nb_fields++;
    }
    ;

        
parameter_list
    : function_parameter {
        $$ = $1;
        nb_params=1;
}
    | parameter_list ',' function_parameter {
        $$ = makeNode(astParamList, NULL, $1, $3, NULL, NULL );
        nb_params++;
}
    ;
    
function_parameter
    : var_declaration {
        if($1->symbol_node->type != isINT && $1->symbol_node->type != POINTER_TO_STRUCT && $1->symbol_node->type != POINTER_TO_INT){
            sprintf(message,  "Parametre '%s' de fonction a un type illegale.", $1->symbol_node->name);
            yyerror(message);
        }
        $1->symbol_node->from_function = curFunctionSym;
        $$ = $1;
        pushV($$->symbol_node);
}
    | function_declaration {
        $1->symbol_node->from_function = curFunctionSym;
        $$ = $1;
        pushV($$->symbol_node);
}
    ;
            
statement
    : compound_statement {
        $$ = $1;
    }
    | expression_statement{
        $$ = $1;
    }
    | selection_statement{
        $$ = $1;
    }
    | iteration_statement{
        $$ = $1;
    }
    | RETURN ';'{ // astReturn doesn't have children
        $$ = makeNode(astReturn, NULL, NULL, NULL, NULL, NULL);
    }
    | RETURN expression ';'{
        printf("\n****** in return stmt ******\n");
        $$ = makeNode (astReturnExpr, NULL, $2, NULL, NULL, NULL);
    }
    ;


compound_statement
    : '{' '}' {
        $$ = makeNode(astEmpty, NULL, NULL, NULL, NULL, NULL);
        curFunctionSym = NULL;
    }
    | '{' statement_list '}' {
        $$ = $2;
    }
    | '{' declaration_list '}' {
        $$ = $2;
    }
    | '{' declaration_list statement_list '}' {
        $$ = makeNode(astBlock, NULL, $2, $3, NULL, NULL);
    }
    ;

declaration_list
    : var_declaration ';'{
        if (curFunctionSym->type == POINTER_TO_FUNC){
            yyerror("Déclaration d'un pointeur sur fonction attendu.");
        }
        $1->symbol_node->from_function = curFunctionSym;
        printf("----- Currenttt func - %s -----", curFunctionSym->name);
        $$ = $1;
        add_variable_to_table($1->symbol_node);
    }
    | function_declaration ';' {
        if (curFunctionSym->type !=POINTER_TO_FUNC)
        yyerror("Declaration d'un pointeur sur fonction attendu.");
        $1->symbol_node->from_function = curFunctionSym;
        $$ = $1;
        printf("----- Surrent func - %s -----", curFunctionSym->name);
        add_variable_to_table($1->symbol_node);
    }
    | declaration_list var_declaration ';' {
        if (curFunctionSym->type == POINTER_TO_FUNC){
            yyerror("Déclaration d'un pointeur sur fonction attendu.");
        }
        $2->symbol_node->from_function = curFunctionSym;
        $$ = makeNode (astDeclList, NULL, $1, $2, NULL, NULL);
        printf("----- Surrent func - %s -----", curFunctionSym->name);
        add_variable_to_table($2->symbol_node);
    }
    |declaration_list function_declaration ';' {
        if (curFunctionSym->type != POINTER_TO_FUNC)
        yyerror("Declaration d'un pointeur sur fonction attendu.");
        $2->symbol_node->from_function = curFunctionSym;
        $$ = makeNode (astDeclList, NULL, $1, $2, NULL, NULL);
        printf("----- Surrent func - %s -----", curFunctionSym->name);
        add_variable_to_table($2->symbol_node);
    }
    ;

statement_list
    : statement {
        $$ = $1;
    }
    | statement_list statement {
        $$ = makeNode (astStmtsList, NULL, $1, $2, NULL, NULL);
    }
    ;

expression_statement
    : ';' {
        $$ = makeNode(astEmpty, NULL, NULL, NULL, NULL, NULL);
    }
    | expression ';' {
        $$ = $1;
    }
    ;

selection_statement
    : IF '(' expression ')' statement %prec PRIORITY_LOWER_THAN_ELSE {
        struct Ast_node *if_node = malloc(sizeof(struct Ast_node));
        assert(if_node != NULL);
        
        $$ = makeNode (astSelStmt, NULL, $3, $5, NULL, NULL);
    }
    | IF '(' expression ')' statement ELSE statement {
        struct Ast_node *if_node, *else_node;
        if_node = malloc(sizeof(struct Ast_node));
        else_node = malloc(sizeof(struct Ast_node));
        assert(if_node != NULL);
        assert(else_node != NULL);
        
        $$ = makeNode (astSelStmt, NULL, $3, $5, $7, NULL);
    }
    ;

iteration_statement
    : WHILE '(' expression ')' statement {
        $$ = makeNode (astWhile, NULL, $3, $5, NULL, NULL);
    }
    | FOR '(' expression_statement expression_statement expression ')' statement {
        $$ = makeNode (astFor, NULL, $3, $4, $5, $7);
    }
    ;
    
external_declaration
    : var_declaration ';' {
        if ($1->symbol_node->type == POINTER_TO_FUNC){
            yyerror("Déclaration d'un pointeur sur fonction attendu.");
        }
        $1->symbol_node->from_function = NULL;
        $1->symbol_node->tag = 'v';
        add_variable_to_table($1->symbol_node);
        $$ = makeNode (astExtDecl,  $1->symbol_node, $1, NULL, NULL, NULL);
        curFunctionSym = NULL;
    }
    | struct_specifier ';' {
        $1->symbol_node->from_function = NULL;
        $1->symbol_node->tag = 's';
        add_variable_to_table($1->symbol_node);
        $$ = makeNode (astExtDecl, $1->symbol_node, $1, NULL, NULL, NULL);
        curFunctionSym = NULL;
    }
    
    | function_declaration compound_statement { // function definition
        printf("\n((((((in func def))))))\n");
       //else it is type FUNCTION, already managed
       $$ = makeNode (astExtDecl, NULL, $1, $2, NULL, NULL);
       $1->symbol_node->tag = 'f';
       add_variable_to_table($1->symbol_node);
       curFunctionSym = NULL;
    }
    | function_declaration ';' {
        $$ = makeNode (astExtDecl, $1->symbol_node, $1, NULL, NULL, NULL);
        $1->symbol_node->from_function = NULL;
        $1->symbol_node->tag = 'f';
        add_variable_to_table($1->symbol_node);
        Print_Table();
        curFunctionSym = NULL;
    }
    ;
        
declarator // complete type in var_decl derivation
    : IDENTIFIER {
        struct Symbol *sym=malloc(sizeof(struct Symbol));
        assert(sym!=NULL);
        sym = makeSymbol($1, UNDEFINED, 0, 0, 'v', 0);
        $$ = makeNode(astDeclarator, sym, NULL, NULL, NULL, NULL);
    }
    
    | '(' '*' IDENTIFIER ')' {
        struct Symbol *sym=malloc(sizeof(struct Symbol));
        assert(sym!=NULL);
        sym = makeSymbol($3, POINTER_TO_FUNC, 0, 8, 'v', 0);
        $$ = makeNode(astDeclarator, sym, NULL, NULL, NULL, NULL);
    }
    
    | '*' IDENTIFIER {
        struct Symbol *sym=malloc(sizeof(struct Symbol));
        assert(sym!=NULL);
        sym = makeSymbol($2, POINTER, 0, 0, 'v', 0);
        $$ = makeNode(astDeclarator, sym, NULL, NULL, NULL, NULL);
    }
    
    | '*' '(' '*' IDENTIFIER ')' {
        struct Symbol *sym=malloc(sizeof(struct Symbol));
        assert(sym!=NULL);
        sym = makeSymbol($4, POINTER_TO_FUNC, 0, 0, 'v', 0);
        sym->returns_pointer=1;
        $$ = makeNode(astDeclarator, sym, NULL, NULL, NULL, NULL);

    }
    
    ;
        
        
/* les types de retour ne peuvent être que type de base ou pointeur sur structure ou constantes */
function_declaration
    : var_declaration '(' parameter_list ')' { // now IDENT in var_decl is FUNCTION/POINTER_TO_FUNC
        // sym->type = POINTER_TO_FUNCTION managed in var_decl derivation
        if($1->symbol_node->type != POINTER_TO_FUNC){
            $1->symbol_node->function_return_type = $1->symbol_node->type;
            $1->symbol_node->type = FUNCTION;
        }
        
        for(int i=0;i<=vtop;i++){
            var_stack[i]->from_function = $1->symbol_node;
        }

        printf ("\n nb_params %d\n", nb_params);
        printVStack();
        $1->symbol_node->param_list = var_stack;
        $1->symbol_node->nb_elements = nb_params;
        Empty_Stack(nb_params);
        $$ = makeNode(astFunctionDecl, $1->symbol_node, $1, $3, NULL, NULL);
        curFunctionSym = $$->symbol_node; // only for func_def
        printf("-----Current func - %s -----", curFunctionSym->name);
        nb_params = 0;
}
    | var_declaration '(' ')' {
        // sym->type = POINTER_TO_FUNCTION managed in var_decl derivation
        if($1->symbol_node->type != POINTER_TO_FUNC){
            $1->symbol_node->function_return_type = $1->symbol_node->type;
            $1->symbol_node->type = FUNCTION;
        }
        
        printVStack();
        $1->symbol_node->param_list = NULL; // no params
        $1->symbol_node->nb_elements = 0;
        
        $$ = makeNode(astFunctionDecl, $1->symbol_node, $1, NULL, NULL, NULL);
        
      curFunctionSym = $$->symbol_node; // only for func_def
        printf("----- Surrent func - %s -----", curFunctionSym->name);
    }
    ;
%%

void warning(char *s)
{
	printf("\n%d:%d : Warning: ", line,prevCol);
	printf("\"%s\"\n",s);
}

void yyerror(char *s)
{
	printf("\033[25m\n%d:%d : error: ",line, prevCol);
	printf("\033[25m\"%s\"\n",s);
    Print_Table();
	exit (-1);
}
    
    

//gen key for Hash Tables
int genKey(char *s)
{
    char *p;
    int athr=0;
    for(p=s; *p; p++)
    athr=athr+(*p);
    return (athr % SYM_TABLE_SIZE);
}
    
    
    // + free memory ?
    void init_tables(){
        for(int i=0;i<SYM_TABLE_SIZE;i++){
            Symbols_Table.symbols[i] = NULL;
        }
    }
    

void Print_Table(){
        printf("\n------- Symbols table ---------\n");
        printf("Var_Name\tFrom_func\tDatatype\n");
        for (int i=0;i<SYM_TABLE_SIZE;i++){
            struct Symbol *sym;
            sym = Symbols_Table.symbols[i];
            while(sym!=NULL){
                
                if(sym->from_function == NULL)
                printf("%s\t\tGlobal var\t%d\n", sym->name, sym->type);
                else
                printf("%s\t\t%s\t%d\n", sym->name,sym->from_function->name, sym->type);
                
                sym = sym->next;
            }
        }
}
    
    
    struct Symbol *makeSymbol(char *name, enum Type type, int value, int size, char tag, int nb_elements){
    
    struct Symbol *temp = (struct Symbol*)malloc(sizeof(struct Symbol));
    assert(temp!=NULL);
    strcpy(temp->name,name);
    temp->type = type;
    temp->tag = tag;
    temp->pointed_struct = NULL;
    temp->size = size;
    temp->nb_elements = nb_elements;
    temp->from_function = NULL;
    temp->param_list = NULL;
    temp->fields_list = NULL;
    temp->next = NULL;
    
    return temp;
}
    
struct Ast_node* makeNode(int type, struct Symbol *sym, struct Ast_node* first, struct Ast_node *second, struct Ast_node *third,struct Ast_node *fourth){
    
    struct Ast_node *ptr = (struct Ast_node*)malloc(sizeof(struct Ast_node));
    assert(ptr!=NULL);
    
    ptr->node_type=type;
    ptr->symbol_node=sym;
    ptr->child_node[0] = first;
    ptr->child_node[1] = second;
    ptr->child_node[2] = third;
    ptr->child_node[3] = fourth;
    return ptr;
}
    
    
void add_variable_to_table(struct Symbol *symbp)
{
        struct Symbol *exists;
        exists = find_variable(symbp->name);
        if( !exists )
            add_variable(symbp);
        else
        {
            sprintf(message, "Variable '%s' déja déclarée. ", symbp->name);
            yyerror(message);
        }
}
    
void add_variable(struct Symbol *symbp)
{
      int i;
      struct Symbol *ptr, *prev;
      
      i = genKey(symbp->name);
      ptr = Symbols_Table.symbols[i];
      prev = NULL;
      
      while(ptr != NULL){
          ptr = ptr->next;
          prev = ptr;
      }
      
      if(prev == NULL){
          Symbols_Table.symbols[i] = malloc(sizeof (struct Symbol));
          assert(Symbols_Table.symbols[i] !=NULL);
          
          Symbols_Table.symbols[i]->next = NULL;
          Symbols_Table.symbols[i] = symbp;
      }
      else{
          
          prev->next = malloc(sizeof (struct Symbol));
          prev->next = symbp;
          prev->next->next = NULL;
      }
      Symbols_Table.nbSymbols++;
}
    
struct Symbol *find_variable(char *s)
{
      int i;
      struct Symbol *ptr;
      struct Hash_Table table = Symbols_Table;

      i = genKey(s);
      ptr = table.symbols[i];
    
    while(ptr){
        if(strcmp(ptr->name,s) ==0){
            if(ptr->from_function== NULL){ // found a global var with the same name
                if (curFunctionSym == NULL) //  new var = global
                    return ptr; // don't add it
                else // new var is in function and found var is global. ok.
                    return NULL;
            }
            else{ /// found a var with the same name in a function
                if (curFunctionSym == NULL)/// new var = global
                    return NULL; /// can add it
                if(curFunctionSym->name == ptr->from_function->name)
                    return ptr; /// already have a var with same name in same function
               
            }
        }
        
        ptr=ptr->next;
    }
      
      return ptr;
}
    
    
/* Types des variables et des champs des structures : int et pointeur sur structure, sur fonction ou sur int */
void complete_type (struct Symbol *sym, struct Ast_node *child_node){
    
    int temp_type1;
    enum Type temp_type2;
             
    temp_type1 = child_node->node_type; // from astDeclSpecs
    switch(temp_type1){
            case astInt:
                 temp_type2 = isINT;
                 break;
            case astVoid:
                 temp_type2 = isVOID; // sym should be a function/pointer to function !!!
                 break;
            case astStruct:
                 temp_type2 = isSTRUCT;
                 break;
        } // isType/Pointer to isType. check next
    switch(sym->type){
        case UNDEFINED:
                if(temp_type2 == isSTRUCT){
                    sprintf(message, "La variable '%s' est de type (struct ) mais pas un pointeur.\n", sym->name);
                    yyerror(message);
                    break;
                }
                sym->type = temp_type2;
                break;
/* check isVOID for var_decl; */

        case POINTER:
                if(temp_type2 == isINT)
                    sym->type = POINTER_TO_INT;
                if(temp_type2 == isVOID)
                    yyerror("Déclaration d'une variable avec un type illegal (void *).");
                if(temp_type2 == isSTRUCT){
                    printf ("\n##### case pointer, is struct ####\n");
                    sym->type = POINTER_TO_STRUCT;
                    sym->pointed_struct = child_node->symbol_node;
                    }
                break;
/* les types de retour ne peuvent être que type de base ou pointeur sur structure ou constantes ; */
        case POINTER_TO_FUNC: // sym->type = POINTER_TO_FUNCTION
            if(sym->returns_pointer == 1) { // int/void/struct * (*id)...
                printf ("\n##### case pointer_to_func, returns pointer ####\n");
                if(temp_type2 == isINT)
                sym->function_return_type = POINTER_TO_INT;
                if(temp_type2 == isVOID)
                yyerror("Pointeur sur fonction avec un type de retour illegal (void *). ");
                if(temp_type2 == isSTRUCT){
                    sym->function_return_type = POINTER_TO_STRUCT;
                    sym->pointed_struct = child_node->symbol_node; // pointed structure for return type!!
                }
                
           
            }
            else{ // int/void/struct (*id)...
                if(temp_type2 == isSTRUCT)
                    yyerror("Pointeur sur fonction avec un type de retour illegal (struct ).");
                else
                      sym->function_return_type = temp_type2;
            }
            break;
            default : printf ("in complete_type function");
                      exit(0);
                      break;
}
}

void pushV (struct Symbol *sym){
    var_stack[++vtop]=sym;
}
    
struct  Symbol* popV() {
    return var_stack[vtop--];
}
    
    
void printVStack(){
        printf("\n------- VARIABLE STACK -------\n");
        printf("name\tfunc_name\ttype\tvtop\n");
        for (int i=vtop; i>=0; i--){
            if(var_stack[i]->from_function!=NULL)
            printf("%s\t%s\t\t%d\t%d\n", var_stack[i]->name, var_stack[i]->from_function->name, var_stack[i]->type, vtop);
            else{
                printf("%s\t\t%d\t%d\n", var_stack[i]->name, var_stack[i]->type, vtop);
            }
        }
        printf("------------- END ------------\n");
}
    
void Empty_Stack(int nb_elements) {
        int i;
        struct Symbol *temp;
        for(i = 0; i < nb_elements; i++)
            temp = popV();
}
    
    
// unary_expression -> unary_operator unary_expression => &/* unary_expr
struct Ast_node* analyse_unary(struct Ast_node *child1,struct Ast_node *child2) {
   
    struct Ast_node *result;
        if(child1->node_type == astAdress){ // & retourne l’adresse d’une variable
            if(child2->node_type == astId){
                // already verif if ident exists in primary_expr
                switch (child2->symbol_node->type){ // int id;  ...&id
                    case isINT:
                    result = makeNode(astUnExpr,child2->symbol_node, child1, child2, NULL, NULL);
                    result->symbol_node->type = POINTER_TO_INT;
                    break;
                    case FUNCTION:
                    yyerror ("Operateur & sur une fonction inattendu STRUCIT.");
                    break;
                    case POINTER_TO_INT:
                    yyerror("Pointeur multiple n'est pas accepté en STRUCIT.");
                    break;
                    case POINTER_TO_FUNC:
                    yyerror("Pointeur multiple n'est pas accepté en STRUCIT.");
                    break;
                    case POINTER_TO_STRUCT:
                    yyerror("Pointeur multiple n'est pas accepté en STRUCIT.");
                    break;
                    default: printf("default in function analyse.");break;
                     } }
              else // CONSTANT / function return type
                {   if (child2->node_type == astConst)// &astConst
                    yyerror("Ne peut pas prendre l'adresse d'une valeur de retour.");
                    if (child2->node_type == astFuncCall){ // &func(...)
                        // already verifieds if func exists in postfix_expr
                        switch (child2->symbol_node->function_return_type){
                            case isVOID: // f-> void f(...)
                            yyerror ("Operateur & sur une fonction avec un type de retour (void ) inattendu STRUCIT.");
                            break;
                            case isINT: // f-> int f(...)
                            yyerror("Ne peut pas prendre l'adresse d'une valeur de retour.");
                            break;
                            default: // f-> POINTER_TO... f(...)
                            yyerror("Pointeur multiple n'est pas accepté en STRUCIT.");
                            break;
                    } } } }
        else{ //astStar - derref
            if(child2->node_type == astId){ // *id. *func.
                // already verified if ident exists, in primary_expr
                switch (child2->symbol_node->type){
                    case isINT: // int id;  ... *id
                    yyerror("Indirection requires pointer -second- operand ('int' invalid). ");
                    break;
                    case FUNCTION: //int (*d)(); d =  *f; == d= f; f - func designator - OK !
                    // f = pointer to func = function =...=...
                    result = makeNode(astUnExpr, child2->symbol_node, child1, child2, NULL, NULL);
                    result->symbol_node->type = POINTER_TO_FUNC; // verif left operand is pointer to func returning $2 - return type
                    break;
                    default: break; } }
            else // *astConst | *func(...)
            {
                if(child2->node_type == astConst)
                yyerror("cannot take the address of an rvalue of type 'int'");
                if(child2->node_type == astFuncCall){ // * f()
                    if (child2->symbol_node->returns_pointer !=1 ) // derref (int f())/(void f())  ?!
                    yyerror("cannot take the address of an rvalue of type 'int'");
                    else{
                        /* les types de retour ne peuvent être que type de base ou pointeur sur structure ou constantes ; */
                        // case POINTER_TO_FUNCTION doesn't exist here!
                        if(child2->symbol_node->function_return_type == POINTER_TO_STRUCT)
                        yyerror("Variable de type (struct ) déréférencé de type de retour (struct *) n'est pas acceptée in STRUCIT.");
                        if(child2->symbol_node->function_return_type == POINTER_TO_INT){
                            result = makeNode(astUnExpr, child2->symbol_node, child1, child2, NULL, NULL);
                            result->symbol_node->type = isINT;
                        }
                    } }} }
            return result;
}
        
