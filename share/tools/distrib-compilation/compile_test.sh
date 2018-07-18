#!/bin/sh
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.
#
# Ce script teste la recompilation de chacun des paquetages du spec file
# correspondant à la distribution et à la cage passés en argument
# distribution (clip-rm, clip-gtw) et cage (clip, rm).
# Les résultats sont par défauts mis dans un répertoire créé et nommé 
# "/root/build/log-compile-<date>"
# Il est possible de stopper la recompilation par un touch /home/stop.
# Et il est possible de relancer une tache de compilation d'un spec file interrompue
# en passant via l'option -l le nom du répertoire contenant les premiers résultats
# obtenus.

function show_help(){
	echo "help :"
	echo "-d distribution(clip-rm,clip-gtw,clip-bare) -c cage(clip,rm) -l log_directory(facultatif)"
	echo "si un log_directory est fourni alors la compilation n'est effectuée que pour les paquetages qui n'apparaissent pas dans le journal"
	echo "pour arreter le script faire un touch /home/stop et attendre la fin des actions en cours"
}

echo "pour arreter le script faire un touch /home/stop et attendre la fin des actions en cours"

OPTIND=1

distribution=""
cage=""
log_directory="/root/build/log-compile-"$(date +"%m-%d_%Hh%Mm%Ss")

while getopts "d:c:l:h?" opt; do
	case "${opt}" in
	h|\?)
	   show_help
	   exit 0
	   ;;
	d) distribution=$OPTARG
	   ;;
	c) cage=$OPTARG
	   ;;
	l) log_directory=$OPTARG
	   ;;
	esac
done

shift $((OPTIND-1))

packages_list=$(./list_packages_in_spec.py "/opt/clip-int/specs/${distribution}/${cage}.spec.xml")

echo ${package_list}

for package in ${packages_list};
	do
	  compile="0"

	  if [ -e "/home/stop" ]; then
	        rm "/home/stop"
	  	exit 0
	  fi

	  if [ -e "${log_directory}/build.log" ]; then
            grep --silent ${package} "${log_directory}/build.log"	   
  	    if [ $? -ne 0 ]; then
	      compile="1"
	    fi
	  else
	    compile="1"
	  fi

	  if [ ${compile} = "1" ]; then	  
            ./compile_one_package.py "${distribution}" "${cage}" "${package}" "${log_directory}"
	  fi
	done
