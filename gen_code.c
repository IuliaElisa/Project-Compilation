#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include "definitions.h"
//#include "structfe.tab.h"
#include "y.tab.h"

extern struct Hash_Table Symbols_Table;
extern struct Ast_node *ast_root;

int nb_temps=0, nb_etiqs=0, nb_if=0, nb_while=0, nb_for=0, nb_lines=0;
int while_top=-1, var_top=-1;
int etiq_id;
char *v_stack[20], *w_stack[20];
char str[10];

struct Symbol *curFunction=NULL;



void generateCode(struct Ast_node *p, int level){
        if (p == NULL)
        {
            return;
        }
        switch (p->node_type)
        {
            case astStart:
                processStart(p,level);
                break;
            case astProgram:
                processProgram(p, level);
                break;
            case astPointerTo:
                processPointerTo(p, level);
                break;
            case astStar:
                processStar(p, level);
                break;
            case astAdress:
                processAdress(p, level);
                break;
            case astBlock:
                processBlock(p, level);
                break;
            case astStruct:
                break;
            case astVarDecl:
                processVarDecl(p,level);
                break;
            case astDeclList:
                processDeclList(p,level);
            case astFunctionDecl:
                processFunctionDecl(p, level);
                break;
            case astFunctionDef:
                processFunctionDef(p, level);
                break;
            case astParamList:
                processParamList(p, level);
                break;
            case astStmtsList:
                processStmtsList(p, level);
                break;
            case astAssignStmt:
                processAssignStmt(p, level);
                break;
            case astReturnExpr:
                processReturnExpr(p, level);
                break;
            case astFuncCall:
                processFuncCall(p, level);
                break;
            case astArgs:
                processArgs(p, level);
                break;
            case astParam:
                processParam(p, level);
                break;
            case astAdd:
                processAdd(p, level);
                break;
            case astSub:
                processSub(p, level);
                break;
            case astMul:
                processMul(p, level);
                break;
            case astDiv:
                processDiv(p, level);
                break;
            case astLte:
                processLte(p, level);
                break;
            case astGte:
                processGte(p, level);
                break;
            case astLt:
                processLt(p, level);
                break;
            case astGt:
                processGt(p, level);
                break;
            case astEq:
                processEq(p, level);
                break;
            case astNeq:
                processNeq(p, level);
                break;
            case astAnd:
                processAnd(p, level);
                break;
            case astOr:
                processOr(p, level);
                break;
            case astConst:
                processIntConst(p, level);
                break;
            case astId:
                processId(p, level);
                break;
            case astIfStmt:
                processIf(p, level);
                break;
            case astElifStmt:
                processIfElse(p, level);
                break;
            case astFor:
                processFor(p, level);
                break;
            case astWhile:
                processWhile(p, level);
                break;
            case astUnaryM:
                processUnaryM(p, level);
                break;
            case astUnExpr:
                processUnaryExpr(p, level);
                break;
            case ast(Expr):
                processExpressionP(p, level);
                break;
            case astSize:
                processSize(p, level);
                break;
            default:
                printf("%d",p->node_type);
                printf("Error in semantics.c: No such Node Type found\n");
                break;
        }
}


void Print_Var_Stack(){
    printf ("\n#########################\n");
    for (int i=var_top; i>=0; i--)
        printf(" |%s| ", v_stack[i]);
    printf ("\n#########################\n");
        
}


void Init_Stack(){
    int i;
    char *temp;
    for(i = 0; i <= var_top; i++)
        temp = popVar();
}
void pushVar(char* var){
    v_stack[++var_top] = var;
}
    
char* popVar() {
    return v_stack[var_top--];
}


void analyse_call(struct Ast_node *p){ //func();
    if(p->node_type == astFuncCall){
        //printf("\n\t%s;\n", p->result_var);
        fprintf(strucit_backend, "\n\t%s;\n", p->result_var);
        nb_lines+=2;
        popVar();
    }
}

void reset_etiqs(){
    nb_temps = 0;
    nb_etiqs = 0;
    nb_if=0;
    nb_while=0;
    nb_for=0;
}

void add_temp(struct Symbol *f, char *name, enum Type type){
    
    struct Temps *temp;
    struct Symbol *func= find_variable(f->name);
    if(curFunction !=NULL && func->type == FUNCTION){ // just in case...
        if(func->temps == NULL){
            func->temps = malloc(sizeof(struct Temps));
            assert(func->temps !=NULL);
            strcpy(func->temps->name, name);
            func->temps->type = type;
            func->temps->next = NULL;
        }
        else{
            temp = func->temps;
            while(temp->next != NULL)
                temp = temp->next;
            
            temp->next = malloc(sizeof(struct Temps));
            assert(temp->next != NULL);
            strcpy( temp->next->name, name);
            temp->next->type = type;
            temp->next->next = NULL;
        }
    }
    else{
        printf("\nin add_temp.");
        exit(0);
    }
    
}

void print_func_temps(struct Symbol *sym){
    
    struct Temps *temp;
    temp = sym->temps;
    while(temp!=NULL){
        printf ("\n@@@@@@@@@@@@@@@@@@@@@@@@\n");
        printf ("%d %s \n", temp->type, temp->name);
        temp = temp->next;
    }
}

