/* ----------------------------------------------------------------------------
 * This file was automatically generated by SWIG (http://www.swig.org).
 * Version 4.0.0
 *
 * This file is not intended to be easily readable and contains a number of
 * coding conventions designed to improve portability and efficiency. Do not make
 * changes to this file unless you know what you are doing--modify the SWIG
 * interface file instead.
 * ----------------------------------------------------------------------------- */

#ifndef PHP_AEROSPIKE_H
#define PHP_AEROSPIKE_H

extern zend_module_entry aerospike_module_entry;
#define phpext_aerospike_ptr &aerospike_module_entry

#ifdef PHP_WIN32
# define PHP_AEROSPIKE_API __declspec(dllexport)
#else
# define PHP_AEROSPIKE_API
#endif

ZEND_NAMED_FUNCTION(_wrap_AS_DATA_typeId_set);
ZEND_NAMED_FUNCTION(_wrap_AS_DATA_typeId_get);
ZEND_NAMED_FUNCTION(_wrap_AS_DATA_intValue_set);
ZEND_NAMED_FUNCTION(_wrap_AS_DATA_intValue_get);
ZEND_NAMED_FUNCTION(_wrap_AS_DATA_doubleValue_set);
ZEND_NAMED_FUNCTION(_wrap_AS_DATA_doubleValue_get);
ZEND_NAMED_FUNCTION(_wrap_AS_DATA_strValue_set);
ZEND_NAMED_FUNCTION(_wrap_AS_DATA_strValue_get);
ZEND_NAMED_FUNCTION(_wrap_AS_DATA_keyName_set);
ZEND_NAMED_FUNCTION(_wrap_AS_DATA_keyName_get);
ZEND_NAMED_FUNCTION(_wrap_AS_DATA_val_set);
ZEND_NAMED_FUNCTION(_wrap_AS_DATA_val_get);
ZEND_NAMED_FUNCTION(_wrap_AS_DATA_size_set);
ZEND_NAMED_FUNCTION(_wrap_AS_DATA_size_get);
ZEND_NAMED_FUNCTION(_wrap_new_AS_DATA);
ZEND_NAMED_FUNCTION(_wrap_AerospikeWP_host_key_set);
ZEND_NAMED_FUNCTION(_wrap_AerospikeWP_host_key_get);
ZEND_NAMED_FUNCTION(_wrap_new_AerospikeWP);
ZEND_NAMED_FUNCTION(_wrap_AerospikeWP_get);
ZEND_NAMED_FUNCTION(_wrap_AerospikeWP_put);
ZEND_NAMED_FUNCTION(_wrap_AerospikeWP_isConnected);
ZEND_NAMED_FUNCTION(_wrap_AerospikeWP_getConnectionReusedCount);
PHP_MINIT_FUNCTION(aerospike);
PHP_MSHUTDOWN_FUNCTION(aerospike);

#endif /* PHP_AEROSPIKE_H */
