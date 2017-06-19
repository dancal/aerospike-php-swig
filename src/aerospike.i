/*
    2017.06.04 created by dancal.
*/
%module aerospike;

%{
#include <fstream>
#include <sstream>
#include <iostream>
#include <vector>
#include <memory>
#include <map>
#include <unordered_map>

#include <boost/algorithm/string/classification.hpp> // Include boost::for is_any_of
#include <boost/algorithm/string/split.hpp> // Include for boost::split

#include <aerospike/aerospike.h>
#include <aerospike/aerospike_key.h>
#include <aerospike/aerospike_batch.h>
#include <aerospike/as_record.h>
#include <aerospike/as_record_iterator.h>
#include <aerospike/as_bytes.h>
#include <aerospike/as_status.h>
#include <aerospike/as_config.h>


#include <php.h>
#include <zend_types.h>
#include <zend_operators.h>
#include <zend_smart_str.h>

#include "zend.h"
#include "zend_globals.h"
#include "zend_variables.h"
#include "zend_API.h"
#include "zend_objects.h"
#include "zend_object_handlers.h"

#include <ext/standard/php_var.h>
#include <ext/standard/php_string.h>
#include <ext/standard/basic_functions.h>
#include <ext/standard/php_incomplete_class.h>
#include <ext/standard/base64.h>

#include "../include/base64.hpp"
#include "../include/aerospike.hpp"

#define AS_BYTECLASS   "Aerospike\\Bytes"

/* {{{ base64 tables */
static const char base64_table[] = {
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
    'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/', '\0'
};

static const char base64_pad = '=';

static const short base64_reverse_table[256] = {
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -1, -1, -2, -2, -1, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -1, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, 62, -2, -2, -2, 63,
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -2, -2, -2, -2, -2, -2,
    -2,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -2, -2, -2, -2, -2,
    -2, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2
};

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

zend_string *php_base64_encode(const unsigned char *str, size_t length) {
    const unsigned char *current = str;
    unsigned char *p;
    zend_string *result;

    result = zend_string_safe_alloc(((length + 2) / 3), 4 * sizeof(char), 0, 0);
    p = (unsigned char *)ZSTR_VAL(result);

    while (length > 2) { /* keep going until we have less than 24 bits */
        *p++ = base64_table[current[0] >> 2];
        *p++ = base64_table[((current[0] & 0x03) << 4) + (current[1] >> 4)];
        *p++ = base64_table[((current[1] & 0x0f) << 2) + (current[2] >> 6)];
        *p++ = base64_table[current[2] & 0x3f];

        current += 3;
        length -= 3; /* we just handle 3 octets of data */
    }

    /* now deal with the tail end of things */
    if (length != 0) {
        *p++ = base64_table[current[0] >> 2];
        if (length > 1) {
            *p++ = base64_table[((current[0] & 0x03) << 4) + (current[1] >> 4)];
            *p++ = base64_table[(current[1] & 0x0f) << 2];
            *p++ = base64_pad;
        } else {
            *p++ = base64_table[(current[0] & 0x03) << 4];
            *p++ = base64_pad;
            *p++ = base64_pad;
        }
    }
    *p = '\0';

    ZSTR_LEN(result) = (p - (unsigned char *)ZSTR_VAL(result));

    return result;
}

zend_string *php_base64_decode_ex(const unsigned char *str, size_t length, zend_bool strict) {
    const unsigned char *current = str;
    int ch, i = 0, j = 0, padding = 0;
    zend_string *result;

    result = zend_string_alloc(length, 0);

    /* run through the whole string, converting as we go */
    while (length-- > 0) {
        ch = *current++;
        if (ch == base64_pad) {
            padding++;
            continue;
        }

        ch = base64_reverse_table[ch];
        if (!strict) {
            /* skip unknown characters and whitespace */
            if (ch < 0) {
                continue;
            }
        } else {
            /* skip whitespace */
            if (ch == -1) {
                continue;
            }
            /* fail on bad characters or if any data follows padding */
            if (ch == -2 || padding) {
                goto fail;
            }
        }

        switch(i % 4) {
        case 0:
            ZSTR_VAL(result)[j] = ch << 2;
            break;
        case 1:
            ZSTR_VAL(result)[j++] |= ch >> 4;
            ZSTR_VAL(result)[j] = (ch & 0x0f) << 4;
            break;
        case 2:
            ZSTR_VAL(result)[j++] |= ch >>2;
            ZSTR_VAL(result)[j] = (ch & 0x03) << 6;
            break;
        case 3:
            ZSTR_VAL(result)[j++] |= ch;
            break;
        }
        i++;
    }
    /* fail if the input is truncated (only one char in last group) */
    if (strict && i % 4 == 1) {
        goto fail;
    }
    /* fail if the padding length is wrong (not VV==, VVV=), but accept zero padding
     * RFC 4648: "In some circumstances, the use of padding [--] is not required" */
    if (strict && padding && (padding > 2 || (i + padding) % 4 != 0)) {
        goto fail;
    }

    ZSTR_LEN(result) = j;
    ZSTR_VAL(result)[ZSTR_LEN(result)] = '\0';

    return result;

fail:
    zend_string_free(result);
    return NULL;
}


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
				Values.typeId			= WP_BYTES;
                Values.keyName          = bin_name;
				Values.strValue			= reinterpret_cast<char*>(as_bytes_get(bytes_val));
                Values.size             = nSize;
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
                //
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

        if ( it->typeId == IS_NULL ) {
            as_record_set_nil( &rec, it->keyName.c_str() );
        } else if ( it->typeId == IS_TRUE ) {
            as_record_set_integer( &rec, it->keyName.c_str(), as_integer_new(1) );
        } else if ( it->typeId == IS_FALSE ) {
            as_record_set_integer( &rec, it->keyName.c_str(), as_integer_new(0) );
        } else if ( it->typeId == IS_LONG ) {
            as_record_set_int64( &rec, it->keyName.c_str(), (int64_t)Z_LVAL_P(it->val) ); 
        } else if ( it->typeId == IS_DOUBLE ) {
            as_record_set_double( &rec, it->keyName.c_str(), (double)Z_DVAL_P(it->val) ); 
        } else if ( it->typeId == IS_STRING ) {

            zend_string *str        = php_base64_encode( (unsigned char*)Z_STRVAL_P(it->val), Z_STRLEN_P(it->val));
            as_record_set_str( &rec, it->keyName.c_str(), str->val );
            zend_string_free(str);

        } else if ( it->typeId == WP_ARRAY ) {
            // not support
        } else if ( it->typeId == WP_OBJECT ) {
            // not support
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

// input
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

    ZEND_HASH_FOREACH_STR_KEY_VAL(array, key, data TSRMLS_DC) {

        const char* key_char    = ZSTR_VAL(key);
        const zend_uchar zRet   = Z_TYPE_P(data);

        if ( zRet == IS_ARRAY ) {
            php_error_docref(NULL TSRMLS_CC, E_WARNING, "PHP ARRAY Type is Not Support. Ignore it.");
        } else if ( zRet == IS_RESOURCE ) {
            php_error_docref(NULL TSRMLS_CC, E_WARNING, "PHP RESOURCE Type is Not Support. Ignore it.");
        } else if ( zRet == IS_REFERENCE ) {
            php_error_docref(NULL TSRMLS_CC, E_WARNING, "PHP REFERENCE Type is Not Support. Ignore it.");
        } else if ( zRet == IS_OBJECT ) {
            php_error_docref(NULL TSRMLS_CC, E_WARNING, "PHP RESOURCE Type is Not Support. Ignore it.");
        } else {
            AS_DATA Values;
            Values.keyName              = key_char;
            Values.typeId               = zRet;
            Values.val                  = data;
            mData.push_back( Values );
        }

    } ZEND_HASH_FOREACH_END();

    $1 = &mData;
}

// output
%typemap(out) vDataList * {

    vDataList::iterator iter = $1->begin();
    vDataList::const_iterator end = $1->end();

    array_init(return_value);
    for (; iter != end; ++iter) {
		if ( iter->typeId == WP_STRING ) {
            zend_bool strict = 0;
            zend_string *result = php_base64_decode_ex( (unsigned char*)iter->strValue.c_str(), iter->strValue.size(), strict );
        	add_assoc_string(return_value, iter->keyName.c_str(), result->val );
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
