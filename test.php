#!/usr/bin/php
<?php

include "build/aerospike.php";

//$aero	= new Aerospike('1');
$aero	= new AerospikeWP("10.3.1.1,10.3.1.2,10.3.1.3,10.3.1.4,10.3.1.5", 3000, 100 );
echo "isConnected = " . $aero->isConnected() . "\n";
echo "getConnectionReusedCount = " . $aero->getConnectionReusedCount() . "\n";

$rData	= array();
$rData["DOUBLE1"]	= 134523.1411;
$rData["DOUBLE2"]	= 3.15; 
$rData["TRUE"]		= true;
$rData["FALSE"]		= false;
$rData["NULL"]		= null;
$rData["STRING1"]	= "s1";
$rData["STRING2"]	= "s12";
$rData["STRING3"]	= "s123";
$rData["STRING4"]	= "s1234";
$rData["STRING5"]	= "s12345";
$rData["INTEGER"]	= 111;
$rData["ARRAY"]		= array('1','2'); 
$rData["OBJECT"]	= new stdclass();

echo "put = " . $aero->put( $rData ) . "\n";
//var_dump( $aero->get('viewer', "COOKIE", 'f8cea446f3dd59f82a35b3844556dfee') );

/*
var_dump( $aero->get('viewer', "COOKIE", 'f8cea446f3dd59f82a35b3844556dfee') );
echo "isConnected = " . $aero->isConnected() . "\n";
echo "getConnectionReusedCount = " . $aero->getConnectionReusedCount() . "\n";
var_dump( $aero->get('viewer', "COOKIE", 'f8cea446f3dd59f82a35b3844556dfee') );
*/
?>
