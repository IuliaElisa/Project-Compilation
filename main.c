extern int *ffff(); /* OK */
int id(int a ,int b,int c, int d); /* OK */

int (*lll)(int a,int b);
struct test{
    int aa;
    int bb;
    int cc;
    int dd;
    int (*f)(int agg,int bgg);
} *ttt(); /* OK */

extern int d;

struct teste{
    int a;
    int b;
}*ttet(); /* OK */

struct hey;

/*
struct teste{
    int c;
};  redef de teste  */


struct liste {
    int valeur;
    int *e;
    struct liste *suivant;
};

int aa(int a,int e, int h, int g, int k ){
    
    struct teste *p;  /* ok ! */
    struct test2{int x; int y;} *pp;
    int b;
    int c;
    int j;
    int *d;
    /* int a; redef de 'a' */
    p->a = 10;
    a=(2+3);
    d = &g;
}

/* Fonctions externes utilisées */

/* void *a; STRUCIT: "Variable 'a' a un type illegale." */

/*
int (*d)(int a){
    
    int bb;
}
 STRUCIT: "'d' est un pointeur sur fonction. compound_statement innattendu."*/


extern void *malloc(int size);
extern void free(void *ptr);

/*
int f(void *p){
    int a;
} Redef de f*/

/* Allocation du prochain element de la liste */



struct liste *allouer(struct liste *p) {

   /*  struct test2 *pp;
    pp->x = 10; "Pas de membre 'x' dans 'struct test2'
    gcc: incomplete definition of type 'struct test2' */
    int *q;
    struct liste *s;
   /*  struct {int i;int j;} *tt;
       tt->i=3; OK */
  /*  *q = 1+sizeof(s)*(1+2); */
  if (p!=0) {

        p->suivant=malloc(sizeof(p));
        return p->suivant;

  } else {

        p=malloc(sizeof(p));

        return p;

  }

}


/* Desallocation de l'element courant de la liste */

struct liste *desallouer(struct liste *p) {

  struct liste *q;

  q=p->suivant;

  free(p);

  return q;

}

/* Iterateur sur la liste. Applique la fonction f sur chaque element */

struct liste *parcours(struct liste *l, struct liste *(*f)(struct liste *p)) {

  int i;
  struct liste *p;
  struct liste *tete;

  tete=p=f(l); 

  for (i=0; i<100; i=i+1) {

    p=f(p);

  }
  return tete;
}
/* Alloue une liste chainee puis la desalloue */


int ee(){
    struct liste *p;
    int *e;
    return 10;
}


int main() {

  int a;
    int b;
    int c;
  int *tes;
    int *q;
    
  struct liste *p;
  struct liste *tete;
    struct liste * (*pp)();
    
    int i;
   /* p=tes; "Operandes avec des types incompatibles." */
    
    b = a!=3; /* ok */
    if(p && 2)
        return 0;
    /* p = -tete; arg invalide pour une expression unaire */
    /* p = p+q; Operandes invalides pour une expression binaire. (pointer+pointer) */
    i = (&ee)(); /* ok */
    i = ee(); /* ok */
    i = (*ee)(); /* ok in C */
    i = (*****ee)(); /* ok in C */
   /* i = (****ffff);  "Operandes avec des types incompatibles." */
    (*tes)=(*q)=a; /* ok */
    /* (&a) = (&b) = tes; error: expression n'est pas assignable */
    /* (&a)= tes; expression n'est pas assignable*/
    tes = (&a); /* ok*/
    a = (*tes); /* ok*/
    a = (1+2+3); /*ok*/
    i = (&ee)(); /* ok */
    
    p->valeur=i;
   /* p = p*i; Operandes invalides pour une expression binaire. */
    i = i&&i; /* ok */
    i = p||q; /* ok */
    
  /*   if(tes != p) error: "Comparaison entre pointeurs avec des types distincts." */
     
    /* parcours(p,pp) = tete; erreur . expr is not assignable */
    i = (*ee)(); /* OK */
    pp()->valeur = i; /* OK */
    for (i =10;i<12;i=3)
        i=i+1;
    *p->e = a; /* ok. derref p->e */
 /* ee()->suivant =   p; error: "Variable 'ee' n'est pas un pointeur sur structure." */
    
   /*  tes = &ee(); "Ne peut pas prendre l'adresse d'une valeur de retour."*/
    /*  f() = a; "Operands invalids pour une expression binaire. (Expression is not assignable)." */
   /* i = *ee(); "Indirection requires pointer operand ('int' invalid). " */
    /* i=(*ffff)(); "Operandes avec des types incompatibles." */
    if(a==b==c)
        return 2;
   /* tes = *p; "Déréférencier une variable de type (struct *) donne une variable struct qui n'est pas autorisée en STRUCIT."*/
  /* aaaa(20+3)=bbb(2+3)=3;  usage d'un identificateyur nedeclare aaaa*/
    /*  a = 10(2+3);  "Objet appelé de type 'int' n'est pas une fonction ou pointeur sur function" */
    /* a=11=12=12; "Operands invalids pour une expression binaire */
  tete=parcours(0,&allouer);
    
    a=-1+2;
  /* ***&&tes=3; error GCC. error in any STRUCIT. && boolean */
    
  /* *&*p = -1+2; "Déréférencier une variable de type (struct *) donne une variable de type struct qui n'est pas autorisée en STRUCIT." */
 /*  a=1+2**p; "Déréférencier une variable de type (struct *) donne une variable struct qui n'est pas autorisée en STRUCIT." */
    
  parcours(tete,&desallouer);

  return 1;

}

