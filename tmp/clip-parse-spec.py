#!/bin/env python
# -*- coding: utf-8 -*-
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

# Tony Cheneau <clipos@ssi.gouv.fr>

import xml.etree.ElementTree as ET
from collections import OrderedDict as odict

# test vectors
import sys

test_env = "DEB_NAME_SUFFIX=-audit,CLIP_VROOTS=/mounts/audit_root,VERIEXEC_CTX=503"
test_env2 = "CLIP_VROOTS=/mounts/audit_root,VERIEXEC_CTX=503"

def get_pkgname(tree):
    pass

def parse_env_string(env_string):
    """parse env tag in order to extract the DEB_SUFFIX"""
    return "".join([s.replace("DEB_NAME_SUFFIX=","").strip() for s in env_string.split(",") if "DEB_NAME_SUFFIX" in s])

def parse_pkg(elt, env):
    return []
def parse_config(elt, env):
    return []

def parse_tree(tree, localenv=None):
    elts = [ elt for elt in tree.getchildren() if elt.tag in [ "config", "pkg", "pkgnames", "env" ] ]
    if localenv:
        env = localenv
    else:
        env = ""
    pkgs = []
    for elt in elts:
        if elt.tag  == "env":
            if env != env:
                print "env has been overwritten"
            env = parse_env_string(elt.text)
    for elt in elts:
        if elt.tag == "config" or elt.tag == "pkg":
            pkgs += parse_tree(elt, env)
        elif elt.tag == "pkgnames":
            for pkg in elt.text.split():
                debname = pkg.split("/")[1]
                gentooname = pkg
                pkgs += [ (gentooname, debname + env if env else debname) ]

    return pkgs




if __name__ == "__main__":
    if len(sys.argv) != 2:
        print "usage: %s filename" % sys.argv[0]

    tree = ET.parse(sys.argv[1])
    #print "\n".join([ gentoo + "," + debian for (gentoo, debian)  in parse_tree(tree.getroot())])
    #we remove the slot information
    pkgs=list(odict.fromkeys(([gentoo.split(":")[0] + "," + debian.split(":")[0] for (gentoo, debian)  in parse_tree(tree.getroot())])))
    print "\n".join(pkgs)


