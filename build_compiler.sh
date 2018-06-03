#!/bin/sh

BINUTILS="binutils-2.28"
GCC="gcc-6.4.0"

wget ftp://ftp.gnu.org/gnu/binutils/$BINUTILS.tar.gz
wget ftp://ftp.gnu.org/gnu/gcc/$GCC/$GCC.tar.gz

tar -xzvf $BINUTILS.tar.gz
tar -xzvf $GCC.tar.gz

cd $GCC
contrib/download_prerquisites
cd ..

export PREFIX="$HOME/opt/cross"
export TARGET=i686-elf
export PATH="$PREFIX/bin:$PATH"

mkdir build-binutils
cd build-binutils
../$BINUTILS/configure --target=$TARGET --prefix="$PREFIX" --with-sysroot --disable-nls -disable-werror
make
make install
cd ..

mkdir build-gcc
cd build-gcc
../$GCC/configure --target=$TARGET --prefix="$PREFIX" --disable-nls --enable-languages=c,c++ --without-headers
make all-gcc
make all-target-libgcc
make install-gcc
make install-target-libgcc
cd ..

rm $GCC.tar.gz
rm $BINUTIL.tar.gz
rm $GCC -rf
rm $BINUTIL -rf
rm build-gcc -rf
rm build-binutils -rf
