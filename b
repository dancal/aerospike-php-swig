#!/bin/sh

MODULE_NAME="aerospike"

PHP_INSTALL_PATH=`php-config --extension-dir`
AEROSPIKE_CLIENT_C="../aerospike-client-c/target/Linux-x86_64"
LIBS="-lstdc++ -lrt -lc -lm -ldl -lz -lbz2 -lcrypto ${AEROSPIKE_CLIENT_C}/lib/libaerospike.a"

swig -c++ -php7 -outdir build src/${MODULE_NAME}.i

g++ -std=c++14 `php-config --includes` -O2 -Ibuild -march=native -mtune=native -fPIC -fpermissive -c src/*.cxx

g++ -std=c++14 -fPIC -shared *.o -I${AEROSPIKE_CLIENT_C}/include ${LIBS} -o libs/${MODULE_NAME}.so

cp -f libs/${MODULE_NAME}.so $PHP_INSTALL_PATH/