void processProgram(struct Ast_node *p, int level)
{
    generateCode(p->child_node[0], level+1);
    if(p->child_node[0]->node_type == astVarDecl || p->child_node[0]->node_type == astFunctionDecl){
        //printf(";\n");
        fprintf(strucit_backend, ";\n");
    }

    generateCode(p->child_node[1], level+1);
    if(p->child_node[1] && (p->child_node[1]->node_type == astVarDecl || p->child_node[1]->node_type == astFunctionDecl)){
        //printf(";\n");
        fprintf(strucit_backend, ";\n");
    }
    
}


void processFunctionDef(struct Ast_node *p, int level)
{
    fprintf(strucit_backend, "\n");
    curFunction =  p->child_node[0]->symbol_node; // for temps
    
   // if(to_add == 0){
        p->child_node[0]->symbol_node->temps = NULL;
   // }
    
    generateCode(p->child_node[0], level + 1); // var_decl (params)
    fprintf(strucit_backend, "{\n\n");
    
    //printf("{\n");
    
   /* if(to_add==1){
        struct Temps *temp = curFunction->temps;
        while(temp!=NULL){
                fprintf(strucit_backend, "\tvoid* %s;\n", temp->name);
            temp= temp->next;
        }
        //printf("\n");
    }*/
    
    generateCode(p->child_node[1], level + 1); // compound statement
    analyse_call(p->child_node[1]);
    fprintf(strucit_backend,"\n}\n\n");
    //printf("\n}\n");
    reset_etiqs();
    
    fprintf(strucit_backend, "\n");
    curFunction = NULL;
}

void processVarDecl(struct Ast_node *p, int level)
{
    if(p->symbol_node->from_function!=NULL){
       // printf("\t");
        fprintf(strucit_backend, "\t");
        
    }
      
    if(p->symbol_node->is_extern == 1){
       // printf("extern ");
        fprintf(strucit_backend, "extern ");
        
    }
    
    if(p->symbol_node->type== POINTER_TO_FUNC)
        fprintf(strucit_backend, "void* %s", p->symbol_node->name);
     
   else{
       switch(p->symbol_node->type){
           case isINT :
               //printf("int %s", p->symbol_node->name);
               fprintf(strucit_backend, "int %s", p->symbol_node->name);
               break;
           case POINTER_TO_STRUCT:
               //printf("void* %s", p->symbol_node->name);
               fprintf(strucit_backend, "void* %s", p->symbol_node->name);
               break;
           case POINTER_TO_INT:
               //printf("int* %s", p->symbol_node->name);
               fprintf(strucit_backend, "int* %s", p->symbol_node->name);
               break;
           case POINTER_TO_FUNC:
               //printf("void* %s", p->symbol_node->name);
               fprintf(strucit_backend, "void* %s", p->symbol_node->name);
               break;
           case POINTER_TO_VOID:
               //printf("void* %s", p->symbol_node->name);
               fprintf(strucit_backend, "void* %s", p->symbol_node->name);
               break;
           case FUNCTION:
               if(p->symbol_node->function_return_type == isINT){
                   //printf("int ");
                   fprintf(strucit_backend, "int ");
               }
                 
               if(p->symbol_node->function_return_type == isVOID){
                   //printf("void ");
                   fprintf(strucit_backend, "void ");
               }

               if(p->symbol_node->function_return_type == POINTER_TO_STRUCT){
                   //printf("void* ");
                   fprintf(strucit_backend, "void* ");
               }

               if(p->symbol_node->function_return_type == POINTER_TO_VOID){
                   fprintf(strucit_backend, "void* ");
                   //printf("void* ");
               }
               
               if(p->symbol_node->function_return_type == POINTER_TO_INT){
                   //printf("int* ");
                   fprintf(strucit_backend, "int* ");
               }
               //printf("%s", p->symbol_node->name);
               fprintf(strucit_backend, "%s", p->symbol_node->name);
               break;
           case isVOID:
               //printf("void %s", p->symbol_node->name);
               fprintf(strucit_backend, "void %s", p->symbol_node->name);
               break;
           default: printf("Error in var declaration.");
               exit(0);
               break;
       }
   }

}

void processFunctionDecl(struct Ast_node *p, int level){

    if(p->node_type != astDeclList){
        if(p->symbol_node->type == POINTER_TO_FUNC){
            //printf ("void *%s", p->symbol_node->name);
            fprintf(strucit_backend, "void* %s", p->symbol_node->name);
            return;
        }
        generateCode(p->child_node[0], level + 1);
        //printf("(");
        fprintf(strucit_backend, "(");
        generateCode(p->child_node[1], level + 1); // (param_list)
        //printf(")");
        fprintf(strucit_backend, ")");
       }
}


void processParamList(struct Ast_node *p, int level){
    generateCode(p->child_node[0], level + 1); // param_list
    fprintf(strucit_backend, ",");
    generateCode(p->child_node[1], level + 1); // param
}

void processBlock(struct Ast_node *p, int level){
    
    generateCode(p->child_node[0], level + 1);
    if(p->child_node[0]->node_type == astVarDecl || p->child_node[0]->node_type == astFunctionDecl){
       // printf (";\n");
        fprintf (strucit_backend, ";\n");

    }
    analyse_call(p->child_node[0]);
    fprintf(strucit_backend, "\n");

    generateCode(p->child_node[1], level + 1);
    analyse_call(p->child_node[1]);
}

