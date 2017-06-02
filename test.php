#!/usr/bin/php
<?php

include "build/aerospike.php";

//$aero	= new Aerospike('1');
$aero	= new AerospikeWP("10.3.1.1,10.3.1.2,10.3.1.3,10.3.1.4,10.3.1.5", 3000, 100 );
echo "isConnected = " . $aero->isConnected() . "\n";
echo "getConnectionReusedCount = " . $aero->getConnectionReusedCount() . "\n";
var_dump( $aero->get('viewer', "COOKIE", 'f8cea446f3dd59f82a35b3844556dfee') );
echo "isConnected = " . $aero->isConnected() . "\n";
echo "getConnectionReusedCount = " . $aero->getConnectionReusedCount() . "\n";
var_dump( $aero->get('viewer', "COOKIE", 'f8cea446f3dd59f82a35b3844556dfee') );

?>
