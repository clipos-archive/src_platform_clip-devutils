#!/bin/env python
# -*- coding: utf-8 -*-
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

# compile un paquetage gentoo vers un paquet debian 
# en se placant d'un sdk remis au propre par un gentoo-upkeep
# le succes ou echec de la compilation est mis dans un fichier de log
# les eventuelles sorties d'erreur sont placees dans un repertoire associe au paquetage par son nom
# le log et les eventuels fichiers d'erreur sont places dans un repertoire passe en argument au script.

import subprocess
import glob
import os
import datetime
import sys

def get_package_output_dir():
    lines = open("/etc/clip-build.conf",'r').readlines()
    for line in lines:
        if (not line.startswith("DEBS_BASE")):
            continue
        debs_dir=line.split("=")[1].strip("\n").strip("\"")
        debs_dir=os.path.dirname(debs_dir)+"/debs"
        return debs_dir

def is_there_deb_in_dir(directory):
    path=directory+"/*.deb"
    ls_debs=glob.glob(path)
    if (len(ls_debs)==0):
        return False
    return True

def log_compile_start(log_output_dir, clip_distribution, clip_cage, package_name):
    if (not os.path.exists(log_output_dir)):
        os.mkdir(log_output_dir)
    filepath = os.path.join(log_output_dir, "build.log")
    f = open(filepath, 'a+');
    f.write("debut compilation %s %s %s : %s\n" % (clip_distribution, clip_cage, package_name, datetime.datetime.now()))
    f.close()


# succeeded : boolean
def log_compile_ended(succeeded, log_output_dir, clip_distribution, clip_cage, package_name):
    if (not os.path.exists(log_output_dir)):
        os.mkdir(log_output_dir)
    filepath = os.path.join(log_output_dir, "build.log")
    f = open(filepath, 'a+');
    deb_result_dir = os.path.join(get_package_output_dir(),clip_cage,"*.deb")
    deb_result_list = glob.glob(deb_result_dir)
    if (succeeded):
        f.write("compilation reussie de : %s %s %s : %s\n" % (clip_distribution, clip_cage, package_name, datetime.datetime.now()))
        for deb in deb_result_list:
            f.write("paquetage resultat : %s\n" % deb)
        f.write("\n")
    else:
        f.write("erreur a la compilation de : %s %s %s : %s\n" % (clip_distribution, clip_cage, package_name, datetime.datetime.now()))
    f.close()


def make_package_id(clip_distribution, clip_cage, package_name):
    result = clip_distribution+"-"+clip_cage+"-"+package_name.replace("/","--")
    return result

# package_id = distribution-cage-package_name (en remplacement le "/" par "--"
def write_error_output(log_output_dir, package_id, new_gentoo_upkeep_result, depends_result, compile_result):
    error_dir=os.path.join(log_output_dir,"error_outputs-"+make_package_id(clip_distribution, clip_cage, package_name))
    if (not os.path.exists(log_output_dir)):
        os.mkdir(log_output_dir)
    if (not os.path.exists(error_dir)):
        os.mkdir(error_dir)
    f = open(os.path.join(error_dir,"upkeep_result.txt"),'a+')
    f.write(new_gentoo_upkeep_result)
    f.close()
    f = open(os.path.join(error_dir,"depends_result.txt"),'a+')
    f.write(depends_result)
    f.close()
    f = open(os.path.join(error_dir,"compile_result.txt"),'a+')
    f.write(compile_result)
    f.close()