void processParam(struct Ast_node *p, int level)
{
    generateCode(p->child_node[0], level + 1); // param = var_decl / func_decl
}

void processFuncCall(struct Ast_node *p, int level)
{
    char *res, temp[70] =""; // temp : func(t1,t2,...)

    generateCode(p->child_node[0], level + 1); // args
    p->result_var = strdup(p->symbol_node->name);
    strcat(temp, p->symbol_node->name);
    strcat(temp, "(");
    for(int i=0;i<p->symbol_node->nb_elements;i++){
        if(var_top==-1){
            printf ("\nIn ProcessFuncCall. Stack already empty!");
            exit(0);
        }
        res = strdup(popVar());
        if(i<p->symbol_node->nb_elements-1){
            strcat(temp, res);
            strcat(temp, ",");
        }
        else
            strcat(temp, res);
    }
    strcat(temp, ")");
    
    p->result_var = strdup(temp);
    pushVar(p->result_var);
    
}

void processArgs(struct Ast_node *p, int level)
{
    generateCode(p->child_node[0], level + 1); // function call arguments
    generateCode(p->child_node[1], level + 1); // argument
}

void processDeclList(struct Ast_node *p, int level){
  
    generateCode(p->child_node[0], level+1);
    if(p->child_node[0]->node_type != astDeclList){
        fprintf(strucit_backend, ";\n");
        //printf(";\n");
    }

    generateCode(p->child_node[1], level+1);
    if(p->child_node[1]->node_type != astDeclList){
        fprintf(strucit_backend, ";\n");
        //printf(";\n");
    }

}



void processStmtsList(struct Ast_node *p, int level)
{
    generateCode(p->child_node[0], level+1);
    analyse_call(p->child_node[0]);
    generateCode(p->child_node[1], level+1);
    analyse_call(p->child_node[1]);
}


