#!/usr/bin/php
<?php

include "build/aerospike.php";
include "build/Bytes.php";

function byteStr2byteArray($s) {
    return array_slice(unpack("C*", "\0".$s), 1);
}

//$aero	= new Aerospike('1');
$aero	= new AerospikeWP("10.3.1.1,10.3.1.2,10.3.1.3,10.3.1.4,10.3.1.5", 3000, 100 );
echo "isConnected = " . $aero->isConnected() . "\n";
echo "getConnectionReusedCount = " . $aero->getConnectionReusedCount() . "\n";

$rData	= array();
$rData["DOUBLE1"]	= 134523.501;
$rData["DOUBLE2"]	= 3.15; 
$rData["TRUE"]		= true;
$rData["FALSE"]		= false;
$rData["NULL"]		= null;
$rData["STRING1"]	= "s111111111111111";
$rData["STRING2"]	= "s12";
$rData["STRING3"]	= "s1231";
$rData["STRING4"]	= "s1234";
$rData["STRING5"]	= "s12345";
$rData["INTEGER1"]	= 111;
//$rData["INTEGER2"]	= 222;
//$rData["INTEGER3"]	= 333;
//$rData["bin"]		= null;
//$rData['BYTE_STRING']	= null;
//$rData["BYTE"]		= new \Aerospike\Bytes( 'The quick fox jumped over the lazy brown dog' );
//$rData["BYTE"]		= null;
//$rData["ARRAY"]		= null;
$rData["ARRAY"]		= byteStr2byteArray('The quick fox jumped over the lazy brown dog');
$rData["ARRAY1"]		= gzdeflate('test stroing asfdjoiasjf io jasfdioasjfio aasfjioasdfjioas jasfiosafdjio');
$rData["ARRAY2"]		= gzdeflate('test stroing asfdjoiasjf io jasfdioasjfio aasfjioasdfjioas jasfiosafdjio');
//$rData["ARRAY4"]		= file_get_contents("aerospike_wrap.o");
//$rData["ARRAY3"]		= null;
//$rData["OBJECT"]	= new stdclass();

$nRet				= $aero->put( "viewer", "COOKIE", "test", $rData );
$rData				= $aero->get('viewer', "COOKIE", 'test') ;

echo gzinflate( $rData['ARRAY1'] ). "\n";

/*
var_dump( $aero->get('viewer', "COOKIE", 'f8cea446f3dd59f82a35b3844556dfee') );
echo "isConnected = " . $aero->isConnected() . "\n";
echo "getConnectionReusedCount = " . $aero->getConnectionReusedCount() . "\n";
var_dump( $aero->get('viewer', "COOKIE", 'f8cea446f3dd59f82a35b3844556dfee') );
*/
?>
