/*
    2017.06.04 created by dancal.
*/
%module aerospike;

%{
#include <iostream>
#include <vector>
#include <memory>
#include <map>
#include <unordered_map>

#include <aerospike/aerospike.h>
#include <aerospike/aerospike_key.h>
#include <aerospike/aerospike_batch.h>
#include <aerospike/as_record.h>
#include <aerospike/as_record_iterator.h>

#include <php.h>
#include <php_ini.h>
#include <zend_types.h>
#include <zend_operators.h>
#include <zend_smart_str.h>
#include <ext/standard/php_var.h>
#include <ext/standard/php_string.h>
#include <ext/standard/basic_functions.h>
#include <ext/standard/php_incomplete_class.h>

#include "../include/aerospike.hpp"

using namespace std;
%}

%include "../include/std_string.i"
%include "../include/std_map.i"
%include "../include/std_vector.i"
%include "../include/typemaps.i"

%{
static std::unordered_map<std::string, aerospike *> _mAerospikeWP; 
int aerospike_php_connect( char *as_hosts, int as_port, int as_timeout ) {

	if ( _mAerospikeWP.count(as_hosts) ) {
		return 0;
	}

    as_config_tls g_tls     = {0};

    as_config_lua lua;
    as_config_lua_init(&lua);
    aerospike_init_lua(&lua);

    as_config config;
    as_config_init(&config);
    as_config_add_hosts(&config, as_hosts, as_port);

    config.conn_timeout_ms      = as_timeout;
    //config.thread_pool_size   = 16;
    //config.async_max_conns_per_node = 200;
    //config.max_conns_per_node     = 600;
    //config.tender_interval            = 500;
    //config.use_services_alternate = true;

    as_policies* p              = &config.policies;
    p->timeout                  = as_timeout;
    p->retry                    = AS_POLICY_RETRY_NONE;
    //p->key                    = AS_POLICY_DIGEST;
    //p->gen                    = AS_POLICY_GEN_IGNORE;
    //p->exists                 = AS_POLICY_EXISTS_IGNORE;
    //p->read.key               = AS_POLICY_KEY_DIGEST;
    p->read.timeout             = as_timeout;
    p->read.replica             = AS_POLICY_REPLICA_ANY;

    memcpy(&config.tls, &g_tls, sizeof(as_config_tls));
    as_error as_err;
    as_error_reset(&as_err);

	aerospike *as				= aerospike_new( &config );
	as_status status        	= aerospike_connect( as, &as_err );
	if ( status == AEROSPIKE_OK ) {
		_mAerospikeWP[as_hosts]	= as;
	}

	return status;
}

int aerospike_php_close() {

    as_error as_err;
	for ( const auto& kv : _mAerospikeWP ) {
	    as_error_reset(&as_err);
    	aerospike_close(kv.second, &as_err);
		aerospike_destroy(kv.second);
	}

	
	return 0;
}

char* convert(const std::string& str) {
    char* result = new char[str.length()+1];
    strcpy(result,str.c_str());
    return result;
}

char *as_string_to_byte(const as_val * v) {

    as_string * s = (as_string *) v;
    if (s->value == NULL) return(NULL);

    return s->value;
}

int as_string_len(const as_val * v) {
    as_string * s = (as_string *) v;
    if (s->value == NULL) {
        return 0;
    }
    if (s->len == SIZE_MAX) {
        s->len = strlen(s->value);
    }
    return s->len;

}

void php_var_serialize(smart_str *buf, zval *struc, php_serialize_data_t *data);

// AerospikeWP Class
AerospikeWP::AerospikeWP( char *as_hosts, int as_port, int as_timeout ) {
	this->host_key	= as_hosts;
	int nRet		= aerospike_php_connect( as_hosts, as_port, as_timeout );
}

AerospikeWP::~AerospikeWP() {
}

bool AerospikeWP::isConnected() {
	
	if ( _mAerospikeWP.count(this->host_key) <= 0 ) {
		return false;
	}

	aerospike *as       = _mAerospikeWP[this->host_key];
	if ( aerospike_cluster_is_connected(as) ) {
		return true;
	}

	return false;
}

int AerospikeWP::getConnectionReusedCount() {
	static int use_connection_pool;
	return use_connection_pool++;
}

vDataList *AerospikeWP::get( char *nspace, char *set, char *key_str ) {

	vDataList *vResult	= new vDataList;

	if ( _mAerospikeWP.count(this->host_key) <= 0 ) {
		return vResult;
	}

	aerospike *as		= _mAerospikeWP[this->host_key];
	
    as_error as_err;
    as_record* rec      = NULL;

    as_key key;
    as_key_init(&key, nspace, set, key_str);

	as_status status    = aerospike_key_get(_mAerospikeWP[this->host_key], &as_err, NULL, &key, &rec);
	if ( status == AEROSPIKE_OK ) {

		as_record_iterator it;
        as_record_iterator_init(&it, rec);
        while (as_record_iterator_has_next(&it)) {

			as_bin *bin				= as_record_iterator_next(&it);
		    as_val *value           = (as_val *)as_bin_get_value(bin);
		    int nValueType          = as_val_type(value);
			char *bin_name     		= as_bin_get_name(bin);
			if ( nValueType == AS_BYTES ) {

		        as_bytes *bytes_val = as_bytes_fromval( value );
		        size_t nSize        = as_bytes_size(bytes_val);
		        if ( nSize <= 0 ) {
					continue;
		        }

				AS_DATA Values;
				Values.typeId			= WP_STRING;
                Values.keyName          = bin_name;
				Values.strValue			= reinterpret_cast<char*>(as_bytes_get(bytes_val));
                (*vResult).push_back( Values );

			} else if ( nValueType == AS_STRING ) {

				size_t nSize			= as_string_len( value );
				if ( nSize <= 0 ) {
					continue;
				}

				AS_DATA Values;
				Values.typeId			= WP_STRING;
                Values.keyName          = bin_name;
				Values.strValue			= as_string_to_byte( value );
                (*vResult).push_back( Values );

			} else if ( nValueType == AS_INTEGER ) {

				AS_DATA Values;
				Values.typeId			= WP_LONG;
                Values.keyName          = bin_name;
				Values.intValue			= as_integer_toint(as_integer_fromval(value));
                (*vResult).push_back( Values );

			} else if ( nValueType == AS_DOUBLE ) {
                // 

				AS_DATA Values;
				Values.typeId			= WP_DOUBLE;
                Values.keyName          = bin_name;
				Values.doubleValue		= as_double_get( as_double_fromval(value) );
                (*vResult).push_back( Values );

			} else {
			}

		}

	}

    as_record_destroy(rec);
    as_key_destroy(&key);

	return vResult;
}

int AerospikeWP::put( char *nspace, char *set, char *key_str, vDataList &input_map ) {

    if ( _mAerospikeWP.count(this->host_key) <= 0 ) {
        return AEROSPIKE_ERR_CLIENT;
    }

    int vDataSize       = input_map.size();

    as_error as_err;
    aerospike *as       = _mAerospikeWP[this->host_key];

    as_key keyAS;
    as_key_init(&keyAS, nspace, set, key_str);

    as_record rec;
    as_record_inita(&rec, vDataSize);

    std::vector<AS_DATA>::iterator it;
    for( it = input_map.begin( ); it != input_map.end( ); ++it ) {
        switch( it->typeId ) {
            case WP_NULL:
                as_record_set_nil( &rec, it->keyName.c_str() );
                cout << "as_record_set_nil = " << it->keyName << endl;
                break; 
            case WP_TRUE:
                as_record_set_integer( &rec, it->keyName.c_str(), as_integer_new(1) );
                cout << "as_record_get_integer = " << it->keyName << ", v = 1" << endl;
                break; 
            case WP_FALSE:
                as_record_set_integer( &rec, it->keyName.c_str(), as_integer_new(0) );
                cout << "as_record_get_integer = " << it->keyName << ", v = 0" << endl;
                break; 
            case WP_LONG:
                as_record_set_int64( &rec, it->keyName.c_str(), it->intValue ); 
                cout << "as_record_get_int64 = " << it->keyName << ", v = " << it->intValue << endl;
                break;
            case WP_DOUBLE:
                as_record_set_double( &rec, it->keyName.c_str(), it->doubleValue ); 
                cout << "as_record_set_double = " << it->keyName << ", v = " << it->doubleValue << endl;
                break;
            case WP_STRING:
                as_record_set_str( &rec, it->keyName.c_str(), it->strValue.c_str() );
                cout << "as_record_set_string = " << it->keyName << ", v = " << it->strValue << endl;
                break;
            default:
                // static const uint8_t bytes[] = { 1, 2, 3 };
                // as_record_set_raw(&rec, "test-bin-4", bytes, 3);
                cout << "key = " << it->keyName << ", type = " << it->typeId << ", value = " << it->strValue << endl;
                break;
        }
    }

    int retCode = 0;
    if (aerospike_key_put(as, &as_err, NULL, &keyAS, &rec) != AEROSPIKE_OK) {
        retCode = as_err.code;
    }

    as_key_destroy(&keyAS);
    as_record_destroy(&rec);

    return retCode;
}

%}

