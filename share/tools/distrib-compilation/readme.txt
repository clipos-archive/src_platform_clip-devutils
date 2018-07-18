
Le script compile_test.sh compile un par un les paquetages de la distribution
clip qu'on lui passe en argument :
-d le nom de la distribution (clip-rm, clip-gtw)
-c le nom de la cage (clip,rm)

Il se base sur les paquetages présents dans le spec file correspondant à la
distribution et à la cage.

Il est possible de donner aussi le répertoire dans lequel on souhaite que les
logs soient écrits :
-l nom du répertoire
Si le répertoire n'existe pas il est créé.
Si le répertoire existe et qu'il contient déjà des logs de compilation alors
le script ne recompile pas les paquetages déjà présents dans les logs.

Si on ne passe pas de répertoire de log au script, il crée un répertoire par
défaut dont le nom est le suivant :
"/root/build/log-compile-"$(date +"%m-%d_%Hh%Mm%Ss")

NB : pour arrêter le script il faut créer un fichier nommé "stop" dans le répertoire home (par exemple par "touch /home/stop") et attendre la fin des taches sur le paquetage en cours de compilation.
