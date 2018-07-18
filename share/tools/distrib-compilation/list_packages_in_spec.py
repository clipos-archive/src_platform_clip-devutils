#!/bin/env python
# -*- coding: utf-8 -*-
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

import sys
import os.path
import xml.etree.ElementTree as ET

"""
    Prend un spec file en entree et liste l'ensemble des packages qu'il reference, en prenant
    en compte les autres spec file qu'il inclut.
    NB : dans les specs file les #define, #if, #endif, #else sont supprimes sans etre evalues
    NB : l'outil considere qu'il y a un nom de package par ligne dans les balises packagenames
    NB : l'outil considere que le seul caractere non alphanumerique present dans un nom de package est le "-"
"""

def read_file (filepath):
    myfile=open(filepath,'r')
    data=myfile.readlines()
    return data


# cette fonction extrait le nom du fichier de la directive "#include ..."
def get_filepath_from_include_line(line):
    stripped=line.strip()
    if (not stripped.startswith("#include")):
        return ""
    path=stripped[8:len(stripped)]
    path=path.strip()
    path=path.strip("\"")
    return path

# cette fonction retourne True si une ligne d'un fichier ne doit pas etre ajoutee
# au tableau de ligne genere par read_files_in_array
def remove_line(line):
    stripped=line.strip()
    if (stripped.startswith("#define")):
        return True
    if (stripped.startswith("#if")):
        return True
    if (stripped.startswith("#endif")):
        return True
    if (stripped.startswith("#else")):
        return True    
    return False

# cette fonction complete le result_array par les lignes du fichier
# filepath, si ce fichier en inclut d'autres leurs lignes sont aussi ajoutees au tableau
def read_files_in_array(filepath, result_array):
    lines=read_file(filepath)
    dirpath=os.path.dirname(filepath)
    for line in lines:
        include_file_path=get_filepath_from_include_line(line)
        if (remove_line(line)):
            continue
        if (include_file_path == ""):
            result_array.append(line)
            continue
        read_files_in_array(dirpath+"/"+include_file_path,result_array)
    return 


# Cette fonction extrait le nom de package de la ligne qui lui est passee
# Si il n'y a pas de nom de package sur la ligne elle retourne ""
#    NB : elle considere qu'il y a un nom de package par ligne dans les balises packagenames
#    NB : elle considere que le seul caractere non alphanumerique present dans un nom de package est le "-"    
def get_packagename_from_string(line):
    result = line.strip()
    splitted_line = result.split("/")
    length = len(splitted_line)
    if (length != 2):
        return ""
    left_without_dash = splitted_line[0].replace("-","z")
    right_without_dash = splitted_line[1].replace("-","z")
    if ((not left_without_dash.isalnum()) or (not right_without_dash.isalnum())):
        return ""
    return result


def print_package_list(specfilepath):    
    lines_list = []
    read_files_in_array(specfilepath, lines_list)
    
    # concatene toutes les lignes de lines_list
    specs_string="".join(lines_list)
    
    # parse la chaine obtenue
    root = ET.fromstring(specs_string)
    
    # fait une requete xpath pour recuperer toutes les balises pkgnames
    pkgnames_list = root.findall(".//pkgnames")
    for element in pkgnames_list :
        # recupere le texte de chaque balise
        current_text=element.text
        current_list_of_lines=current_text.split("\n")
        for line in current_list_of_lines:
            # extrait le nom du package de chaque ligne de texte de la balise pkgnames
            package = get_packagename_from_string(line)
            if (package == ""):
                continue
            print package    

def print_usage(exe):
    print "usage: %s filename" % exe
    print "extrait l'ensemble des paquetages cites dans un spec file en prenant en compte les spec files inclus"
    print "par contre l'outil se contente de supprimer les #if #endif #define #else sans les traiter"
    return


def test():    
    print_package_list("./specs/clip-rm/clip.spec.xml")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print_usage(sys.argv[0])
        exit()
    
    if ((sys.argv[1] == "-h") or (sys.argv[1] == "--help")):
        print_usage(sys.argv[0])
        exit()
    
    print_package_list(sys.argv[1])
 

