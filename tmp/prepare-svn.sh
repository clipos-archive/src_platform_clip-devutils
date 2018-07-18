#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

set -u

print_exit() {
    echo "a command exited with a non-zero status"
    exit 1
}
trap 'print_exit' ERR

declare -a SVN_DIRS
# default SVN directories for clip-rm
SVN_DIRS=("clip" "rm" "clip-hermes" "rm-hermes")
if [[ $# == 1 ]]; then 
    case $1 in
        "gtw")
            SVN_DIRS=("clip" "clip-hermes")
            ;;
        *)
            echo "usage: $0 [gtw]"
            exit 1
            ;;
    esac
fi

USE="clip-hermes"
SUFFIXDIR="-hermes"

# make sure we have the latest version
echo "checking for newer packages version"
svn up


# sign up everything
echo "signing up new packages"
for dir in ${SVN_DIRS[@]}; do
    pushd $dir > /dev/null
    clip-checksign -a|xargs clip-sign -a
    popd > /dev/null
done


# copy files without the $USE use-flag to the proper directory
echo "moving files with the $USE use-flag to the proper directory"
for dir in ${SVN_DIRS[@]}; do
    echo "checking dir $dir"
    if echo $dir|grep -q -e "${SUFFIXDIR}\$"; then
        for pkgpath in ${dir}/*.deb; do
                if ! clip-dpkg hasuse $USE $pkgpath; then
                        # make sure we don't clobber existing files
			targetdir=$(dirname $pkgpath|sed s/$SUFFIXDIR\$//)
                        pkgname=$(basename $pkgpath)
                        # don't do anything if the file has already been commited to the SVN
                        ret=0
                        svn status "${pkgpath}"|grep -q -E '^?|^M' || ret=1
                        if [[ -f "$targetdir/$pkgname" && $ret == 0 ]]; then
                            echo "$(basename $pkgpath) already exists in ${targetdir}, should we remove it (y/n)?"
                            read answer
                            case ${answer} in
                                    "y"|"yes"|"o"|"oui")
                                            svn rm --force ${pkgpath}
                                            ;;
                                    "n"|"no"|"non"|*)
                                            echo "preserving the file for now"
                                            ;;
                            esac
                        else
                            # check if the file is already revisioned
                            ret=0
                            svn info "${pkgpath}" 1>/dev/null 2>&1 && ret=1
                            if [[ $ret == 1 ]]; then
                                echo "svn move"
                                if [ ! -f "${targetdir}/${pkgname}" ]; then
                                    svn mv "${pkgpath}" "${targetdir}"
                                fi
                            else
                                echo "move"
                                mv -n "${pkgpath}" "${targetdir}"
                            fi
                        fi
                fi
        done
    fi
done

echo "pruning old packages"
for dir in ${SVN_DIRS[@]}; do
    pushd ${dir} > /dev/null
    clip-prunepkgs
    popd > /dev/null
done


# adding and removing files from the svn
echo "adding/removing files from the SVN repository"
add_files=$(svn status|grep '^?'|awk '{print $2}')
if [ ! -z "${add_files}" ]; then svn add ${add_files}; fi
rm_files=$(svn status|grep '^!'|awk '{print $2}')
if [ ! -z "${rm_files}" ]; then svn rm ${rm_files}; fi

for pkg in $(svn status|grep '^M'|awk '{print $2}'); do
	echo "$pkg already exists, should be revert to the committed version (y/n)?"
	read answer
	case ${answer} in
		"y"|"yes"|"o"|"oui")
			svn revert $pkg
			;;
		"n"|"no"|"non"|*)
			echo "preserving the file for now"
			;;
	esac
done


echo "please double check your local changes before commiting any packages"
