## Étapes d’execution des programmes:
- Changer le nom du fichier Makefile_OS en Makefile (selon le systeme 
d’exploatation utilisé).
- Ouvrir le dossier contenant les programmes du projet dans la ligne de 
commande.
- Executer la commande make (L’executable s’appele 'ex' et doit être ensuite 
utilisé pour la commande de generation du code.
- Executez ./ex <fichier_entré> <fichier_sortie>
- Si le message "-->Compilation avec succes" est affiché, ouvrir le fichier <fichier_sortie>
  Sinon, soit il y a une erreur syntaxique dans le programme (l'erreur va être affichee), soit le parseur ne lis pas d'un fichier mais dans la ligne de commande (il arrive parfois sur Fedora...) ou des erreurs de make*, soit il y à un message de control (pour essayer de ne pas arriver à une erreur de segmentation) qui s'affiche à cause des erreurs eventuels dans les fichiers gen_code.c ou structfe.y (exemple:  printf ("\nIn ProcessFuncCall. Stack already empty!"); exit(0);). 

## Configuration requise (Systemes d’exploitation):
- UNIX (utiliser le Makefile 'Makefile_unix')
- Linux (utiliser le Makefile 'Makefile_linux')


*Exemple: File 'structfe.tab.h' has modification time 0.89 s in the future
gcc y.tab.c lex.yy.c -o ex -lfl
make: warning:  Clock skew detected.  Your build may be incomplete.


!! Selon le systeme utilise, l'inclusion de la biblioteque y.tab.h en ANSI-C.l et gen_code.c doit s'ecrire comme structfe.tab.h en Fedora.