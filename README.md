# PHP7, PHP7-FPM aerospike module



# Do not Use this. just test module.




# Install

##
	// apt-get install libphp7.0-embed

## SWIG

```shell
	git clone https://github.com/swig/swig.git

	cd swig
	./autogen.sh
	./configure
	make
	make install
	cd ..
```

## aerospike-client-c

```shell
	git clone https://github.com/aerospike/aerospike-client-c.git
	cd aerospike-client-c
	make
  	cd ..
```

## aerospike_php

```shell
	git clone http://dancal@src.widerlab.io/scm/tg/aerospike_php.git
	cd aerospike_php
  	./b
  	vi aerospike.ini
    extension=aerospike.so
```

# 예제
```php

include "build/aerospike.php";

$aero   	= new AerospikeWP("10.3.1.1,10.3.1.2,10.3.1.3,10.3.1.4,10.3.1.5", 3000, 100 );
$nRet       = $aero->put( "viewer", "COOKIE", "test", $rData );
$rData      = $aero->get('viewer', "COOKIE", 'test') ;
var_dump( $rData );
```