void processAssignStmt(struct Ast_node *p, int level){

    char temp[30];
    
    if(p->child_node[0]->node_type == astUnExpr && p->child_node[0]->child_node[1]->node_type == astPointerTo){
        generateCode(p->child_node[0]->child_node[1],level+1);
        p->result_var = p->child_node[0]->child_node[1]->result_var;
        popVar();
    }
    else{
        switch(p->child_node[0]->node_type){
            case astUnExpr: // (*p)= // *p->e =
                if(p->child_node[0]->child_node[0]->node_type== astAdress)
                    sprintf(temp, "&%s", p->child_node[0]->symbol_node->name);
                if(p->child_node[0]->child_node[0]->node_type == astStar && p->child_node[0]->child_node[1]->node_type!= astPointerTo)
                    sprintf(temp, "*%s", p->child_node[0]->symbol_node->name);
                p->result_var = strdup(temp);
                break;
            case astId:
                p->result_var = strdup(p->child_node[0]->symbol_node->name);
                break;
            case astConst:
                p->result_var = strdup(p->child_node[0]->symbol_node->name);
                break;
            case ast(Expr):
                if(p->child_node[0]->child_node[0]->node_type== astStar){
                    sprintf(temp, "*%s", p->child_node[0]->symbol_node->name);
                    p->result_var = strdup(temp);
                }
                else
                    printf("ERROR in ast(Expr)\n");
                exit(0);
                break;
            case astPointerTo:
                generateCode(p->child_node[0],level+1);
                p->result_var = p->child_node[0]->result_var;
                popVar();
                break;
        }
    }


   //Print_Var_Stack();


    if(p->child_node[1]->node_type == astId || p->child_node[1]->node_type == astConst){
        //printf("\t%s = %s;\n", p->result_var, p->child_node[1]->symbol_node->name);
        fprintf(strucit_backend,"\t%s = %s;\n", p->result_var, p->child_node[1]->symbol_node->name);
        nb_lines+=1;
        return;
    }
    if(p->child_node[1]->node_type == astUnaryM && (p->child_node[1]->child_node[0]->node_type == astId || p->child_node[1]->child_node[0]->node_type == astConst)){
        //printf("\t%s = -%s;\n", p->result_var, p->child_node[1]->child_node[0]->symbol_node->name);
        fprintf(strucit_backend, "\t%s = -%s;\n", p->result_var, p->child_node[1]->child_node[0]->symbol_node->name);
        nb_lines+=1;
        return;
    }
    if(p->child_node[1]->node_type == ast(Expr) && p->child_node[1]->child_node[0]->node_type == astAdress){
       //printf("\t%s = (&%s);\n", p->result_var, p->child_node[1]->child_node[1]->symbol_node->name);
        fprintf(strucit_backend, "\t%s = (&%s);\n", p->result_var, p->child_node[1]->child_node[1]->symbol_node->name);
        nb_lines+=1;
        return;
    }
    if(p->child_node[1]->node_type == ast(Expr) && p->child_node[1]->child_node[0]->node_type == astStar){
        //printf("\t%s = (&%s);\n", p->result_var, p->child_node[1]->child_node[1]->symbol_node->name);
        fprintf(strucit_backend, "\t%s = (&%s);\n", p->result_var, p->child_node[1]->child_node[1]->symbol_node->name);
        nb_lines+=1;
        return;
    }
    
    if(p->child_node[1]->node_type == astUnExpr && p->child_node[1]->child_node[0]->node_type == astAdress){
        //printf("\t%s = &%s;\n",  p->result_var, p->child_node[1]->child_node[1]->symbol_node->name);
        fprintf(strucit_backend, "\t%s = &%s;\n",  p->result_var, p->child_node[1]->child_node[1]->symbol_node->name);
        nb_lines+=1;
        return;
    }
    if(p->child_node[1]->node_type == astUnExpr && p->child_node[1]->child_node[0]->node_type == astStar){
        //printf("\t%s = *%s;\n", p->result_var, p->child_node[1]->child_node[1]->symbol_node->name);
        fprintf(strucit_backend, "\t%s = *%s;\n", p->result_var, p->child_node[1]->child_node[1]->symbol_node->name);
        nb_lines+=1;
        return;
    }
   
    if(p->child_node[1]->node_type == astFuncCall){
        if(p->child_node[1]->symbol_node->nb_elements == 0){
           // printf("\t%s = %s();\n", p->result_var, p->child_node[1]->symbol_node->name);
            fprintf(strucit_backend, "\t%s = %s();\n", p->result_var, p->child_node[1]->symbol_node->name);
            nb_lines+=1;
            return;
        }
        if(p->child_node[1]->child_node[0]->node_type == astId || p->child_node[1]->child_node[0]->node_type == astConst){
        //printf("\t%s = %s(%s);\n", p->result_var, p->child_node[1]->symbol_node->name, p->child_node[1]->child_node[0]->symbol_node->name);
        fprintf(strucit_backend, "\t%s = %s(%s);\n", p->result_var, p->child_node[1]->symbol_node->name, p->child_node[1]->child_node[0]->symbol_node->name);
            nb_lines+=1;
        return;
        }
        
    }
    
    if(p->child_node[1]->node_type == astPointerTo){
        generateCode(p->child_node[1],level+1);
        popVar();
        //printf("\t%s = %s;\n", p->result_var,p->child_node[1]->result_var); // t1 = p+x; p = _t1;
        fprintf(strucit_backend, "\t%s = %s;\n", p->result_var,p->child_node[1]->result_var); // t1 = p+x; p = _t1;
        nb_lines+=1;
        return;
    }
    char op[5];
    
    if(p->child_node[1]->child_node[0]->node_type == astSize){
        generateCode(p->child_node[1]->child_node[0],level+1);
        char *res = strdup(popVar());
       // printf("\t%s = %s (%s);\n", p->result_var, p->child_node[1]->symbol_node->name, res);
        fprintf(strucit_backend, "\t%s = %s (%s);\n", p->result_var, p->child_node[1]->symbol_node->name, res);
        nb_lines+=1;
        return;
    }
    
    if (p->child_node[1]->child_node[0]->child_node[0] == NULL &&p->child_node[1]->node_type!=astAssignStmt){ // var1 = var2 op var 3
        switch(p->child_node[1]->node_type){
            case astAdd: strcpy(op,"+");
                        break;
            case astSub: strcpy(op,"-");
                        break;
            case astOr: strcpy(op,"||");
                        break;
            case astAnd: strcpy(op,"&&");
                        break;
            case astEq: strcpy(op,"==");
                        break;
            case astNeq: strcpy(op,"!="); // ok gcc
                        break;
            case astGt: strcpy(op,">");
                        break;
            case astLt: strcpy(op,"<");
                break;
            case astLte: strcpy(op,"<=");
                break;
            case astGte: strcpy(op,">=");
                break;
        }
        //printf("\t%s = %s %s %s;\n", p->result_var, p->child_node[1]->child_node[0]->symbol_node->name, op, p->child_node[1]->child_node[1]->symbol_node->name);
        fprintf(strucit_backend, "\t%s = %s %s %s;\n", p->result_var, p->child_node[1]->child_node[0]->symbol_node->name, op, p->child_node[1]->child_node[1]->symbol_node->name);
        nb_lines+=1;
        return;
    }
    // we need temp vars
    generateCode(p->child_node[1], level + 1); // right
    
    if(var_top==2){ // var1 = var2 op var3
        char *op, *rlhs, *rrhs;
        op = strdup(popVar());
        rlhs = strdup(popVar());
        rrhs = strdup(popVar());
        //printf("\t%s = %s %s %s;\n", p->result_var, rlhs, op, rrhs);
        fprintf(strucit_backend, "\t%s = %s %s %s;\n", p->result_var, rlhs, op, rrhs);
        nb_lines+=1;
        return;
    }
    if(var_top==1){ // var1 = &t2 / *t2
        char *op, *rlhs;
        op = strdup(popVar());
        rlhs = strdup(popVar());
        //printf("\t%s =  %s %s;\n", p->result_var, op,rlhs);
        fprintf(strucit_backend, "\t%s =  %s %s;\n", p->result_var, op,rlhs);
        nb_lines+=1;
        return;
    }
    if(var_top==0){ // var1 = t2 / *
        char *rlhs;
        rlhs = strdup(popVar());
        //printf("\t%s =  %s;\n", p->result_var, rlhs);
        fprintf(strucit_backend, "\t%s =  %s;\n", p->result_var, rlhs);
        nb_lines+=1;
        return;
    }
    if(var_top == -1){ // a=b=c res in b
        //printf("\t%s = %s;\n", p->result_var, p->child_node[1]->result_var);
        fprintf(strucit_backend, "\t%s = %s;\n", p->result_var, p->child_node[1]->result_var);
        nb_lines+=1;
    }
}


