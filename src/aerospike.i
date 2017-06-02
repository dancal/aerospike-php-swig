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

#include "../include/aerospike.hpp"
%}

%include "../include/std_string.i"
%include "../include/std_map.i"
%include "../include/std_vector.i"
%include "../include/typemaps.i"

%{
static std::unordered_map<std::string, aerospike *> mAerospikeWP; 
int aerospike_php_connect( char *as_hosts, int as_port, int as_timeout ) {

	if ( mAerospikeWP.count(as_hosts) ) {
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
		mAerospikeWP[as_hosts]	= as;
	}

	return status;
}

int aerospike_php_close() {

    as_error as_err;
	for ( const auto& kv : mAerospikeWP ) {
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

// AerospikeWP Class
AerospikeWP::AerospikeWP( char *as_hosts, int as_port, int as_timeout ) {
	this->host_key	= as_hosts;
	int nRet		= aerospike_php_connect( as_hosts, as_port, as_timeout );
}

AerospikeWP::~AerospikeWP() {
}

bool AerospikeWP::isConnected() {
	
	if ( mAerospikeWP.count(this->host_key) <= 0 ) {
		return false;
	}

	aerospike *as       = mAerospikeWP[this->host_key];
	if ( aerospike_cluster_is_connected(as) ) {
		return true;
	}

	return false;
}

int AerospikeWP::getConnectionReusedCount() {
	static int use_connection_pool;
	return use_connection_pool++;
}

mDataList *AerospikeWP::get( char *nspace, char *set, char *key_str ) {

	mDataList *mResult	= new mDataList;
	if ( mAerospikeWP.count(this->host_key) <= 0 ) {
		return mResult;
	}

	aerospike *as		= mAerospikeWP[this->host_key];
	
    as_error as_err;
    as_record* rec      = NULL;

    as_key key;
    as_key_init(&key, nspace, set, key_str);

	as_status status    = aerospike_key_get(mAerospikeWP[this->host_key], &as_err, NULL, &key, &rec);
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
				Values.typeId			= TYPE_STRING;
				Values.strValue			= reinterpret_cast<char*>(as_bytes_get(bytes_val));
				(*mResult)[bin_name] 	= Values;

			} else if ( nValueType == AS_STRING ) {

				size_t nSize			= as_string_len( value );
				if ( nSize <= 0 ) {
					continue;
				}

				AS_DATA Values;
				Values.typeId			= TYPE_STRING;
				Values.strValue			= as_string_to_byte( value );
				(*mResult)[bin_name] 	= Values;

			} else if ( nValueType == AS_INTEGER ) {

				AS_DATA Values;
				Values.typeId			= TYPE_INT;
				Values.intValue			= as_integer_toint(as_integer_fromval(value));
				(*mResult)[bin_name] 	= Values;

			} else {
			}

		}

	}

    as_record_destroy(rec);
    as_key_destroy(&key);

	return mResult;
}

%}

%typemap(out) mDataList*
{
    mDataList::iterator iter = $1->begin();
    mDataList::const_iterator end = $1->end();
    array_init(return_value);
    for (; iter != end; ++iter) {
		if ( iter->second.typeId == TYPE_STRING ) {
        	add_assoc_string(return_value, iter->first.c_str(), (char *)iter->second.strValue.c_str() );
		} else if ( iter->second.typeId == TYPE_INT ) {
        	add_assoc_long(return_value, iter->first.c_str(), (int)iter->second.intValue );
		} else if ( iter->second.typeId == TYPE_FLOAT ) {
        	add_assoc_double(return_value, iter->first.c_str(), (double)iter->second.doubleValue );
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