%typemap(in) vDataList & {

    zval *arg;
    zval *z_array;
    long version = 0;

    zval *nspace;
    zval *set;
    zval *key_str;
    if (zend_parse_parameters(ZEND_NUM_ARGS() TSRMLS_CC, "zzzza|l", &arg, &nspace, &set, &key_str, &z_array, &version ) == FAILURE) {
        return;
    }
    // convert_to_string(nspace);
    // convert_to_string(set);
    // convert_to_string(key_str);

    vDataList mData;

    zend_string *key;
    zval *data;
    const HashTable *array  = HASH_OF(z_array);

    ZEND_HASH_FOREACH_STR_KEY_VAL(array, key, data) {

        const char* key_char    = ZSTR_VAL(key);
        const zend_uchar zRet   = Z_TYPE_P(data);

        AS_DATA Values;
        Values.keyName          = key_char;
        if ( zRet == IS_TRUE ) {
            Values.typeId           = WP_TRUE;
            mData.push_back( Values );
        } else if ( zRet == IS_FALSE ) {
            Values.typeId           = WP_FALSE;
            mData.push_back( Values );
        } else if ( zRet == IS_STRING ) {
            Values.typeId           = WP_STRING;
            Values.strValue         = Z_STRVAL_P(data);
            mData.push_back( Values );
        } else if ( zRet == IS_LONG ) {
            Values.typeId           = WP_LONG;
            Values.intValue         = (int64_t)Z_LVAL_P(data);
            mData.push_back( Values );
        } else if ( zRet == IS_DOUBLE ) {
            Values.typeId           = WP_DOUBLE;
            Values.doubleValue      = (double)Z_DVAL_P(data);
            mData.push_back( Values );
        } else if ( zRet == IS_NULL ) {
            Values.typeId           = WP_NULL;
            mData.push_back( Values );
        } else if ( zRet == IS_ARRAY ) {
            //php_error_docref(NULL TSRMLS_CC, E_WARNING, "PHP ARRAY Type is Not Support. Ignore it.");
            smart_str buf = {0};
            php_serialize_data_t var_hash;
            PHP_VAR_SERIALIZE_INIT(var_hash);
            php_var_serialize(&buf, data, &var_hash);
            PHP_VAR_SERIALIZE_DESTROY(var_hash);
            cout << buf.s->val << endl;
            smart_str_free(&buf);

        } else if ( zRet == IS_OBJECT ) {
            // php_error_docref(NULL TSRMLS_CC, E_WARNING, "PHP OBJECT Type is Not Support. Ignore it.");

        } else if ( zRet == IS_RESOURCE ) {
            php_error_docref(NULL TSRMLS_CC, E_WARNING, "PHP RESOURCE Type is Not Support. Ignore it.");
        } else if ( zRet == IS_REFERENCE ) {
            php_error_docref(NULL TSRMLS_CC, E_WARNING, "PHP REFERENCE Type is Not Support. Ignore it.");
        }

    } ZEND_HASH_FOREACH_END();

    $1 = &mData;
}