void processSize(struct Ast_node *p, int level){
    int size = 0;
    struct Symbol *from_struct = p->symbol_node->pointed_struct;
    char temp[10];
  
    for(int i=0;i<p->symbol_node->pointed_struct->nb_elements; i++){
            if(from_struct->fields_list[i]->type > 5) // POINTER_TO
                size +=8;
            else
                size +=4;
    }
    sprintf(temp,"%d", size);
    p->result_var= strdup(temp);
    pushVar(p->result_var);
}

void processPointerTo(struct Ast_node *p, int level){ // p->id

    struct Symbol *from_struct = p->symbol_node->pointed_struct;
    int offset =0;
    for(int i=0;i<from_struct->nb_elements;i++){
        if(strcmp(from_struct->fields_list[i]->name,p->child_node[0]->symbol_node->name)!=0)
        {
            if(from_struct->fields_list[i]->type > 5) // POINTER_TO
                offset +=8;
            else
                offset +=4;
        }
    }
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
    //printf( "   %s = %s + %d;\n", temp, p->symbol_node->name, offset);
    fprintf(strucit_backend,  "\t%s = %s + %d;\n", temp, p->symbol_node->name, offset);
    nb_lines+=1;
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}


void processExpressionP(struct Ast_node *p, int level){
 
    
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    generateCode(p->child_node[0], level + 1);
    generateCode(p->child_node[1], level + 1);
    if(p->child_node[0]->node_type == astStar || p->child_node[0]->node_type == astAdress){
        char *rhs = strdup(popVar());
        if(p->child_node[0]->node_type == astStar){
            //printf("    %s = *%s;\n",res, p->child_node[1]->symbol_node->name);
            fprintf(strucit_backend, "\t%s = *%s;\n",temp,rhs);
            if(var_top)
            popVar();
        }
       
        else{
            //printf("    %s = &%s;\n",res, p->child_node[1]->symbol_node->name);
            fprintf(strucit_backend, "\t%s = &%s;\n",temp,rhs);
            if(var_top)
            popVar();
        }
        
        
        p->result_var = strdup(temp);
        pushVar(p->result_var);
   
}
    else{
        printf("\nSee processExpP\n");
        exit(0);
    }
}

       
void processUnaryExpr(struct Ast_node *p, int level){ // *|& t_x

    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
 
    if(p->child_node[0]->node_type == astAdress){
        //printf("\t%s = &%s;\n", temp, p->child_node[1]->symbol_node->name);
        fprintf(strucit_backend, "\t%s = &%s;\n", temp, p->child_node[1]->symbol_node->name);
    }
     
    else{
        //printf("    %s = *%s;\n", temp, p->child_node[1]->symbol_node->name);
        fprintf(strucit_backend, "\t%s = *%s;\n", temp, p->child_node[1]->symbol_node->name);
    } // astStar
       
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}

void processId(struct Ast_node *p, int level){

    p->result_var = strdup(p->symbol_node->name);
    pushVar(p->result_var);
}

void processIntConst(struct Ast_node *p, int level){

    p->result_var = strdup(p->symbol_node->name);
    pushVar(p->result_var);
}

void processIf(struct Ast_node *p, int level){ // astIfStmt

    char etiq[10], op[5];
    sprintf(etiq, "Lelse%d",++nb_if);

    if((p->child_node[0]->node_type >=538 && p->child_node[0]->node_type <=544 && (p->child_node[0]->child_node[0]->node_type == astId || p->child_node[0]->child_node[0]->node_type == astConst ))){
      if(p->child_node[0]->child_node[1]->node_type == astConst || p->child_node[0]->child_node[1]->node_type == astId)  {
          switch(p->child_node[0]->node_type){
              case astEq: strcpy(op,"!=");
                          break;
              case astNeq: strcpy(op,"=="); // ok gcc
                          break;
              case astGt: strcpy(op,"<=");
                          break;
              case astLt: strcpy(op,">=");
                  break;
              case astLte: strcpy(op,">");
                  break;
              case astGte: strcpy(op,"<");
                  break;
          }

          //printf( "\n   if(%s %s %s) goto %s;\n{\n",p->child_node[0]->child_node[0]->symbol_node->name,op, p->child_node[0]->child_node[1]->symbol_node->name, etiq);
          fprintf( strucit_backend, "   if(%s %s %s) goto %s;\n{\n",p->child_node[0]->child_node[0]->symbol_node->name,op, p->child_node[0]->child_node[1]->symbol_node->name, etiq);
          generateCode(p->child_node[1],level+1);  // Statements list
          analyse_call(p->child_node[1]);
          //printf("\n}\n");
          fprintf(strucit_backend, "\n}\n");
          //printf( "\n%s:\n", etiq); // abstract else
          fprintf( strucit_backend, "\n%s:\n", etiq); // abstract else
          return;
          
        }
        
    }// need temps
    generateCode(p->child_node[0],level+1); // Condition
    char *var = strdup(popVar());
    //printf( "   if( !%s ) goto %s;\n{\n",var, etiq);
    fprintf(strucit_backend, "   if( !%s ) goto %s;\n{\n",var, etiq);
    nb_lines+=2;
    generateCode(p->child_node[1],level+1);  // Statements list
    analyse_call(p->child_node[1]);
    //printf("\n}\n");
    fprintf(strucit_backend, "\n}\n");
    nb_lines+=2;
    //printf( "\n%s:\n", etiq); // abstract else
    fprintf(strucit_backend,  "\n%s:\n", etiq); // abstract else
    nb_lines+=2;
}


