#!/bin/bash

mkdir out

./thumbs.sh make
./thumbs.sh check
objdump -f build/libtiff/*.so | grep ^architecture
ldd build/libtiff/*.so
tar -zcf out/libtiff-x64.tar.gz --transform 's/.*\///' $(./thumbs.sh list)
./thumbs.sh clean

sudo apt-get -y update > /dev/null
sudo apt-get -y install gcc-multilib > /dev/null

export tbs_arch=x86
./thumbs.sh make
./thumbs.sh check
objdump -f build/libtiff/*.so | grep ^architecture
ldd build/libtiff/*.so
tar -zcf out/libtiff-x86.tar.gz --transform 's/.*\///' $(./thumbs.sh list)
./thumbs.sh clean
