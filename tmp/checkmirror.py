#!/usr/bin/env python
# -*- coding: utf-8 -*-
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

import os
import sys
import gzip
import debian.deb822
import hashlib


def check_packages(filename):
    status = 0
    if filename.endswith(".gz"):
        f = gzip.open(filename)
    else:
        f = file(filename)
    basedir = os.path.dirname(filename)

    for src in debian.deb822.Sources.iter_paragraphs(f):
        filepath = os.path.join(basedir, "..", "..", "..", "..", src['Filename'])
        try:
            with open(filepath, 'r') as pkg:
                text = pkg.read()
                if hashlib.md5(text).hexdigest() != src['MD5sum'] or \
                   hashlib.sha1(text).hexdigest() != src['SHA1'] or \
                   hashlib.sha256(text).hexdigest() != src['SHA256']:
                    print "file %s is corrupted" % src['Filename']
                    status |= 1

        except IOError:
            print "could not open %s" % src['Filename']
            status |= 2
    return status

if __name__ == "__main__":
    status = check_packages(sys.argv[1])
    sys.exit(status)