%typemap(out) vDataList * {

    vDataList::iterator iter = $1->begin();
    vDataList::const_iterator end = $1->end();

    array_init(return_value);
    for (; iter != end; ++iter) {
		if ( iter->typeId == WP_STRING ) {
        	add_assoc_string(return_value, iter->keyName.c_str(), (char *)iter->strValue.c_str() );
		} else if ( iter->typeId == WP_LONG ) {
        	add_assoc_long(return_value, iter->keyName.c_str(), (int)iter->intValue );
		} else if ( iter->typeId == WP_DOUBLE ) {
        	add_assoc_double(return_value, iter->keyName.c_str(), (double)iter->doubleValue );
		} else if ( iter->typeId == WP_TRUE ) {
        	add_assoc_bool(return_value, iter->keyName.c_str(), true );
		} else if ( iter->typeId == WP_FALSE ) {
        	add_assoc_bool(return_value, iter->keyName.c_str(), false );
		} else if ( iter->typeId == WP_NULL ) {
        	add_assoc_null(return_value, iter->keyName.c_str() );
		}
    } 
    delete $1;
}

%minit {
	// zend_printf("Inserted into PHP_MINIT_FUNCTION\n");
}
%mshutdown {
	// zend_printf("Inserted into PHP_MSHUTDOWN_FUNCTION\n");
	aerospike_php_close();
}

%include "../include/aerospike.hpp"

%feature("director") AerospikeWP;
