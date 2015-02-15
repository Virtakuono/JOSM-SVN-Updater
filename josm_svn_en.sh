#!/bin/bash
#
#
# Copyright (C) [2009] [Max Andre - User Telegnom on Openstreetmap.org]
# 
#
# This program is free software; you can redistribute it and/or modify it under the terms of the GNU 
# General Public License as published by the Free Software Foundation; either version 3 of the License,
# or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
# without #even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
# See the GNU General Public License for more details.
#
# To get a copy of the GNU General Public License see <http://www.gnu.org/licenses/>.
#
#
###
# Set the following parameters as required:
###

# The directory in which the SVN will be checked out to 
source_dir=~/source/josm

# Maximal heap size for the Java VM (in MB)
maxmem="1240"

# Minimum heap size for the Java VM (in MB)
minmem="128"

# Activate 2D acceleration yes=true; no=false
acc2d="false"

###
# The actual script starts here, do not touch anything below
###

# Parse input parameters

set -- `getopt "hlorm:" "$@"`
while [ "$1" != "" ]; do
	case "$1" in
		-h) echo "Help: `basename $0` [-h] [-l] [-o] [-r] [-m] [Data]"; 
		#-n) echo "Repository wird nicht ausgecheckt. Lokale Version wird gestartet";
		    echo "-h : shows this help";	
		    echo "-l : prints out the local version number";
		    echo "-o : prints out the version number in the repository";
                    echo "-m : the amount of space allocated to the JOSM, this must exceed $minmem"; 
		    echo "-r : recompile the local source";
		    exit;;
		-l) shift; showloc=1;;
		-o) shift; showonline=1;;
		-m) shift; maxmem="$1";;
		-r) shift; build=1;;
		--) break;;
	esac
	shift
done

if [ "$showloc" == "1" ]; then
	if svn info $source_dir > /dev/null; then
                echo "Local version:"
		svn info $source_dir | grep Revision
	else
		echo "No local source found."
	fi
	exit 1
fi

if [ "$showonline" == "1" ]; then
	if ping josm.openstreetmap.de -c 2 > /dev/null; then
		echo "Current version in the repository:"
		svn info http://josm.openstreetmap.de/svn/trunk | grep Revision
	else
		echo "Repository is offline or cannot be reached"
	fi
	exit 1
fi

if [ "$build" == "1" ]; then
	if svn info $source_dir > /dev/null; then
		echo "Local source available, recompile."
	else
		echo "No local source, script will terminate."
		exit 1
	fi
else

	# test connection to SVN repository
	if ping josm.openstreetmap.de -c 2 > /dev/null; then
		version_svn=`svn info http://josm.openstreetmap.de/svn/trunk | grep Revision | awk '{print $2}'`
		echo "Repository can be reached."
	else

		# Set version number to minus one if repository is not reached
		version_svn=-1
	fi

	echo "Testing whether directory $source_dir exists..."

	# Test if the given directory exists
	if [ -d $source_dir ]; then
		echo Directory $source_dir exists

		# Prüfung ob REVISION-Datei aus dem SVN lokal vorhanden ist
		version_lokal=`svn info $source_dir | grep Revision | awk '{print $2}'`
		if [ -z $version_lokal ]; then
			echo "Local copy does not exists"

		        # If local version cannot be determined, set version to zero
			version_lokal=0
		fi
	else

		# falls das verzeichnis nicht gefunden wurde, wird es angelegt
		echo "Verzeichnis $source_dir wird angelegt"
		mkdir -p $source_dir

		# lokale Version wird auf 0 gesetzt
		version_lokal=0
	fi

	echo "local version: $version_lokal"
	echo "current version: $version_svn"

	# wenn keine lokale Version vorhanden ist und das SVN-Repository nicht erreichbar ist, wird das Script abgebrochen
	if [ $version_svn -eq -1 ]; then
		echo "Repository not in reach."
		if [ $version_lokal -eq 0 ]; then

		        # abbruch des scripts
			echo "Local version does not exist. Terminating."
			exit 1
		fi

	# wenn die lokale Version kleiner ist als die svn version wird das Repository ausgecheckt und kompiliert.
	elif [ $version_lokal -lt $version_svn ]; then
		echo "Local version has changed. The most recent version will be downloaded."

		# chencking out the repository
		svn co http://josm.openstreetmap.de/svn/trunk $source_dir
		echo "Compile the current version."

		# compiling the current JOSM version
		build=1;
	else
		if [ -f $source_dir/dist/josm-custom.jar ]; then
			echo "Local version is up-to-date."
		else
			echo "Cannot find Jarfile. Recompile with -r."
			exit 
		fi
	fi
fi
if [ "$build" == "1" ]; then
	if ant clean dist -f $source_dir/build.xml; then
		echo "Compilation terminating succesfully!"
	else
		echo "Error while compiling, terminating."
		exit 1
	fi
fi

version_aktuell=`svn info $source_dir | grep Revision | awk '{print $2}'`
echo "Start JOSM version $version_aktuell"

# Start JOSM with the parameters set above
java -Xms"$minmem"M -Xmx"$maxmem"M -Dsun.java2d.opengl=$acc2d -jar $source_dir/dist/josm-custom.jar $@ &

# Print out the PID of JOSM
echo "JOSM was started with PID $! "
exit
