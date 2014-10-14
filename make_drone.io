#!/bin/bash
# set $1 to 1 to force an x86 build
# set $2 to 1 to rebuild and statically link any deps
# ex: _build 0 1 would build an x64 static (on x64 machines)

_build()
{
  echo "*building* (x86=${1-0}; static=${2-0})"
  
  pack="*.a *.so*"
  cmargs="-DCMAKE_C_FLAGS=-fPIC"
  [ ${1-0} -gt 0 ] && cmargs="$cmargs -DCMAKE_CXX_FLAGS=-m32 -DCMAKE_C_FLAGS=-m32" || cmargs="$cmargs -D64BIT=1"
  
  if [ ${2-0} -gt 0 ]; then
    mkdir deps
    
    git clone https://github.com/imazen/zlib
    cd zlib
    cmake -G "Unix Makefiles" $cmargs
    make zlib_static
    cp libz.a ../deps
    cp *.h ../deps
    cd ..
    
    git clone https://github.com/imazen/libjpeg-turbo
    cd libjpeg-turbo
    cmake -G "Unix Makefiles" $cmargs
    make jpeg_static
    cp libjpeg.a ../deps
    cp *.h ../deps
    cd ..
    
    cmargs="$cmargs -DCMAKE_PREFIX_PATH=$(pwd)/deps"
    pack="$pack ../deps/*.a"
  fi
  
  cmake -G "Unix Makefiles" $cmargs
  make
  ctest .
  cd libtiff
  objdump -f *.so | grep ^architecture
  ldd *.so
  find . -maxdepth 1 -type l -exec rm -f {} \;
  tar -zcf ../binaries.tar.gz $pack
  cd ..
}


_clean()
{
  echo "*cleaning*"
  git clean -ffde /out > /dev/null
  git reset --hard > /dev/null
}

mkdir out
sudo apt-get install nasm

_build
mv binaries.tar.gz out/libtiff-x64.tar.gz
_clean

_build 0 1
mv binaries.tar.gz out/libtiff-static-x64.tar.gz
_clean

sudo apt-get -y update > /dev/null
sudo apt-get -y install gcc-multilib > /dev/null
sudo apt-get -y install g++-multilib > /dev/null
sudo ldconfig -n /lib/i386-linux-gnu/
for f in $(find /lib/i386-linux-gnu/*.so.*); do sudo ln -s -f $f ${f%%.*}.so; done > /dev/null
sudo cp /usr/include/x86_64-linux-gnu/jconfig.h /usr/include/jconfig.h

_build 1
mv binaries.tar.gz out/libtiff-x86.tar.gz
_clean

_build 1 1
mv binaries.tar.gz out/libtiff-static-x86.tar.gz
_clean