"""
    clip_distribution = "clip-rm" ou "clip-gtw"
    clip_cage = "clip" ou "rm"
    debs_path = chemin vers le repertoire des debs compiles fourni par get_package_output_dir
    package_name = aaa/bbb
"""
def compile_one_package(clip_distribution, clip_cage, package_name, log_output_dir):
    print("*** compile %s-%s %s" % (clip_distribution, clip_cage, package_name))
    log_compile_start(log_output_dir, clip_distribution, clip_cage, package_name)

    arg0 = clip_distribution+"/"+clip_cage
    deb_directory = os.path.join(get_package_output_dir(), clip_cage)    
    step = 0

    try:
        new_gentoo_upkeep_result="gentoo upkeep not done"
        depends_result="dependency emerge not done"
        compile_result="compilation not done"
        clean_debs_directory(deb_directory)
        
        step = 1
        print("*** gentoo upkeeping")
        new_gentoo_upkeep_result = subprocess.check_output(["./compilation-test-gentoo-upkeep.sh"], stderr=subprocess.STDOUT)

        step = 2
        print("*** dependencies emerging")
        depends_result = subprocess.check_output(["clip-compile", arg0,"--depends", "-pkgn", package_name], stderr=subprocess.STDOUT)

        step = 3
        print("*** package compiling")
        compile_result = subprocess.check_output(["clip-compile", arg0, "-pkgn", package_name], stderr=subprocess.STDOUT)
        
    except subprocess.CalledProcessError as e :
        print("compilation failed")
        log_compile_ended(False,log_output_dir, clip_distribution, clip_cage, package_name)
        if (step == 1):
            new_gentoo_upkeep_result = e.output
        if (step == 2):
            depends_result = e.output
        if (step == 3):
            compile_result = e.output            
        write_error_output(log_output_dir, make_package_id(clip_distribution, clip_cage, package_name), new_gentoo_upkeep_result, depends_result, compile_result)
        return

    if (is_there_deb_in_dir(deb_directory)):
        print("compilation succeeded")
        log_compile_ended(True,log_output_dir, clip_distribution, clip_cage, package_name)
        return

    if (not is_there_deb_in_dir(deb_directory)):
        print("compilation failed")
        log_compile_ended(False,log_output_dir, clip_distribution, clip_cage, package_name)
        write_error_output(log_output_dir, make_package_id(clip_distribution, clip_cage, package_name), new_gentoo_upkeep_result, depends_result, compile_result)



def clean_debs_directory(directory):
    path=os.path.join(directory,"*.deb")
    ls_debs=glob.glob(path)
    for filedeb in ls_debs:
        command=["rm"]
        command.append(filedeb)
        subprocess.call(command)

def print_usage(exe):
    print "usage: %s distribution_clip cage_clip nom_du_paquetage repertoire_des_logs" % exe
    print "distribution_clip : clip-rm ou clip-gtw"
    print "cage_clip : rm ou clip"
    print "nom_du_paquetage : de la forme aaaa/bbbb"
    print "repertoire_des_logs : repertoire dans lequel ecrire les logs et stocker les fichiers d'erreur, sera cree si il n'existe pas"
    return


def test_package_id():
    print make_package_id("clip-rm","clip","x11-misc/xscreensaver")

def test_deb():
    directory = get_package_output_dir()
    print directory
    directory = directory + "/clip"
    print directory
    print is_there_deb_in_dir(directory)
    clean_debs_directory(directory)
    print is_there_deb_in_dir(directory)

def test_compile():
    compile_one_package("clip-rm","clip","x11-misc/xscreensaver", "/root/build/debs")
    # clean_debs_directory(directory)

if __name__ == "__main__" :
    if ((len(sys.argv) != 2) and (len(sys.argv) != 5)):
        print_usage(sys.argv[0])
        exit(1)

    if ((sys.argv[1] == "-h") or (sys.argv[1] == "--help")):
        print_usage(sys.argv[0])
        exit(1)

    clip_distribution = sys.argv[1]
    clip_cage = sys.argv[2]
    package_name = sys.argv[3]
    log_output_dir = sys.argv[4]

    if(not clip_distribution in ["clip-rm","clip-gtw"]):
        print "Erreur : clip_distribution = %s au lieu de clip-rm ou clip-gtw" % clip_distribution
        exit()

    if(not clip_cage in ["clip","rm"]):
        print "Erreur : clip_cage = %s au lieu de rm ou clip" % clip_cage
        exit()

    compile_one_package(clip_distribution, clip_cage, package_name, log_output_dir)


