#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.
 
# Tony Cheneau <clipos@ssi.gouv.fr>
# simple script for compiling incremental CLIP builds

set -e
set -u

# TODO:
# - test the script when we have multiple use-flag we want to check
# - test the script when we have multiple suffixes we want to check
# - test the script when there is no use-flag and suffix provided



# workaround: bash can't declare global associative arrays within a function
declare -A CLIP_CONFS=( ['overwrite']="me" )

setvar() {
    # required use flags
    readonly USE_FLAGS=${USE_FLAGS:-"clip-hermes"}
    readonly CLIP_SPEC_DEFINES=${CLIP_SPEC_DEFINES:-"WITH_HERMES"}
    readonly SUFFIX=${SUFFIX:-"-hermes"}

    readonly DEBUG=${DEBUG:-"no"}
    readonly SVN_DIR=${SVN_DIR:-"/opt/build/svn"}
    readonly SCRIPT_DIR=${SCRIPT_DIR:-"/root/scripts"}
    readonly OUT_DIR=${OUTDIR:-"/tmp"}
    readonly CLIPDIR=${CLIPDIR:-"/opt/clip-int"}
    readonly SPECIES=${SPECIES:-"clip-rm"}
    readonly SPEC="specs/$SPECIES"
    readonly ARCH=${ARCH:-"i386"}
    case ${SPECIES} in
        clip-rm)
            CLIP_CONFS=( ['clip-core-conf']="clip" ['clip-apps-conf']="clip" ['rm-core-conf']="rm" ['rm-apps-conf']="rm" )
            ;;
        clip-gtw)
            CLIP_CONFS=( ['clip-core-conf']="clip" ['clip-apps-conf']="clip" )
            ;;
        *)
            echo "clip species $SPECIES not supported (yet)"
            exit 1
            ;;
    esac
}

# commands that should be executed before actually running the script (mostly workarounds)
pre_cmd() {
    # work around for the buggy default caching behavior of aufs
    for conf in "${!CLIP_CONFS[@]}"; do
        dir="${SVN_DIR}/${CLIP_CONFS[$conf]}"
        if [ -d ${dir} ]; then
            echo "remounting $dir"
            mount -o remount $dir
        fi
    done
}

compile_conf() {
        # TODO: check return code
	clip-compile ${SPECIES}/$1 -pkgn $2 2>/dev/null|grep "Built debian package"|sed 's/.*\///g'
}

get_deps() {
	alldeps=$(dpkg-deb -W --showformat="\${$2}\n"  $1 | tr "," "\n"| tr "=" "_"| sed -e 's/[ \t()]*//g')
	files=""

	for pkg in $alldeps; do
		files="${files}${pkg}_${ARCH}.deb "
	done
	echo ${files}
}

get_gentoo_name() {
	echo $(dpkg-deb -W --showformat='${Section}/${Package}'  $1)

}

debpkg_to_gentoo () {
	if [ $# != 2 ]; then
		echo "missing argument"
	fi
	grep -E ",${2}\$" ${1}|cut -d "," -f 1
}

build_command_from_list () {
    for pkg in $*; do
        prefix=$(echo ${pkg}|cut -d "," -f 2)
        pkg=$(echo ${pkg}|cut -d "," -f 1)
        echo "clip-compile $SPECIES/${prefix} --depends -pkgn ${pkg}"
        echo "clip-compile $SPECIES/${prefix} -pkgn ${pkg}"
    done
}

debug_print () {
        if [ ${DEBUG:-"no"} == "yes" ]; then
                echo $*
        fi
}

pre_cmd_exec=0

while getopts "b:dhps:" optchar ; do
    case "${optchar}" in
        b)
            SVN_DIR=${OPTARG}
            ;;
        d)
            DEBUG="yes"
            ;;
        h)
            # TODO
            echo "TODO: print help"
            ;;
        p)
            echo "will execute pre-commands before running script"
            pre_cmd_exec=1
            ;;
        s)
            echo "setting species to ${OPTARG}"
            SPECIES=${OPTARG}
            ;;
        *)
            echo "${optchar} is not a valid argument"
            exit 1
            ;;
    esac
done

debug_print "command line arguments have been parsed"

setvar

if [ ${pre_cmd_exec} -eq 1 ]; then 
    pre_cmd
fi

# packages that needs to be build from a debian name
tobuild_from_deb=""
# packages that needs to be build from a gentoo name
tobuild_from_gentoo=""

if [ -n $USE_FLAGS ]; then
    pkgs_with_use_flags=$(equery hasuse -I -p -o ${USE_FLAGS} -F \$category/\$name 2>/dev/null)