void processIfElse(struct Ast_node *p, int level){

    char etiq[10], op[]="//";
    sprintf(etiq, "Lelse%d",++nb_if);

    if((p->child_node[0]->node_type >=538 && p->child_node[0]->node_type <=544 && (p->child_node[0]->child_node[0]->node_type == astId || p->child_node[0]->child_node[0]->node_type == astConst ))){
      if(p->child_node[0]->child_node[1]->node_type == astConst || p->child_node[0]->child_node[1]->node_type == astId)  {
          switch(p->child_node[0]->node_type){
              case astEq: strcpy(op,"!=");
                          break;
              case astNeq: strcpy(op,"=="); // ok gcc
                          break;
              case astGt: strcpy(op,"<=");
                          break;
              case astLt: strcpy(op,">=");
                  break;
              case astLte: strcpy(op,">");
                  break;
              case astGte: strcpy(op,"<");
                  break;
          }
          
          //printf( "   if(%s %s %s) goto %s;\n{\n",p->child_node[0]->child_node[0]->symbol_node->name,op, p->child_node[0]->child_node[1]->symbol_node->name, etiq);
          fprintf(strucit_backend,  "   if(%s %s %s) goto %s;\n{\n",p->child_node[0]->child_node[0]->symbol_node->name,op, p->child_node[0]->child_node[1]->symbol_node->name, etiq);

          generateCode(p->child_node[1],level+1);  // Statements list
          analyse_call(p->child_node[1]);
          //printf("\n}\n");
          fprintf(strucit_backend, "\n}\n");
          //printf( "\n%s:\n{\n", etiq);
          fprintf(strucit_backend, "\n%s:\n{", etiq);

          generateCode(p->child_node[2],level+1); // else statement list
          analyse_call(p->child_node[2]);
          //printf( "\n}\n");
          fprintf(strucit_backend, "\n}\n");

          return;
          
        }
        
    }
    
    generateCode(p->child_node[0],level+1); // Condition
    char *var = strdup(popVar());
    //printf( "   if( !%s ) goto %s;\n{\n", var, etiq);
    fprintf(strucit_backend, "   if( !%s ) goto %s;\n{\n", var, etiq);

    generateCode(p->child_node[1],level+1);  // Statements list
    analyse_call(p->child_node[1]);
    //printf("\n}\n");
    fprintf(strucit_backend, "\n}\n");
    
    //printf( "\n%s:\n{", etiq);
    fprintf(strucit_backend,  "\n%s:\n{", etiq);
    generateCode(p->child_node[2],level+1); // else statement list
    analyse_call(p->child_node[2]);
    //printf( "\n}\n");
    fprintf(strucit_backend, "\n}\n");
    nb_lines+=2;
}


void processWhile(struct Ast_node *p, int level)
{
    char op[5], etiq[10], els[10];
    if((p->child_node[0]->node_type >=538 && p->child_node[0]->node_type <=544 && (p->child_node[0]->child_node[0]->node_type == astId || p->child_node[0]->child_node[0]->node_type == astConst ))){
      if(p->child_node[0]->child_node[1]->node_type == astConst || p->child_node[0]->child_node[1]->node_type == astId)  {
          switch(p->child_node[0]->node_type){
              case astEq: strcpy(op,"!=");
                          break;
              case astNeq: strcpy(op,"=="); // ok gcc
                          break;
              case astGt: strcpy(op,"<=");
                          break;
              case astLt: strcpy(op,">=");
                  break;
              case astLte: strcpy(op,">");
                  break;
              case astGte: strcpy(op,"<");
                  break;
          }
        
        sprintf(etiq,"LWhile%d",++nb_while);
        sprintf(els,"Lelse%d",++nb_if);
        
        //printf("\ngoto %s;\n", etiq); // goto LWhile1;
        fprintf(strucit_backend, "\ngoto %s;\n", etiq); // goto LWhile1;
        //printf( "\n%s: if (%s %s %s) goto %s;\n",etiq, p->child_node[0]->child_node[0]->symbol_node->name,op, p->child_node[0]->child_node[1]->symbol_node->name, els);// Ltest1: if (non...) goto Lelse1;
        fprintf(strucit_backend, "\n%s: if (%s %s %s) goto %s;\n",etiq, p->child_node[0]->child_node[0]->symbol_node->name,op, p->child_node[0]->child_node[1]->symbol_node->name, els);

        generateCode(p->child_node[1],level+1); // stmts
          analyse_call(p->child_node[1]);
        //printf("\ngoto %s;\n", etiq); // goto LWhile;
        fprintf(strucit_backend, "\ngoto %s;\n", etiq); // goto LWhileN;
        //printf("\n%s: \n", els); //Lelse1 :
        fprintf(strucit_backend, "\n %s: \n", els); //Lelse1 :
        return;
    }
    
}
    generateCode(p->child_node[0],level+1);
    sprintf(etiq,"LWhile%d",++nb_while);
    sprintf(els,"Lelse%d",++nb_if);
    char *var = strdup(popVar());
    
    //printf("\n\tgoto %s;\n", etiq); // goto LWhile1;
    fprintf(strucit_backend, "\n\tgoto %s;\n", etiq); // goto LWhile1;

    //printf( "\n%s: if (!%s) goto %s;\n",etiq,var, els);// Ltest1: if (non...) goto Lelse1;
    fprintf( strucit_backend, "\n%s: if ( !%s ) goto %s;\n",etiq,var, els);// LWhile1: if (non...) goto Lelse1;

    generateCode(p->child_node[1],level+1); // stmts
    analyse_call(p->child_node[1]);
    //printf("\ngoto %s;\n", etiq); // goto LWhile;
    fprintf(strucit_backend, "\ngoto %s;\n", etiq); // goto LWhile;

    //printf("\n%s: \n", els); //Lelse1 :
    fprintf(strucit_backend, "\n %s: \n", els); //Lelse1 :

}


