FROM ubuntu:12.04


RUN apt-get update -qq
RUN apt-get install -y build-essential nasm cmake python-software-properties
RUN add-apt-repository --yes ppa:kalakris/cmake
RUN apt-get update -qq

RUN apt-get -y install git gcc-multilib g++-multilib libc6-dev:i386 libc6:i386 build-essential
RUN apt-get -y install cmake
#ENV tbs_arch x86

ADD . /var/libtiff