else
    pkgs_with_use_flags=""
fi

for clipconf in "${!CLIP_CONFS[@]}"; do
	conf_pkg="clip-conf/${clipconf}"
	prefix=${CLIP_CONFS[$clipconf]}
        spec=$CLIPDIR/$SPEC/${prefix}.spec.xml
	echo "building packages list for the following config: " $conf_pkg

	# first create a map file between debian names and gentoo names
	tempdir=$(mktemp -d)
	tmpspec=${tempdir}/spec.xml 
	mapfile=${tempdir}/deb_map.txt
	EXTRAARGS=""
	if [ -n $CLIP_SPEC_DEFINES ]; then
		EXTRAARGS="${EXTRAARGS} -d ${CLIP_SPEC_DEFINES}"
	fi

	if [ "$ARCH" == "i386" ]; then
		EXTRAARGS="${EXTRAARGS} -d CLIP_ARCH_x86"
	fi

	clip-specpp -i ${spec} -o ${tmpspec} ${EXTRAARGS}
	${SCRIPT_DIR}/clip-parse-spec.py ${tmpspec} > ${mapfile}
	
	# second step: identify configuration packages
	conf_pkgs=$(compile_conf ${prefix} "${conf_pkg}")
	
	# third step: list dependencies (regular + optional packages)
	deps=""
        for suffix in ${SUFFIX}; do
            for pkg in ${conf_pkgs}; do 
                    deps="$deps $(get_deps $SVN_DIR/$prefix$suffix/$pkg Depends)"
                    opt_deps=$(get_deps $SVN_DIR/$prefix$suffix/$pkg Suggests)
                    if [ -n "${opt_deps}" ]; then deps="${deps} ${opt_deps}"; fi
            done
        done

	# filter out packages that appear more than once
	deps=$(echo ${deps}| xargs -n1|sort -u|xargs)

	# packages that needs to be checked for a useflag
	tocheck=""
	for dep in  ${deps}; do
            for suffix in ${SUFFIX} ""; do # TODO: finish this up
		pkg_file=${SVN_DIR}/${prefix}${suffix}/${dep}
		if [[ ! -f  "${pkg_file}" && ${suffix} != "" ]]; then # file is missing from the suffixed build directory, trying the other ones
                    continue; 
                else
                    if [[ ! -f  "${pkg_file}" ]]; then
                            debug_print "${dep} is missing from all build directories"
                            # extract debian name
                            dep=$(echo $dep|cut -d "_" -f 1)
                            # map to gentoo name and save
                            tobuild_from_deb="${tobuild_from_deb} $(debpkg_to_gentoo ${mapfile} ${dep}),${prefix}"
                    else
                            # check if a specific use flag is absent
                            ret=0
                            $(clip-dpkg hasuse ${USE_FLAGS} ${pkg_file}) || ret=1
                            if [ $ret == 1 ]; then
                                    tocheck="${tocheck} $(get_gentoo_name ${pkg_file})"
                            fi
                            break
                    fi
                fi 
            done
	done
	
	
        debug_print "Checking ${USE_FLAGS} use flag within the list of already built packages"
	for pkg in ${tocheck}; do
		ret=0
# equery -q uses ${pkg} 2>/dev/null |grep -q -e "^.${USE_FLAGS}\$" > /dev/null || ret=1
                echo "${pkgs_with_use_flags}"|grep -x -q ${pkg} || ret=1
	
		if [ $ret == 0 ]; then
			debug_print "* $pkg has use flag ${USE_FLAGS} but it is missing from the package in the repository"
			tobuild_from_gentoo="${tobuild_from_gentoo} ${pkg},${prefix}"
		fi
	done 
	
	if [ -d $tempdir ]; then rm -fr $tempdir; fi
done

outfile=$OUT_DIR/"build_update-${SPECIES}-$(date +%Y-%m-%d-%H%M%S).sh"

cat << EOF > ${outfile}
#!/bin/sh

set -u
set -e

#command that will build an incremental ${SPECIES} update

EOF
	
debug_print "list of packages that should have the ${USE_FLAGS} but don't have it"
build_command_from_list ${tobuild_from_gentoo}  >> ${outfile}

debug_print "list of packages that are missing from the deb conf"
build_command_from_list ${tobuild_from_deb} >> ${outfile}

echo "incremental update script is now available at ${outfile}"

echo "press enter to execute the script or hit ctrl+c (and execute it at a later time)"
read ignoreme
sh "${outfile}"