void processFor(struct Ast_node *p, int level){
 
    generateCode(p->child_node[0], level+1); // expression_statement 1
    char *res;
    char etiq[10];
    char for_etiq[10];

    sprintf(etiq,"Ltest%d",++nb_etiqs);
    sprintf(for_etiq,"Lfor%d",++nb_for);
    //printf("\n\tgoto %s;\n", etiq);
    //printf("\n%s:\n", for_etiq);
    fprintf(strucit_backend, "\n\tgoto %s;\n", etiq);
    fprintf(strucit_backend, "\n%s:\n", for_etiq);
    
    generateCode(p->child_node[3], level+1); // Statement_list
    analyse_call(p->child_node[3]);
    generateCode(p->child_node[2], level+1); // inc
    analyse_call(p->child_node[2]);
    generateCode(p->child_node[1], level+1); // condition
    analyse_call(p->child_node[1]);
    res = strdup(popVar());
    //printf("    %s:", etiq);
    fprintf(strucit_backend, "    %s:", etiq);

    //printf("   if ( %s ) goto %s;\n", res, for_etiq);
    fprintf(strucit_backend, "   if ( %s ) goto %s;\n", res, for_etiq);
    nb_lines+=1;
}

void processLte(struct Ast_node *p,  int level)
{
   
    generateCode(p->child_node[0], level+1);
    generateCode(p->child_node[1], level+1);
    char *rhs = strdup(popVar());
    char *lhs = strdup(popVar());
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
    //printf("\t%s = %s <= %s;\n",temp, lhs, rhs);
    fprintf(strucit_backend, "\t%s = %s <= %s;\n",temp, lhs, rhs);
    nb_lines+=1;
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}

void processGte(struct Ast_node *p, int level)
{
  
    generateCode(p->child_node[0], level+1);
    generateCode(p->child_node[1], level+1);
    char *rhs = strdup(popVar());
    char *lhs = strdup(popVar());
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
    //printf("\t%s = %s >= %s;\n",temp, lhs, rhs);
    fprintf(strucit_backend, "\t%s = %s >= %s;\n",temp, lhs, rhs);
    nb_lines+=1;
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}

void processEq(struct Ast_node *p, int level)
{

    generateCode(p->child_node[0], level+1);
    generateCode(p->child_node[1], level+1);
    char *rhs = strdup(popVar());
    char *lhs = strdup(popVar());
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
    //printf("\t%s = %s == %s;\n",temp, lhs, rhs);
    fprintf(strucit_backend, "\t%s = %s == %s;\n",temp, lhs, rhs);
    nb_lines+=1;
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}

void processNeq(struct Ast_node *p, int level)
{

    generateCode(p->child_node[0], level+1);
    generateCode(p->child_node[1], level+1);
    char *rhs = strdup(popVar());
    char *lhs = strdup(popVar());
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
    //printf("\t%s = %s != %s;\n",temp, lhs, rhs);
    fprintf(strucit_backend, "\t%s = %s != %s;\n",temp, lhs, rhs);
    nb_lines+=1;
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}

void processGt(struct Ast_node *p, int level)
{

    generateCode(p->child_node[0], level+1);
    generateCode(p->child_node[1], level+1);
    char *rhs = strdup(popVar());
    char *lhs = strdup(popVar());
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
    //printf("\t%s = %s > %s;\n",temp, lhs, rhs);
    fprintf(strucit_backend, "\t%s = %s > %s;\n",temp, lhs, rhs);
    nb_lines+=1;
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}

void processLt(struct Ast_node *p, int level)
{
    generateCode(p->child_node[0], level+1);
    generateCode(p->child_node[1], level+1);
    char *rhs = strdup(popVar());
    char *lhs = strdup(popVar());
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
    //printf("\t%s = %s < %s;\n",temp, lhs, rhs);
    fprintf(strucit_backend, "\t%s = %s < %s;\n",temp, lhs, rhs);
    nb_lines+=1;
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}

void processAnd(struct Ast_node *p, int level)
{
    generateCode(p->child_node[0], level+1);
    generateCode(p->child_node[1], level+1);
    char *rhs = strdup(popVar());
    char *lhs = strdup(popVar());
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
    //printf("\t%s = %s && %s;\n",temp, lhs, rhs);
    fprintf(strucit_backend, "\t%s = %s && %s;\n",temp, lhs, rhs);
    nb_lines+=1;
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}

