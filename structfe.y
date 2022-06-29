%{
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "definitions.h"

extern int line,prevCol;
char *strucit_frontend;
FILE *strucit_backend;
char message[200]; // errors info
void yyerror(char *);
extern FILE *yyin;
extern FILE *yyout;
int yylex();
    
/** ---------------------------- declarations --------------------------------- **/
    
enum Type type;
int nb_params=0, nb_args=0, nb_fields=0;
int struct_id=1;

struct Ast_node *ast_root;
struct Hash_Table Symbols_Table;
struct Symbol *curFunctionSym = NULL;

int whileTop=-1,vtop=-1,arg_top=-1;
struct Symbol *var_stack[253];
struct Ast_node* arg_stack[20];
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
%type <node> expression_statement selection_statement iteration_statement in_statement
%type <node> program external_declaration start

%right '='
%left '+' '-'
%left '*' '/'
%nonassoc UNARY_MINUS
%nonassoc PRIORITY_LOWER_THAN_ELSE
%nonassoc PRIORITY_LOWER_THAN_DECL_LIST
%nonassoc '{'
%nonassoc '('
%nonassoc ELSE
%start start
%%

start : program { ast_root = makeNode (astStart, NULL, $1, NULL, NULL, NULL);
        printf ("\n---> Compilation avec succes.\n");
      }
      ;
program
      : external_declaration {
          $$ = $1;
      }
      | program external_declaration {
        $$ = makeNode (astProgram, NULL, $1, $2, NULL, NULL);
      }
      ;
            
primary_expression
     : IDENTIFIER {
        struct Symbol *sym = NULL;
        sym = find_variable($1);
        if(sym == NULL){
                sprintf(message,"Usage d'un identificateur nedéclaré. '%s'",$1);
                yyerror(message);
        }
        $$ = makeNode (astId, sym, NULL, NULL, NULL, NULL);
        $$->expression_type = sym->type;
    }
    | CONSTANT {
        struct Symbol *sym;
        char temp[15];
        sprintf(temp,"%d", $1);
        sym = makeSymbol (temp, isINT, $1, 4, 'c', 0);
        $$ = makeNode (astConst, sym, NULL, NULL, NULL, NULL);
        $$->expression_type = isINT;
    }
    | '(' expression ')' {
        $$ = $2;
        if($2->node_type == astUnExpr)
        $$->node_type = ast(Expr);
    }
    ;
    
postfix_expression
    : primary_expression { // $1 = astId/ astConst/ ast(Expr)
        $$ = $1;
    }
    
    | postfix_expression '(' ')' { // f() / *f() / &f() / (*f)() / (&f)() / astPointerTo / f()() /3()
        // &f() - impossible in STRUCIT
        // verif called func has 0 args & the same type
        if ($1->node_type == astConst)
        yyerror("Objet appelé de type 'int' n'est pas une fonction ou pointeur sur function");
        if ($1->node_type == astFuncCall) // = f(args)(args)
        yyerror("Objet appelé de type 'return type' n'est pas une fonction ou pointeur sur function");
        if ($1->node_type == astPointerTo) // = p->id()
        yyerror("Appel de fonction non autorisé.");
        if($1->node_type == ast(Expr)) // (expr)(...)
        {
            if($1->child_node[0]->node_type == astStar || $1->child_node[0]->node_type == astAdress ){ // (*f)
                $$ = makeNode(astFuncCall, $1->symbol_node, NULL, NULL, NULL, NULL);
                $$->expression_type = $1->symbol_node->function_return_type;
            }
            else{
                yyerror("Appel de fonction non autorisé en STRUCIT.");
            }
        }
        
        if($1->node_type == astUnExpr) // *f() / &f()
        {
            if($1->child_node[0]->node_type ==astAdress){ // &()
                sprintf(message, "Pointeur sur le type retour de la fonction '%s' non-autorisé en strucit.",$1->symbol_node->name);
                yyerror(message);
            }
            else{ // *f()
                if($1->child_node[1]->symbol_node->function_return_type == POINTER_TO_INT){
                    $$ = makeNode(astFuncCall, $1->symbol_node, NULL, NULL, NULL, NULL);
                    $$->expression_type = isINT;
                }
                else{
                    sprintf(message, "Dereferencier le type retour de la fonction '%s' non-autorisé en strucit.",$1->symbol_node->name);
                    yyerror(message);
                    /* error: cannot take the address of an rvalue of type 'int' .... q = *&*&*&ee();*/
                }
            }
       }

        struct Symbol *sym;
        sym = find_variable ($1->symbol_node->name);
        if(sym == NULL || (sym !=NULL && sym->type != FUNCTION &&sym->type != POINTER_TO_FUNC )){
            sprintf(message,"Declaration implicite de fonction '%s' est invalide. \n",$1->symbol_node->name);
            yyerror(message);
        }
        
        if($1->node_type == astId){
            $$ = makeNode(astFuncCall, $1->symbol_node, NULL, NULL, NULL, NULL);
            $$->expression_type = sym->function_return_type;
        }
        
        if($1->symbol_node->nb_elements != sym->nb_elements){
            sprintf(message,"Fonction '%s' doit avoir %d parametres.", $1->symbol_node->name,sym->nb_elements);
            yyerror(message);
        }
       
    }
    
    | postfix_expression '(' argument_expression_list ')' { // verif nb_args = nb_params. args?
        // f() / *f() / &f() / (*f)() / (&f)() / astPointerTo / f()() /3()
            // &f() - impossible in STRUCIT
           
           if ($1->node_type == astConst)
           yyerror("Objet appelé de type 'int' n'est pas une fonction ou pointeur sur function");
           if ($1->node_type == astFuncCall) // = f(args)(args)
           yyerror("Objet appelé de type 'return type' n'est pas une fonction ou pointeur sur function");
           if ($1->node_type == astPointerTo) // = p->id()
            yyerror("Appel de fonction non autorisé.");
           
           struct Symbol *sym;
           struct Ast_node *noeud;
           sym = find_variable ($1->symbol_node->name);
           if(sym == NULL || (sym !=NULL && sym->type != FUNCTION &&sym->type != POINTER_TO_FUNC )){
               sprintf(message,"Declaration implicite de fonction '%s' est invalide. \n",$1->symbol_node->name);
               yyerror(message);
           }
           
           if($1->symbol_node->nb_elements != sym->nb_elements){
               sprintf(message,"Fonction '%s' doit avoir %d parametres.", $1->symbol_node->name,sym->nb_elements);
               yyerror(message);
           }
           
           
           for(int i =0;i<sym->nb_elements;i++){
               noeud = popArg();
               if(sym->param_list[i]->type != noeud->expression_type && (noeud->expression_type <5 && sym->param_list[i]->type ==POINTER_TO_VOID)){
                   sprintf(message,"Fonction '%s' n'a pas des parametres des types correspondant.",$1->symbol_node->name);
                   yyerror(message);
               }
           }

            if($1->node_type == ast(Expr)) // (expr)(...)
            {
                if($1->child_node[0]->node_type == astStar || $1->child_node[0]->node_type == astAdress ){ // (*f)
                    $$ = makeNode(astFuncCall, $1->symbol_node, $3, NULL, NULL, NULL);
                    $$->expression_type = $1->symbol_node->function_return_type;
                }
                else{
                    yyerror("Appel de fonction non autorisé en STRUCIT.");
                }
            }
            if($1->node_type == astUnExpr) // *f() / &f()
            {
                if($1->child_node[0]->node_type ==astAdress){ // &()
                    sprintf(message, "Pointeur sur le type retour de la fonction '%s' non-autorisé en strucit.",$1->symbol_node->name);
                    yyerror(message);
                }
                else{ // *f()
                    if($1->child_node[1]->symbol_node->function_return_type == POINTER_TO_INT){
                        $$ = makeNode(astFuncCall, $1->symbol_node, $3, NULL, NULL, NULL);
                        $$->expression_type = isINT;
                    }
                    else{
                        sprintf(message, "Dereferencier le type retour de la fonction '%s' non-autorisé en strucit.",$1->symbol_node->name);
                        yyerror(message);
                        /* error: cannot take the address of an rvalue of type 'int' .... q = *&*&*&ee();*/
                    }
                }
           }
            if($1->node_type == astId){
                $$ = makeNode(astFuncCall, $1->symbol_node, $3, NULL, NULL, NULL);
                $$->expression_type = sym->function_return_type;
            }
        
    }
    | postfix_expression PTR_OP IDENTIFIER {
        int found = 0;
        enum Type field_type;
        struct Symbol *from_struct;
        struct Symbol *temp_ptr;
        if($1->node_type == astFuncCall){ //struct liste * f().... f()->id
            if(find_variable($1->symbol_node->name)){
                temp_ptr = find_variable($1->symbol_node->name);
                found =1;
                if(temp_ptr->function_return_type != POINTER_TO_STRUCT){
                    sprintf(message, "Variable '%s' n'a pas un type de retour 'struct *'.", $1->symbol_node->name);
                    yyerror(message);
                }
            }
            else{
                sprintf(message, "Variable '%s' nédéclarée dans la portée.", $1->symbol_node->name);
                yyerror(message);
            }
            
            if (found == 0){
                sprintf(message,"Pas de membre '%s' dans 'struct %s' \n", $3, from_struct->name);
                yyerror(message);
            }
        }
        
        
        if($1->node_type == astConst || $1->node_type == ast(Expr) || $1->node_type == astSize  || $1->node_type == astUnExpr){ // 12->id / (2+3+p)->id / &p->id / *p->id
            sprintf(message, "Operation non-autorisée sur le champs '%s'. ", $3);
            yyerror(message);
        }
        
        
        if($1->node_type == astId){
            if(find_variable($1->symbol_node->name)){
                temp_ptr = find_variable($1->symbol_node->name);
                if(temp_ptr->type != POINTER_TO_STRUCT){
                    sprintf(message, "Variable '%s' n'est pas un pointeur sur structure.", $1->symbol_node->name);
                    yyerror(message);
                }

            from_struct = temp_ptr->pointed_struct;
            for(int i=0;i<from_struct->nb_elements;i++){
                    if(strcmp(from_struct->fields_list[i]->name,$3)==0){
                        found = 1;
                        field_type = from_struct->fields_list[i]->type;
                        break;
                    }
                       
                }

            }
            else{
                sprintf(message, "Variable '%s' nédéclarée dans la portée.", $1->symbol_node->name);
                yyerror(message);
            }
            
        }
        from_struct = temp_ptr->pointed_struct;
        for(int i=0;i<from_struct->nb_elements;i++){
                if(strcmp(from_struct->fields_list[i]->name,$3)==0){
                    found = 1;
                    field_type = from_struct->fields_list[i]->type;
                    break;
                }
            }
        
        if (found == 0){
            sprintf(message,"Pas de membre '%s' dans 'struct %s' \n", $3, from_struct->name);
            yyerror(message);
        }
        
        struct Ast_node *field = malloc(sizeof(struct Ast_node));
        assert(field != NULL);
        field->node_type = astId;
        field->symbol_node = malloc(sizeof(struct Symbol));
        assert(field->symbol_node != NULL);
        strcpy(field->symbol_node->name, $3);
        field->symbol_node->type = field_type;
        $$ = makeNode(astPointerTo, $1->symbol_node, field, NULL, NULL, NULL);
        $$->expression_type = field->symbol_node->type;
    }
    ;


argument_expression_list
    : expression {
        $$ = $1;
        nb_args = 1;
        pushArg($$);
    }
    | argument_expression_list ',' expression{
        $$ = makeNode(astArgs, NULL, $1, $3, NULL, NULL);
        nb_args++;
        pushArg($3);
    }
    ;

unary_expression
    : SIZEOF '(' IDENTIFIER ')' {
    struct Symbol *symm;
    symm = find_variable($3);
    if (symm == NULL){
        sprintf(message, "Variable-argument '%s' n'est pas déclarée dans la portée.", $3);
        yyerror(message);
    }
    
    if(symm->type!=POINTER_TO_STRUCT){
        sprintf(message, "Variable-argument de sizeof, '%s' n'est pas un pointeur sur structure.", $3);
        yyerror(message);
    }
    $$ = makeNode (astSize, symm, NULL, NULL, NULL, NULL);
    $$ ->expression_type = isINT;
    }
    | postfix_expression {
        $$ = $1;
    }
    | unary_operator unary_expression{
        $$ = analyse_unary($1, $2);
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
        if ($1->expression_type !=isINT || $3->expression_type !=isINT)
        yyerror("Operands invalids pour une expression binaire.");
        $$ = makeNode (astMul, NULL, $1, $3, NULL, NULL);
        $$->expression_type = isINT;
    }
    | multiplicative_expression '/' unary_expression {
        if ($1->expression_type !=isINT || $3->expression_type !=isINT)
        yyerror("Operands invalids pour une expression binaire.");
        $$ = makeNode (astDiv, NULL, $1, $3, NULL, NULL);
        $$->expression_type = isINT;
    }
    ;

additive_expression
    : '-' multiplicative_expression %prec UNARY_MINUS {
        $$ = makeNode (astUnaryM, NULL, $2, NULL, NULL, NULL);
        if($2->expression_type != isINT)
        yyerror("Argument invalide pour une expression unaire");
        $$->expression_type = isINT;
    
    }
    | multiplicative_expression{
        $$ = $1;
    }
    | additive_expression '+' multiplicative_expression{
        $$ = makeNode (astAdd, NULL, $1, $3, NULL, NULL);
        if($1->expression_type == isINT && $3->expression_type == isINT) // int + int
            $$->expression_type = isINT;
        if($1->expression_type == isINT && $3->expression_type >4) // pointer+int
            $$->expression_type = $3->expression_type;
        if($3->expression_type == isINT && $1->expression_type >4 ) // pointer+int
            $$->expression_type = $1->expression_type;
        if($1->expression_type >4 && $3->expression_type >4)
            yyerror("Operandes invalides pour une expression binaire. (pointer+pointer).");
    }
    | additive_expression '-' multiplicative_expression{
        $$ = makeNode (astSub, NULL, $1, $3, NULL, NULL);
        if($1->expression_type == isINT && $3->expression_type == isINT) // int - int
            $$->expression_type = isINT;
        if($1->expression_type == isINT && $3->expression_type >4) // pointer-int
            $$->expression_type = $3->expression_type;
        if($3->expression_type == isINT && $1->expression_type >4 ) // pointer-int
            $$->expression_type = $1->expression_type;
        if($1->expression_type >4 && $3->expression_type >4)
            yyerror("Operandes invalides pour une expression binaire. (pointer-pointer).");
    }
    ;

relational_expression
    : additive_expression {
        $$ = $1;
    }
    | relational_expression '<' additive_expression{
         if(($1->expression_type>4 && ($3->node_type == astConst && $3->symbol_node->value !=0)) || ($3->expression_type>4 && ($1->node_type == astConst && $1->symbol_node->value!=0)))
                yyerror("Comparaison entre pointeur et une constante non nulle.");
        if($1->expression_type != $3->expression_type)
                yyerror("Comparaison entre deux operandes avec des type distincts.");
        $$ = makeNode (astLt, NULL, $1, $3, NULL, NULL);
        $$->expression_type = isINT;
    }
    | relational_expression '>' additive_expression{
        if(($1->expression_type>4 && ($3->node_type == astConst && $3->symbol_node->value !=0)) || ($3->expression_type>4 && ($1->node_type == astConst && $1->symbol_node->value!=0)))
                yyerror("Comparaison entre pointeur et une constante non nulle.");
       if($1->expression_type != $3->expression_type)
                yyerror("Comparaison entre deux operandes avec des type distincts.");
        $$ = makeNode (astGt, NULL, $1, $3, NULL, NULL);
        $$->expression_type = isINT;
    }
    | relational_expression LE_OP additive_expression{
        if(($1->expression_type>4 && ($3->node_type == astConst && $3->symbol_node->value !=0)) || ($3->expression_type>4 && ($1->node_type == astConst && $1->symbol_node->value!=0)))
                yyerror("Comparaison entre pointeur et une constante non nulle.");
       if($1->expression_type != $3->expression_type)
                yyerror("Comparaison entre deux operandes avec des type distincts.");
        $$ = makeNode (astLte, NULL, $1, $3, NULL, NULL);
        $$->expression_type = isINT;
        
    }
    | relational_expression GE_OP additive_expression{
        if(($1->expression_type>4 && ($3->node_type == astConst && $3->symbol_node->value !=0)) || ($3->expression_type>4 && ($1->node_type == astConst && $1->symbol_node->value!=0)))
                yyerror("Comparaison entre pointeur et une constante non nulle.");
       if($1->expression_type != $3->expression_type)
                yyerror("Comparaison entre deux operandes avec des type distincts.");
        $$ = makeNode (astGte, NULL, $1, $3, NULL, NULL);
        $$->expression_type = isINT;
    }
    ;

equality_expression
    :    relational_expression {
        $$ = $1;
    }
    | equality_expression EQ_OP relational_expression {
        if($1->expression_type == isINT && $3->expression_type != isINT ){
            if($1->node_type !=astConst)
            yyerror("Comparaison entre pointeur et une constante non-nulle.");
        }
        if($3->expression_type == isINT && $1->expression_type != isINT ){
            if($3->node_type !=astConst)
            yyerror("Comparaison entre pointeur et une constante non-nulle.");
        }
        if($1->expression_type>4 && $3->expression_type>4 && ($1->expression_type != $3->expression_type>4))
        yyerror("Comparaison entre pointeurs avec des types distincts.");
        
        $$ = makeNode (astEq, NULL, $1, $3, NULL, NULL);
        $$->expression_type = isINT;
    }
    | equality_expression NE_OP relational_expression {
        if($1->expression_type == isINT && $3->expression_type != isINT ){
            if($1->node_type !=astConst)
            yyerror("Comparaison entre pointeur et une constante non-nulle.");
        }
        if($3->expression_type == isINT && $1->expression_type != isINT ){
            if($3->node_type !=astConst)
            yyerror("Comparaison entre pointeur et une constante non-nulle.");
        }
        if($1->expression_type>4 && $3->expression_type>4 && ($1->expression_type != $3->expression_type>4))
        yyerror("Comparaison entre pointeurs avec des types distincts.");
        
        $$ = makeNode (astNeq, NULL, $1, $3, NULL, NULL);
        $$->expression_type = isINT;
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
    | unary_expression '=' expression {
        if(($1->expression_type<4 && $3->expression_type>=4) || ($3->expression_type<4 && $1->expression_type>=4))
            yyerror("Operandes avec des types incompatibles.");
        if($1->expression_type != $3->expression_type){
            if($1->expression_type<=4 && $3->expression_type<=4)
                yyerror("Operandes avec des types incompatibles.");
            if(($1->expression_type == POINTER_TO_VOID && $3->expression_type<4) || ($3->expression_type == POINTER_TO_VOID && $1->expression_type<4 ))
                        yyerror("Operandes avec des types incompatibles.");
            if(($1->expression_type >=4 && $3->expression_type != POINTER_TO_VOID) && ($3->expression_type >=4 && $1->expression_type != POINTER_TO_VOID))
                yyerror("Operandes avec des types incompatibles.");
        }
       
        struct Symbol *sym;
        $$ = makeNode (astAssignStmt, NULL, $1, $3, NULL, NULL); // !
        if($1->node_type == astConst || $1->node_type == astFuncCall || $1->node_type == astSize)
                yyerror("Operands invalids pour une expression binaire. (Expression is not assignable)."); // f() = / 3 = / sizeof(p) =
                
        if($1->node_type == astId){ // id/func =
            sym = find_variable ($1->symbol_node->name);
            if(sym == NULL){
                sprintf(message, "Variable '%s' utilisé non-déclarée.", $1->symbol_node->name);
                yyerror(message);
            }
            if(sym->type == FUNCTION) {// func =
                sprintf(message, "Fonction '%s' n'est pas assignable.", $1->symbol_node->name);
                yyerror(message);
            }
            $$->expression_type = $1->symbol_node->type;
        }
        
        if($1->node_type == ast(Expr)){ // (expr)
            if ($1->child_node[0]->node_type != astStar)
                yyerror("Expression n'est pas asignable."); // (&b)
            //(*p) ok
            if($1->child_node[1]->symbol_node->type !=POINTER_TO_INT)
                yyerror("Expression n'est pas acceptee en STRUCIT. Pointeur sur entier attendu.");
            if($1->child_node[1]->symbol_node->type == POINTER_TO_INT && $1->child_node[0]->node_type == astStar)
                    $$->expression_type = isINT;
        }
        
        
        
        if($1->node_type == astPointerTo) // p->field
            $$->expression_type = $1->child_node[0]->symbol_node->type;

    }
    ;


var_declaration
    : declaration_specifiers declarator {
        if($1->child_node[0]->node_type == astExt){
              $2->symbol_node->is_extern = 1;
            complete_type($2->symbol_node,$1->child_node[1]);
        }
        else // var not EXTERN
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
        $$ = makeNode (astVoid, NULL, NULL, NULL, NULL, NULL);
    }
    
    | INT {
        $$ = makeNode (astInt, NULL, NULL, NULL, NULL, NULL);
    }
    | struct_specifier {
        $$ = $1;
    }
    ;
            

struct_specifier
    : STRUCT IDENTIFIER '{' struct_declaration_list '}' {
        struct Symbol *sym=malloc(sizeof(struct Symbol));
        assert(sym!=NULL);
        sym = makeSymbol($2, isSTRUCT, 0, 0, 's', 0);
        sym->fields_list = malloc(nb_fields *sizeof(struct Symbol));
        assert(sym->fields_list !=NULL );

        for(int i=0;i<nb_fields;i++){
            sym->fields_list[i] = popV();
        }
        
        sym->nb_elements = nb_fields;
        sym->from_function = curFunctionSym;
        $$ = makeNode(astStruct, sym, NULL, NULL, NULL, NULL);
        add_variable_to_table(sym);
        nb_fields=0;
    }
    | STRUCT '{' struct_declaration_list '}' {
        struct Symbol *sym=malloc(sizeof(struct Symbol));
        assert(sym!=NULL);
        
        char temp[10];
        sprintf(temp, "struct%d", struct_id++);
      
        sym = makeSymbol(temp, isSTRUCT, 0, 0, 's', 0);
        sym->fields_list = malloc(nb_fields *sizeof(struct Symbol));
        assert(sym->fields_list !=NULL );
        for(int i=0;i<nb_fields;i++){
            sym->fields_list[i] = popV();
        }
        sym->nb_elements = nb_fields;
        sym->from_function = curFunctionSym;
    
        $$ = makeNode(astStruct, sym, NULL, NULL, NULL, NULL);
        add_variable_to_table(sym);
        nb_fields=0;
    }
    | STRUCT IDENTIFIER %prec PRIORITY_LOWER_THAN_DECL_LIST {
        struct Symbol *sym=malloc(sizeof(struct Symbol));
        assert(sym!=NULL);
        sym = makeSymbol($2, isSTRUCT, 0, 0, 's', 0);
        
        struct Symbol *found;
        if((found = find_variable($2)) && found->tag == 's'){
            sym->fields_list = found->fields_list;
            sym->nb_elements = found->nb_elements;
        }
        $$ = makeNode (astStruct, sym, NULL, NULL, NULL, NULL);
    }
    ;
    
/* Types des variables et des champs des structures : int et pointeur sur structure, sur fonction ou sur int. */
struct_declaration_list
    : var_declaration ';' {
        $1->symbol_node->from_struct = 1;
        if($1->symbol_node->type != isINT && $1->symbol_node->type != POINTER_TO_STRUCT && $1->symbol_node->type != POINTER_TO_INT)
            yyerror("Variable avec un type illegale déclarée dans une structure.");
            $$ = $1;
     
            pushV($1->symbol_node);
        nb_fields=1;
    }
    
    | function_declaration ';' {
        $1->symbol_node->from_struct = 1;
        pushV($1->symbol_node);
        nb_fields=1;
    }
    | struct_declaration_list var_declaration ';' {
        $2->symbol_node->from_struct = 1;
        if($2->symbol_node->type != isINT && $2->symbol_node->type != POINTER_TO_STRUCT && $2->symbol_node->type != POINTER_TO_INT)
            yyerror("Variable avec un type illegale déclarée dans une structure.");
       
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
        if($1->symbol_node->type != isINT && $1->symbol_node->type != POINTER_TO_STRUCT && $1->symbol_node->type != POINTER_TO_INT && $1->symbol_node->type != POINTER_TO_VOID ){
            sprintf(message,  "Parametre '%s' de fonction a un type illegale.", $1->symbol_node->name);
            yyerror(message);
        }
        $$ = $1;
        pushV($$->symbol_node);
}
    | function_declaration {
        if($1->symbol_node->type !=POINTER_TO_FUNC){
            sprintf(message, "Parametre '%s' avec un type illegal. Pointeur sur fonction attendu. ", $1->symbol_node->name);
            yyerror(message);
        }
        $$ = $1;
        pushV($$->symbol_node);
}
    ;
            
statement
    : expression_statement{
        if($1->node_type!=astAssignStmt && $1->node_type!=astFuncCall)
        yyerror("Expression non-autorisee.");
        $$ = $1;
    }
    | selection_statement{
        $$ = $1;
    }
    | iteration_statement{
        $$ = $1;
    }
    | RETURN ';'{
        $$ = makeNode(astReturn, NULL, NULL, NULL, NULL, NULL);
    }
    | RETURN expression ';'{
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
            sprintf(message, "'%s' est un pointeur sur fonction. compound_statement innattendu.", curFunctionSym->name);
            yyerror(message);
        }
        if($1->symbol_node->type != isINT && $1->symbol_node->type != POINTER_TO_STRUCT && $1->symbol_node->type != POINTER_TO_INT){
            sprintf(message,  "Variable '%s' a un type illegale.", $1->symbol_node->name);
            yyerror(message);
        }
        $1->symbol_node->from_function = curFunctionSym;
        add_variable_to_table($1->symbol_node);
        $$ = $1;
    }
    | function_declaration ';' {
        if (curFunctionSym->type == POINTER_TO_FUNC){
            sprintf(message, "'%s' est un pointeur sur fonction. compound_statement innattendu.", curFunctionSym->name);
            yyerror(message);
        }
        if ($1->symbol_node->type !=POINTER_TO_FUNC)
        yyerror("Declaration d'un pointeur sur fonction attendu.");
        $1->symbol_node->from_function = curFunctionSym;
        add_variable_to_table($1->symbol_node);
        $$ = $1;
    }
    | declaration_list var_declaration ';' {
        if($2->symbol_node->type != isINT && $2->symbol_node->type != POINTER_TO_STRUCT && $2->symbol_node->type != POINTER_TO_INT){
            sprintf(message,  "Variable '%s' a un type illegale.", $2->symbol_node->name);
            yyerror(message);
        }
        
        $2->symbol_node->from_function = curFunctionSym;
        add_variable_to_table($2->symbol_node);
        $$ = makeNode (astDeclList, NULL, $1, $2, NULL, NULL);
    }
    |declaration_list function_declaration ';' {
        if ($2->symbol_node->type !=POINTER_TO_FUNC)
        yyerror("Declaration d'un pointeur sur fonction attendu.");
        $2->symbol_node->from_function = curFunctionSym;
        add_variable_to_table($2->symbol_node);
        $$ = makeNode (astDeclList, NULL, $1, $2, NULL, NULL);
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
    : IF '(' expression ')' in_statement %prec PRIORITY_LOWER_THAN_ELSE {
        struct Ast_node *if_node = malloc(sizeof(struct Ast_node));
        assert(if_node != NULL);
        
        $$ = makeNode (astIfStmt, NULL, $3, $5, NULL, NULL);
    }
    | IF '(' expression ')' in_statement ELSE in_statement {
        struct Ast_node *if_node, *else_node;
        if_node = malloc(sizeof(struct Ast_node));
        else_node = malloc(sizeof(struct Ast_node));
        assert(if_node != NULL);
        assert(else_node != NULL);
        $$ = makeNode (astElifStmt, NULL, $3, $5, $7, NULL);
    }
    ;
    
in_statement
    : '{' statement_list '}' {
        $$ = $2;
}
    | statement {
        $$ = $1;
    }
    ;

iteration_statement
    : WHILE '(' expression ')' in_statement {
        $$ = makeNode (astWhile, NULL, $3, $5, NULL, NULL);
    }
    | FOR '(' expression_statement expression_statement expression ')' in_statement {
        $$ = makeNode (astFor, NULL, $3, $4, $5, $7);
    }
    ;
    
external_declaration
    : var_declaration ';' {
        if($1->symbol_node->type != isINT && $1->symbol_node->type != POINTER_TO_STRUCT && $1->symbol_node->type != POINTER_TO_INT){
            sprintf(message,  "Variable '%s' a un type illegale.", $1->symbol_node->name);
            yyerror(message);
        }
        $1->symbol_node->from_function = NULL;
        $1->symbol_node->tag = 'v';
        curFunctionSym = NULL;
        add_variable_to_table($1->symbol_node);
        $$ = $1;
    }
    | struct_specifier ';' {
        $1->symbol_node->from_function = NULL;
        curFunctionSym = NULL;
       $$ = $1;
    }
    
    | function_declaration compound_statement { // function definition
        $1->symbol_node->tag = 'f';
        $$ = makeNode (astFunctionDef, NULL, $1, $2, NULL, NULL);
        curFunctionSym = NULL;
        add_variable_to_table($1->symbol_node);
    }
    | function_declaration ';' {
        $1->symbol_node->from_function = NULL;
        $1->symbol_node->tag = 'f';
        curFunctionSym = NULL;
        add_variable_to_table($1->symbol_node);
       $$ = $1;
    }
    ;
        
declarator // complete_type in var_decl derivation
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
        sym = makeSymbol($4, POINTER_TO_FUNC, 0, 8, 'v', 0);
        sym->returns_pointer=1;
        $$ = makeNode(astDeclarator, sym, NULL, NULL, NULL, NULL);

    }
    ;
        
        
/* les types de retour ne peuvent être que type de base ou pointeur sur structure ou constantes */
function_declaration
    : var_declaration '(' parameter_list ')' { // now IDENT in var_decl is FUNCTION/POINTER_TO_FUNC
        if($1->symbol_node->type != POINTER_TO_FUNC){
            $1->symbol_node->function_return_type = $1->symbol_node->type;
            $1->symbol_node->type = FUNCTION;
        }
        $1->symbol_node->nb_elements = nb_params;
        $1->symbol_node->param_list = malloc (nb_params * sizeof(struct Symbol));
        assert ($1->symbol_node->param_list != NULL);
        
        for(int i=0;i<nb_params;i++){
            $1->symbol_node->param_list[i] = popV();
        }
        
        if(curFunctionSym == NULL && $1->symbol_node->type !=POINTER_TO_FUNC)
                curFunctionSym = $1->symbol_node;
        $$ = makeNode(astFunctionDecl, $1->symbol_node, $1, $3, NULL, NULL);
}
    | var_declaration '(' ')' {
        if($1->symbol_node->type != POINTER_TO_FUNC){
            $1->symbol_node->function_return_type = $1->symbol_node->type;
            $1->symbol_node->type = FUNCTION;
        }
        
        $1->symbol_node->param_list = NULL; // no params
        $1->symbol_node->nb_elements = 0;
        
        $$ = makeNode(astFunctionDecl, $1->symbol_node, $1, NULL, NULL, NULL);
        if(curFunctionSym == NULL && $1->symbol_node->type != POINTER_TO_FUNC)
        curFunctionSym = $1->symbol_node; // only for func_def
    }
    ;
%%
    
int main(int argc, char *argv[])
{
        
        if (argc != 3)
        {
            printf("\nUsage: <exefile> <inputfile> <output>\n\n");
            exit(0);
        }
        
        Init_Stack();
        yyin = fopen(argv[1], "r");
        yyparse();
       //traverse(ast_root, -3); // output AST
        strucit_backend = fopen(argv[2], "w");
        
        if(strucit_backend == NULL){
            printf("\nFichier '%s' ne peut pas etre ouvert\n", argv[1]);
            exit(0);
        }
        
        generateCode(ast_root, 0);
        /*
        to_add=1; // to add temporary vars
        //fclose(fopen(argv[2], "w+")); NOT GOOD!
        fclose(strucit_backend);

        strucit_backend = fopen(argv[2], "w");
        if(strucit_backend == NULL){
            printf("\nFichier '%s' ne peut pas etre ouvert\n", argv[1]);
            exit(0);
        }
        generateCode(ast_root, 0);*/
        fclose(strucit_backend);

        return 0;
}

    


void yyerror(char *s)
{
	printf("\033[25m\n%d:%d : error: ",line, prevCol);
	printf("\033[25m\"%s\"\n",s);
    Print_Table();
	exit (0);
}
    
    

//for Hash Tables
int genKey(char *s)
{
    char *p;
    int athr=0;
    for(p=s; *p; p++)
    athr=athr+(*p);
    return (athr % SYM_TABLE_SIZE);
}
    
    
void init_tables(){
        for(int i=0;i<SYM_TABLE_SIZE;i++){
            Symbols_Table.symbols[i] = NULL;
        }
        Symbols_Table.nbSymbols = 0;
}


void Print_Table(){
        printf("\n############ Symbols table ############\n");
        printf("Var_Name\tFrom_func\tDatatype\n");
        for (int i=0;i<SYM_TABLE_SIZE;i++){
            struct Symbol *sym;
            sym = Symbols_Table.symbols[i];
            while(sym!=NULL){
                
                if(sym->from_function == NULL)
                printf("[%d]:%s\t\tGlobal var\t%d\n", i, sym->name, sym->type);
                else
                printf("[%d]:%s\t\t%s\t%d\n", i,sym->name,sym->from_function->name, sym->type);
                
                sym = sym->next;
            }
        }
        printf("\n###########################################\n");
}
    
    
struct Symbol *makeSymbol(char *name, enum Type type, int value, int size, char tag, int nb_elements){
    
    struct Symbol *temp = (struct Symbol*)malloc(sizeof(struct Symbol));
    assert(temp!=NULL);
    strcpy(temp->name,name);
    temp->type = type;
    temp->value = value;
    temp->tag = tag;
    temp->size = size;
    temp->nb_elements = nb_elements;
    temp->param_list = NULL;
    temp->fields_list = NULL;
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
        exists = find_to_add(symbp->name);
        if(!exists || (exists && symbp->from_function!=NULL && symbp->from_function != curFunctionSym) || (exists && curFunctionSym!=NULL && curFunctionSym != symbp->from_function) || (exists->from_function == NULL && symbp->from_function!=NULL) || (exists->from_function != NULL && symbp->from_function==NULL))
            add_variable(symbp);
        else
        {
            sprintf(message, "Rédéfinition de '%s'. ", symbp->name);
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
          prev = ptr;
          ptr = ptr->next;
      }
      
      if(prev == NULL){
          Symbols_Table.symbols[i] = malloc(sizeof (struct Symbol));
          assert(Symbols_Table.symbols[i] !=NULL);
          
          Symbols_Table.symbols[i]->next = NULL;
          symbp->next = NULL;
          Symbols_Table.symbols[i] = symbp;
      }
      else{
          prev->next = malloc(sizeof (struct Symbol));
          symbp->next = NULL;
          prev->next = symbp;
      }

      Symbols_Table.nbSymbols++;
}
    
// for declarations.
struct Symbol *find_to_add(char *s)
    {
          int i;
          struct Symbol *ptr;
          struct Hash_Table table = Symbols_Table;

          i = genKey(s);
          ptr = table.symbols[i];
          while(ptr){
            if(strcmp(ptr->name,s) ==0){
                if(ptr->from_function== NULL){ /// found a global var with the same name
                    if (curFunctionSym == NULL) ///  new var = global
                    {
                        return ptr; /// don't add it
                    }
                    else /// new var is in function and found var is global
                        {
                          return NULL;
                        }
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
        
        // search in param_list
        if(curFunctionSym!=NULL && curFunctionSym->param_list!=NULL){
            for(int i=0;i<curFunctionSym->nb_elements;i++){
                if(strcmp(curFunctionSym->param_list[i]->name, s)==0){
                    return curFunctionSym->param_list[i];
                }
                  
            }
            return NULL;
        }
        
          return ptr;
    }
        
        
// verif if variable is accessible
struct Symbol *find_variable(char *s)
{
      int i;
      struct Symbol *ptr;
      struct Hash_Table table = Symbols_Table;

      i = genKey(s);
      ptr = table.symbols[i];
      while(ptr){
          if(strcmp(ptr->name, s)==0){
              if(curFunctionSym !=NULL && ptr->from_function!=NULL && curFunctionSym->name == ptr->from_function->name)
                    return ptr; /// found another var with same name in same func
          }
          ptr=ptr->next;
      }
      ptr = table.symbols[i];
      while(ptr){
        if(strcmp(ptr->name,s) ==0){
            if(ptr->from_function== NULL){ /// found a global var with the same name
                if (curFunctionSym == NULL) ///  new var = global
                {
                    return ptr; /// don't add it
                }
                else /// new var is in function and found var is global. found.
                    {
                      return ptr;
                    }
            }
            else{ /// found a var with the same name in a function
                if (curFunctionSym == NULL)/// new var = global
                    return ptr; /// can add it
                if(curFunctionSym->name == ptr->from_function->name)
                    return ptr; /// already have a var with same name in same function
            }
        }
       
        ptr=ptr->next;
    }
    
    // search in param_list
    if(curFunctionSym!=NULL && curFunctionSym->param_list!=NULL){
        for(int i=0;i<curFunctionSym->nb_elements;i++){
            if(strcmp(curFunctionSym->param_list[i]->name, s)==0){
                return curFunctionSym->param_list[i];
            }
              
        }
        return NULL;
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

        case POINTER:
                if(temp_type2 == isINT)
                    sym->type = POINTER_TO_INT;
                if(temp_type2 == isVOID)
                    sym->type = POINTER_TO_VOID;
            
                if(temp_type2 == isSTRUCT){
                    sym->type = POINTER_TO_STRUCT;
                    sym->pointed_struct = child_node->symbol_node;
                    }
                break;

        case POINTER_TO_FUNC: // sym->type = POINTER_TO_FUNCTION
            if(sym->returns_pointer == 1) { // int/void/struct * (*id)...
                if(temp_type2 == isINT)
                sym->function_return_type = POINTER_TO_INT;
                if(temp_type2 == isVOID)
                sym->function_return_type = POINTER_TO_VOID;
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
                printf("%s\tNULL\t\t%d\t%d\n", var_stack[i]->name, var_stack[i]->type, vtop);
            }
        }
        printf("------------- END ------------\n");
}
   
void pushArg(struct Ast_node* node){
    arg_stack[++arg_top]=node;
}
        
struct  Ast_node* popArg() {
    return arg_stack[arg_top--];
}
        
void printAStack(){
            printf("\n------- Arguments STACK -------\n");
            printf("node type\t expression type \n");
            for (int i=arg_top; i>=0; i--){
                printf("%d\t %d\n", arg_stack[i]->node_type, arg_stack[i]->expression_type);
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
struct Ast_node* analyse_unary(struct Ast_node *child1, struct Ast_node *child2) {
   
    struct Ast_node *result;
        if(child1->node_type == astAdress){ // &
            if(child2->node_type == astUnExpr && child2->expression_type == POINTER)
                yyerror("Pointeur multiple n'est pas accepté en STRUCIT.");

            if(child2->node_type == astId){
                if(child2->expression_type == isINT){
                    result = makeNode(astUnExpr,child2->symbol_node, child1, child2, NULL, NULL);
                    result->expression_type = POINTER_TO_INT;
                    return result;
                }
                switch (child2->symbol_node->type){ // int id;  ...&id
                    case isINT:
                    result = makeNode(astUnExpr,child2->symbol_node, child1, child2, NULL, NULL);
                    result->expression_type = POINTER_TO_INT;
                    break;
                    case FUNCTION:
                    {
                        result = makeNode(astUnExpr,child2->symbol_node, child1, child2, NULL, NULL);
                        result->expression_type = POINTER_TO_FUNC;
                    }
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
                    default: printf("default in function analyse."); exit(0); break;
                     }
            }
             
             
             if(child2->node_type == astPointerTo && child2->child_node[0]->symbol_node->type!=isINT){
              yyerror("Prendre l'adresse d'une variable non-INT n'est pas autorise en strucit.");
             }
             
             if(child2->node_type == astPointerTo && child2->child_node[0]->symbol_node->type ==isINT){
                 result = makeNode(astUnExpr,child2->symbol_node, child1, child2, NULL, NULL);
                 result->expression_type = POINTER_TO_INT;
             }
            
             
        
              // CONSTANT / function return type
              if (child2->node_type == astConst)// &astConst
                    yyerror("Ne peut pas prendre l'adresse d'une valeur constante.");
              if (child2->node_type == astFuncCall){ // &func(...)
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
                    }
              }
              if(child2->node_type == astUnExpr){
                  if(child2->expression_type == isINT){
                      result = makeNode(astUnExpr,child2->symbol_node, child1, child2, NULL, NULL);
                      result->expression_type = POINTER_TO_INT;
                      return result;
                  }
                  else {
                      yyerror ("Pointeur multiple n'est pas accepté en STRUCIT.");
                  }
              }
        }
        else{ //astStar - derref
            if(child2->expression_type == isINT)
            yyerror("Indirection requires pointer operand ('int' invalid). ");
            if(child2->expression_type == FUNCTION){
                result = makeNode(astUnExpr,child2->symbol_node, child1, child2, NULL, NULL);
                result->expression_type = FUNCTION;
                return result;
            }
           
            if(child2->node_type == astPointerTo && child2->child_node[0]->symbol_node->type != POINTER_TO_INT)
            yyerror("Derreference d'un champ d'une structure non autorise en strucit.");
            

            if (child2->node_type == astPointerTo && child2->child_node[0]->symbol_node->type == POINTER_TO_INT){
                result = makeNode(astUnExpr,child2->symbol_node, child1, child2, NULL, NULL);
                result->expression_type = isINT;
                return result;
            }
            if(child2->node_type == astId){ // *id. *func.
                // already verified if ident exists, in primary_expr
                switch (child2->symbol_node->type){
                    case isINT: // int id;  ... *id
                    yyerror("Indirection requires pointer operand ('int' invalid). ");
                    break;
                    case FUNCTION: //int (*d)(); d =  *f; == d= f; f - func designator - OK !
                    // f = pointer to func = function =...=...
                    result = makeNode(astUnExpr, child2->symbol_node, child1, child2, NULL, NULL);
                    result->expression_type = FUNCTION; // verif left operand is pointer to func returning $2 - return type (func designator)
                    break;
                    case POINTER_TO_STRUCT:
                    yyerror("Déréférencier une variable de type (struct *) donne une variable struct qui n'est pas autorisée en STRUCIT.");
                    case POINTER_TO_INT:
                    result = makeNode(astUnExpr, child2->symbol_node, child1, child2, NULL, NULL);
                    result->expression_type = isINT;
                    break;
                    case POINTER_TO_FUNC:
                    result = makeNode(astUnExpr, child2->symbol_node, child1, child2, NULL, NULL);
                    result->expression_type = FUNCTION;
                    break;
                    default: break;
                }
            }
            else // *astConst | *func(...)
            {
                if(child2->node_type == astConst)
                yyerror("cannot take the address of an rvalue of type 'int'");
                if(child2->node_type == astFuncCall){ // * f()
                    if (child2->symbol_node->returns_pointer !=1 ) // derref (int f())/(void f())  ?!
                    yyerror("Cannot take the address of an rvalue of type 'int'");
                    else{
                        /* les types de retour ne peuvent être que type de base ou pointeur sur structure ou constantes ; */
                        if(child2->symbol_node->function_return_type == POINTER_TO_STRUCT)
                        yyerror("Variable de type (struct ) déréférencé de type de retour (struct *) n'est pas acceptée in STRUCIT.");
                        if(child2->symbol_node->function_return_type == POINTER_TO_INT){
                            result = makeNode(astUnExpr, child2->symbol_node, child1, child2, NULL, NULL);
                            result->symbol_node->type = isINT;
                        }
                    }
                }
            }
        }
            return result;
}
        

