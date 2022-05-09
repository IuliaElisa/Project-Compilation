//
//  definitions.h
//  
//
//  Created by Iulia Elisa on 07.03.2022.
//

#ifndef definitions_h
#define definitions_h

#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define NAME_LEN 100
#define SYM_TABLE_SIZE 101

/* ----  Definitions des constantes pour le << type >> des node d'arbre syntaxique ---- */
#define astReturnExpr 481
#define astUnaryM 482
#define astDeclList 483
#define astBlock 484
#define astConst 485
#define astReturn 486
#define astEmpty 487 // function with 0 params
#define astStruct 488
#define astSize 489
#define astUnExpr 490
#define astStar 491
#define astAdress 492
#define astRelExp 493
#define astPointerTo 494
#define astPostExpr 495
#define astDeclarator 496
#define astVarDecl 498
#define astEmptyProgram 499
#define astProgram 500
#define astFunctionDef 501
#define astFunctionDecl 502
#define astParamList 504
#define astStmtsList 505
#define astAssignStmt 506
#define astFor 507
#define astWhile 508
#define astSelStmt 510
#define astElifStmts 512
#define astElifStmt 555
#define astElseStmt 513
#define astValue 515
#define astFuncCall 518
#define astArgs 522
#define astIdList 524
#define astParam 525
#define astAssignment 526
#define astExpr 527
#define astInt 530
#define astVoid 534
#define astExt 550
#define astAdd 535
#define astSub 536
#define astMul 537
#define astDiv 538
#define astLte 539
#define astGte 540
#define astLt 541
#define astGt 542
#define astEq 543
#define astNeq 544
#define astAnd 545
#define astOr 546
#define astStructList 547
#define astStart 549
#define astExtDecl 550
#define astDeclSpecs 551
#define astId 552

enum Type{UNDEFINED, isINT, isVOID, isSTRUCT, FUNCTION, POINTER, POINTER_TO_INT, POINTER_TO_VOID, POINTER_TO_FUNC, POINTER_TO_STRUCT};


/* -----------------------  Definition struct Symbol ------------------------- */
struct Symbol {
  char tag;                             /* v-Variable, f-Function, c-Constant, s-Struct */
  char name[NAME_LEN];                  /* Variable Name tag = v/s */
  struct Symbol *pointed_struct;        /* for var/func_def/pointer_to_func */
    
  enum Type type;                       /* var */
  enum Type function_return_type;       /* func_decl, var=pointer_to_func*/
  int size;                             /* for struct . CHECK LATER ! */
  int nb_elements;                      /* struct/func_def/pointer_to_func */
    
  struct Symbol *from_function;         /* var/struct/pointer_to_func */
  struct Symbol **param_list;
  struct Symbol **fields_list;
  int returns_pointer;                  /* var/pointer_to_func */
  int is_extern;                        /* all declarations */
  int from_struct;
  int value; // for constant
  int is_param;                         /* var/pointer. if 1, var can't be redeclared in function.  */
    /* struct Hash_Table *symbols_table;     Pointer to the symbol table if it is a function */
  struct Symbol *next;                  /* Pointer to the next symbol in the symbol table */
};


/*-----------------------  Definition struct Hash Table ------------------------- */
struct Hash_Table {
  int nbSymbols;
  struct Symbol *symbols[SYM_TABLE_SIZE];
};


/*-----------------------  Definition struct AST-node ------------------------- */
struct Ast_node {
  int node_type; //make a node of type astTYPE
  struct Symbol *symbol_node; // the node can have a symbol from makeSymbol attached to it
  enum Type expression_type;
  struct Ast_node *child_node[4]; //has at most 4 children
};


/* ----------------------- Function Prototypes -------------------------*/

void init_tables();
void print_tables();

struct Ast_node* makeNode(int type, struct Symbol *sn, struct Ast_node* first, struct Ast_node* second, struct Ast_node* third, struct Ast_node* fourth);
struct Symbol* makeSymbol(char *name, enum Type type, int value, int size,char tag,int no_elements);
void add_variable_to_table(struct Symbol *symbp);
int genKey(char *s);
void add_variable(struct Symbol *symbol_pointer);
struct Symbol *find_variable(char *variable_name);
struct Symbol *find_function(char *method_name);
void complete_type (struct Symbol *sym, struct Ast_node *child_node);
void traverse(struct Ast_node* p, int n);
void generateCode(struct Ast_node *p, int level);
void printVStack();
void pushV(struct Symbol *p);
struct Symbol *popV();
void printRStack();
void pushR(struct Symbol *p);
struct Symbol *popR();
void enqueue(struct Symbol* sym);
struct Symbol* dequeue();
void display();
struct Ast_node* analyse_unary(struct Ast_node *child1,struct Ast_node *child2);

struct Symbol* top_while();
void push_while(struct Symbol* whileSym);
struct Symbol *pop_while();
void Empty_Stack(int nb_elements);
void Print_Table();