void processOr(struct Ast_node *p, int level)
{
    generateCode(p->child_node[0], level+1);
    generateCode(p->child_node[1], level+1);
    char *rhs = strdup(popVar());
    char *lhs = strdup(popVar());
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
    //printf("\t%s = %s || %s;\n",temp, lhs, rhs);
    fprintf(strucit_backend, "\t%s = %s || %s;\n",temp, lhs, rhs);
    nb_lines+=1;
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}


void processAdd(struct Ast_node *p, int level)
{
    generateCode(p->child_node[0], level+1);
    generateCode(p->child_node[1], level+1);
    char *rhs = strdup(popVar());
    char *lhs = strdup(popVar());
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
    //printf("\t%s = %s + %s;\n",temp, lhs, rhs);
    fprintf(strucit_backend, "\t%s = %s + %s;\n",temp, lhs, rhs);
    nb_lines+=1;
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}

void processMul(struct Ast_node *p, int level)
{
    generateCode(p->child_node[0], level+1);
    generateCode(p->child_node[1], level+1);
    char *rhs = strdup(popVar());
    char *lhs = strdup(popVar());
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
    //printf("\t%s = %s * %s;\n",temp, lhs, rhs);
    fprintf(strucit_backend, "\t%s = %s * %s;\n",temp, lhs, rhs);
    nb_lines+=1;
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}

void processDiv(struct Ast_node *p, int level)
{
    generateCode(p->child_node[0], level+1);
    generateCode(p->child_node[1], level+1);
    char *rhs = strdup(popVar());
    char *lhs = strdup(popVar());
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
    //printf("\t%s = %s / %s;\n",temp, lhs, rhs);
    fprintf(strucit_backend, "\t%s = %s / %s;\n",temp, lhs, rhs);
    nb_lines+=1;
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}


void processSub(struct Ast_node *p, int level)
{
   
    generateCode(p->child_node[0], level+1);
    generateCode(p->child_node[1], level+1);
    char *rhs = strdup(popVar());
    char *lhs = strdup(popVar());
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
    //printf("\t%s = %s - %s;\n",temp, lhs, rhs);
    fprintf(strucit_backend, "\t%s = %s - %s;\n",temp, lhs, rhs);
    nb_lines+=1;
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}

void processReturnExpr(struct Ast_node *p, int level)
{
    if(p->child_node[0]){
        if(p->child_node[0]->node_type == astId || p->child_node[0]->node_type == astConst){
            //printf ("\treturn %s;\n", p->child_node[0]->symbol_node->name);
            fprintf (strucit_backend, "\treturn %s;\n", p->child_node[0]->symbol_node->name);
            nb_lines+=1;
            return;
        }
        
        if(p->child_node[0]->node_type == astPointerTo){
            generateCode(p->child_node[0],level+1);
            popVar();
       
            p->result_var = p->child_node[0]->result_var;
            
            //printf("\treturn %s;\n", p->result_var);
            fprintf(strucit_backend, "\treturn %s;\n", p->result_var);
            return;
        }
        if(p->child_node[0]->node_type == astUnExpr){
            if(p->child_node[0]->child_node[0]->node_type == astAdress){
                //printf ("\treturn &%s;\n", p->child_node[0]->symbol_node->name);
                fprintf (strucit_backend, "\treturn &%s;\n", p->child_node[0]->symbol_node->name);
                return;
            }
            if(p->child_node[0]->child_node[0]->node_type == astStar){
                //printf ("\treturn *%s;\n", p->child_node[0]->symbol_node->name);
                fprintf (strucit_backend, "\treturn *%s;\n", p->child_node[0]->symbol_node->name);
                return;
            }
        }
        if(p->child_node[0]->node_type == ast(Expr)){
            if(p->child_node[0]->child_node[0]->node_type == astAdress){
                //printf ("\treturn &%s;\n", p->child_node[0]->symbol_node->name);
                fprintf (strucit_backend, "\treturn &%s;\n", p->child_node[0]->symbol_node->name);
                return;
            }
            if(p->child_node[0]->child_node[0]->node_type == astStar){
                //printf ("\treturn *%s;\n", p->child_node[0]->symbol_node->name);
                fprintf (strucit_backend, "\treturn *%s;\n", p->child_node[0]->symbol_node->name);
                return;
            }
        }
        
        generateCode(p->child_node[0], level+1); // gen expression if non-NULL
        char *res = strdup(popVar());
        fprintf(strucit_backend,  "\n\treturn %s;\n",res);
        return;
    }
        fprintf(strucit_backend, "\n\treturn;\n");
}

void processStar(struct Ast_node *p, int level){
    pushVar("*");
}

void processAdress(struct Ast_node *p, int level){
    pushVar("&");
}

void processUnaryM(struct Ast_node *p, int level){
    generateCode(p->child_node[0], level+1);
    char *res = strdup(popVar());
    char temp[10];
    sprintf(temp, "_t%d", ++nb_temps);
    add_temp(curFunction, temp, POINTER_TO_VOID);
    fprintf(strucit_backend, " \t %s = -%s;\n",temp,res);
    nb_lines+=1;
    p->result_var = strdup(temp);
    pushVar(p->result_var);
}

void processStart(struct Ast_node *p, int level){
    generateCode(p->child_node[0], level+1);
}
