#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int existe_erreur();

extern FILE *strucit_backend;
#define NAME_LEN 100
#define SYM_TABLE_SIZE 101

/* ----  Definitions des constantes pour le << type >> des nodes d'arbre syntaxique ---- */
#define astReturnExpr 481
#define astUnaryM 482 //
#define astDeclList 483 //
#define astBlock 484 //
#define astConst 485
#define astReturn 486
#define astEmpty 487 // function with 0 params
#define astStruct 488 //
#define astSize 489
#define astUnExpr 490 //
#define astStar 491
#define astAdress 492
#define astRelExp 493
#define astPointerTo 494 //
#define astPostExpr 495
#define astDeclarator 496 //
#define astVarDecl 498
#define astProgram 500
#define astFunctionDef 501
#define astFunctionDecl 502
#define astParamList 504 // 
#define astStmtsList 505
#define astAssignStmt 506
#define astFor 507 // 
#define astWhile 508
#define astSelStmt 510
#define astIfStmt 512 //
#define astElifStmt 513 //
#define astElseStmt 514 //
#define astFuncCall 518 //
#define astArgs 522 //
#define astParam 525 //
#define ast(Expr) 527 //
#define astInt 530 //
#define astVoid 534 //
#define astAdd 535 //
#define astSub 536 //
#define astMul 537 //
#define astDiv 538 //
#define astLte 539 //
#define astGte 540 //
#define astLt 541 //
#define astGt 542 //
#define astEq 543 //
#define astNeq 544 //
#define astAnd 545 //
#define astOr 546 //
#define astStructList 547
#define astStart 549 //
#define astExt 550 //
#define astDeclSpecs 551 //
#define astId 559 //

enum Type{UNDEFINED, isINT, isVOID, isSTRUCT, FUNCTION, POINTER, POINTER_TO_INT, POINTER_TO_VOID, POINTER_TO_FUNC, POINTER_TO_STRUCT};


/* -----------------------  Definition structure Symbol ------------------------- */
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
  int value;                            /* for constant */
  int is_param;                         /* var/pointer. if 1, var can't be redeclared in function.  */
  struct Symbol *next;                  /* Pointer to the next symbol in the symbol table */
  struct Temps *temps;
};


/*-----------------------  Definition structure Hash Table ------------------------- */
struct Hash_Table {
  int nbSymbols;
  struct Symbol *symbols[SYM_TABLE_SIZE];
};


/*-----------------------  Definition structure AST-node ------------------------- */
struct Ast_node {
  int node_type; //make a node of type astTYPE
  struct Symbol *symbol_node; // the node can have a symbol from makeSymbol attached to it
  enum Type expression_type; // for expressions
  struct Ast_node *child_node[4]; //has at most 4 childre
  char *result_var; // for generating code
};


struct Temps{
    char name[10];
    enum Type type;
    struct Temps *next;
};
/* ----------------------- Function Prototypes -------------------------*/

void Init_Stack();
int yyparse();
void init_tables();
void print_tables();

struct Ast_node* makeNode(int type, struct Symbol *sn, struct Ast_node* first, struct Ast_node* second, struct Ast_node* third, struct Ast_node* fourth);
struct Symbol* makeSymbol(char *name, enum Type type, int value, int size,char tag,int no_elements);
void add_variable_to_table(struct Symbol *symbp);
int genKey(char *s);
void add_variable(struct Symbol *symbol_pointer);
struct Symbol *find_variable(char *variable_name);
struct Symbol *find_to_add(char *variable_name);
void complete_type (struct Symbol *sym, struct Ast_node *child_node);
void traverse(struct Ast_node* p, int n);
void printVStack();
void pushV(struct Symbol *p);
struct Symbol *popV();

void analyse_call(struct Ast_node *p);
struct Ast_node* popArg();
void pushArg();
void printAStack();
struct Ast_node* analyse_unary(struct Ast_node *child1,struct Ast_node *child2);
void Empty_Stack(int nb_elements);
void Print_Table();

void reset_etiqs();
void add_temp(struct Symbol *func, char *name, enum Type type);

void freeAST(struct Ast_node *p);
void freeSymTable();




void Print_Var_Stack();

void pushVar(char* var);
char* popVar();

void analyse_call(struct Ast_node *p);
void reset_etiqs();

void print_func_temps(struct Symbol *sym);

void processProgram(struct Ast_node *p, int level);
void processFunctionDef(struct Ast_node *p, int level);
void processVarDecl(struct Ast_node *p, int level);

void processFunctionDecl(struct Ast_node *p, int level);

void processParamList(struct Ast_node *p, int level);
void processBlock(struct Ast_node *p, int level);

void processParam(struct Ast_node *p, int level);

void processFuncCall(struct Ast_node *p, int level);

void processArgs(struct Ast_node *p, int level);

void processStmtsList(struct Ast_node *p, int level);

void processAssignStmt(struct Ast_node *p, int level);

void processSize(struct Ast_node *p, int level);

void processPointerTo(struct Ast_node *p, int level);

void processExpressionP(struct Ast_node *p, int level);

       
void processUnaryExpr(struct Ast_node *p, int level);
void processId(struct Ast_node *p, int level);
void processIntConst(struct Ast_node *p, int level);
void processIf(struct Ast_node *p, int level);

void processIfElse(struct Ast_node *p, int level);


void processWhile(struct Ast_node *p, int level);

void processFor(struct Ast_node *p, int level);

void processLte(struct Ast_node *p,  int level);
void processGte(struct Ast_node *p, int level);
void processEq(struct Ast_node *p, int level);
void processNeq(struct Ast_node *p, int level);
void processGt(struct Ast_node *p, int level);
void processLt(struct Ast_node *p, int level);
void processAnd(struct Ast_node *p, int level);

void processOr(struct Ast_node *p, int level);
void processAdd(struct Ast_node *p, int level);

void processMul(struct Ast_node *p, int level);

void processDiv(struct Ast_node *p, int level);

void processSub(struct Ast_node *p, int level);
void processReturnExpr(struct Ast_node *p, int level);

void processStar(struct Ast_node *p, int level);

void processAdress(struct Ast_node *p, int level);
void processUnaryM(struct Ast_node *p, int level);
void processStart(struct Ast_node *p, int level);

void generateCode(struct Ast_node *p, int level);

void processDeclList(struct Ast_node *p, int level);

