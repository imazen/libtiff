#!/bin/bash

# THe Ultimate Make Bash Script
# Used to wrap build scripts for easy dep
# handling and multiplatform support


# Basic usage on *nix:
# export tbs_arch=x86
# ./thumbs.sh make


# On Win (msvc 2015):
# C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall x86_amd64
# SET tbs_tools=msvc14
# thumbs make

# On Win (mingw32):
# SET path=C:\mingw32\bin;%path%
# SET tbs_tools=mingw
# SET tbs_arch=x86
# thumbs make


# Global settings are stored in env vars
# Should be inherited

[ $tbs_conf ]           || export tbs_conf=Release
[ $tbs_arch ]           || export tbs_arch=x64
[ $tbs_tools ]          || export tbs_tools=gnu
[ $tbs_static_runtime ] || export tbs_static_runtime=0


# tbsd_* contains dep related settings
# tbsd_[name]_* contains settings specific to the dep
# name should match the repo name

# deps contains a map of what should be built/used
# keep the keys in sync ... no assoc arrays on msys :/
# targ contains a target for each dep (default=empty str)
# post is executed after each thumbs dep build
# ^ used for copying/renaming any libs you need - uses eval

zname=zlib.lib
jname=jpeg.lib

if [ $tbs_tools = gnu -o $tbs_tools = mingw ]
then
  zname=libz.a
  jname=libjpeg.a
fi

deps=()
targ=()
post=()

[ "$tbsd_zlib_repo" ]          || export tbsd_zlib_repo="git clone https://github.com/imazen/zlib_shallow ; cd zlib_shallow && git reset --hard b4d48d0d43f14c018bebc32131cb705ee108ae85"
[ "$tbsd_libjpeg_turbo_repo" ] || export tbsd_libjpeg_turbo_repo="git clone https://github.com/imazen/libjpegturbo libjpeg_turbo ; cd libjpeg_turbo && git reset --hard 2ade31732a9f6eaf113beb48aba55aed1779557a"

if [[ "$OSTYPE" == "darwin"* ]]; then cp="rsync"
else cp="cp"
fi

deps+=(zlib); targ+=(zlibstatic)
post+=("$cp -u \$(./thumbs.sh list_slib) ../../deps/$zname")

deps+=(libjpeg_turbo); targ+=(jpeg-static)
post+=("for lib in \$(./thumbs.sh list_slib); do [ -f \$lib ] && $cp -u \$lib ../../deps/$jname; done")

# -----------
# dep processor

process_deps()
{
  mkdir _build_deps
  mkdir deps
  cd _build_deps

  for key in "${!deps[@]}"
  do
    dep=${deps[$key]}
    i_dep_repo="tbsd_${dep}_repo"
    i_dep_incdir="tbsd_${dep}_incdir"
    i_dep_libdir="tbsd_${dep}_libdir"
    i_dep_built="tbsd_${dep}_built"
    
    [ ${!i_dep_built} ] || export "${i_dep_built}=0"
    
    if [ ${!i_dep_built} -eq 0 ]
    then
      eval ${!i_dep_repo} || exit 1
      ./thumbs.sh make ${targ[$key]} || exit 1
      
      # copy any includes and do poststep
      $cp -u $(./thumbs.sh list_inc) ../../deps
      eval ${post[$key]}
      
      # look in both local and parent dep dirs
      export "${i_dep_incdir}=../../deps;deps"
      export "${i_dep_libdir}=../../deps;deps"
      export "${i_dep_built}=1"
      
      cd ..
    fi
  done
  
  cd ..
}

# -----------
# constructs dep dirs for cmake

postproc_deps()
{
  cm_inc=
  cm_lib=
  
  for dep in "${deps[@]}"
  do
    i_dep_incdir="tbsd_${dep}_incdir"
    i_dep_libdir="tbsd_${dep}_libdir"
    
    cm_inc="${!i_dep_incdir};$cm_inc"
    cm_lib="${!i_dep_libdir};$cm_lib"
  done
  
  cm_args+=(-DCMAKE_LIBRARY_PATH=$cm_lib)
  cm_args+=(-DCMAKE_INCLUDE_PATH=$cm_inc)
}

# -----------

if [ $# -lt 1 ]
then
  echo ""
  echo " Usage : ./thumbs.sh [command]"
  echo ""
  echo " Commands:"
  echo "   make [target]   - builds everything"
  echo "   check           - runs tests"
  echo "   clean           - removes build files"
  echo "   list            - echo paths to any interesting files"
  echo "                     space separated; relative"
  echo "   list_bin        - echo binary paths"
  echo "   list_inc        - echo lib include files"
  echo "   list_slib       - echo static lib path"
  echo "   list_dlib       - echo dynamic lib path"
  echo ""
  exit
fi

# -----------

upper()
{
  echo $1 | tr [:lower:] [:upper:]
}

# Local settings

l_inc="./_build/libtiff/tif_config.h ./_build/libtiff/tiffconf.h ./libtiff/tiffio.h ./libtiff/tiffvers.h ./libtiff/tiff.h ./libtiff/tiffiop.h ./libtiff/tif_dir.h"
l_slib=
l_dlib=
l_bin=
list=

make=
c_flags=
cm_tools=
cm_args=(-DCMAKE_BUILD_TYPE=$tbs_conf)
cm_args+=(-Dlzma=OFF)

target=
[ $2 ] && target=$2

# -----------

case "$tbs_tools" in
msvc14)
  # d suffix for debug builds
  csx=
  [ "$tbs_conf" = "Debug" ] && csx=d
  
  cm_tools="Visual Studio 14"
  [ "$target" = "" ] && mstrg="TIFF.sln" || mstrg="$target.vcxproj"
  make="msbuild.exe $mstrg //p:Configuration=$tbs_conf //v:m"
  l_slib="./_build/libtiff/$tbs_conf/tiff_static$csx.lib"
  l_dlib="./_build/libtiff/$tbs_conf/tiff$csx.lib"
  l_bin="./_build/libtiff/$tbs_conf/tiff$csx.dll"
  list="$l_bin $l_slib $l_dlib $l_inc" ;;
gnu)
  cm_tools="Unix Makefiles"
  c_flags+="-fPIC"
  make="make $target"
  l_slib="./_build/libtiff/libtiff.a"
  l_dlib="./_build/libtiff/libtiff.so.4.0.3"
  l_bin="$l_dlib"
  list="$l_slib $l_dlib $l_inc" ;;
mingw)
  cm_tools="MinGW Makefiles"
  make="mingw32-make $target"
  
  # allow sh in path; some old cmake/mingw bug?
  cm_args+=(-DCMAKE_SH=)
  
  l_slib="./_build/libtiff/libtiff.a"
  l_dlib="./_build/libtiff/libtiff.dll.a"
  l_bin="./_build/libtiff/libtiff.dll"
  list="$l_bin $l_slib $l_dlib $l_inc" ;;

*) echo "Tool config not found for $tbs_tools"
   exit 1 ;;
esac

# -----------

case "$tbs_arch" in
x64)
  [ $tbs_tools = msvc14 ] && cm_tools="$cm_tools Win64"
  [ $tbs_tools = gnu -o $tbs_tools = mingw ] && c_flags+=" -m64" ;;
x86)
  [ $tbs_tools = gnu -o $tbs_tools = mingw ] && c_flags+=" -m32" ;;

*) echo "Arch config not found for $tbs_arch"
   exit 1 ;;
esac

# -----------

if [ $tbs_static_runtime -gt 0 ]
then
  [ $tbs_tools = msvc14 ] && c_flags+=" /MT"
  [ $tbs_tools = gnu ] && cm_args+=(-DCMAKE_SHARED_LINKER_FLAGS="-static-libgcc -static-libstdc++")
  [ $tbs_tools = mingw ] && cm_args+=(-DCMAKE_SHARED_LINKER_FLAGS="-static")
fi

# -----------

case "$1" in
make)
  process_deps
  postproc_deps
  
  mkdir _build
  cd _build
  
  fsx=
  [ $tbs_tools = gnu ] || fsx=_$(upper $tbs_conf)
  
  cm_args+=(-DCMAKE_C_FLAGS$fsx="$c_flags")
  cm_args+=(-DCMAKE_CXX_FLAGS$fsx="$c_flags")
  echo Running: cmake -G "$cm_tools" "${cm_args[@]}"
  cmake -G "$cm_tools" "${cm_args[@]}" .. || exit 1
  $make || exit 1
  
  cd .. ;;
  
check)
  cd _build
  ctest -C $tbs_conf . || exit 1
  cd .. ;;
  
clean)
  rm -rf deps
  rm -rf _build_deps
  rm -rf _build ;;

list) echo $list ;;
list_bin) echo $l_bin ;;
list_inc) echo $l_inc ;;
list_slib) echo $l_slib ;;
list_dlib) echo $l_dlib ;;

*) echo "Unknown command $1"
   exit 1 ;;
esac
