#include <iostream>
#include <vector>
#include <memory>
#include <map>
#include <unordered_map>

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

#define PHP_DOUBLE_MAX_LENGTH 1080

static void php_var_serialize_intern(smart_str *buf, zval *struc, php_serialize_data_t var_hash);

static inline zend_long php_add_var_hash(php_serialize_data_t data, zval *var) /* {{{ */
{   
    zval *zv;
    zend_ulong key;
    zend_bool is_ref = Z_ISREF_P(var);
    
    data->n += 1;
    
    if (!is_ref && Z_TYPE_P(var) != IS_OBJECT) {
        return 0;
    }
    
    /* References to objects are treated as if the reference didn't exist */
    if (is_ref && Z_TYPE_P(Z_REFVAL_P(var)) == IS_OBJECT) {
        var = Z_REFVAL_P(var);
    }
    
    /* Index for the variable is stored using the numeric value of the pointer to
     * the zend_refcounted struct */
    key = (zend_ulong) (zend_uintptr_t) Z_COUNTED_P(var);
    zv = zend_hash_index_find(&data->ht, key);
    
    if (zv) {
        /* References are only counted once, undo the data->n increment above */
        if (is_ref) {
            data->n -= 1;
        }
        
        return Z_LVAL_P(zv);
    } else { 
        zval zv_n;
        ZVAL_LONG(&zv_n, data->n);
        zend_hash_index_add_new(&data->ht, key, &zv_n);
        
        /* Additionally to the index, we also store the variable, to ensure that it is
         * not destroyed during serialization and its pointer reused. The variable is
         * stored at the numeric value of the pointer + 1, which cannot be the location
         * of another zend_refcounted structure. */ 
        zend_hash_index_add_new(&data->ht, key + 1, var);
        Z_ADDREF_P(var);
        
        return 0;
    }
}

static inline void php_var_serialize_long(smart_str *buf, zend_long val) /* {{{ */
{
    smart_str_appendl(buf, "i:", 2);
    smart_str_append_long(buf, val);
    smart_str_appendc(buf, ';');
}
/* }}} */

static inline void php_var_serialize_string(smart_str *buf, char *str, size_t len) /* {{{ */
{
    smart_str_appendl(buf, "s:", 2);
    smart_str_append_unsigned(buf, len);
    smart_str_appendl(buf, ":\"", 2);
    smart_str_appendl(buf, str, len);
    smart_str_appendl(buf, "\";", 2);
}
/* }}} */

static inline zend_bool php_var_serialize_class_name(smart_str *buf, zval *struc) /* {{{ */
{
    PHP_CLASS_ATTRIBUTES;

    PHP_SET_CLASS_ATTRIBUTES(struc);
    smart_str_appendl(buf, "O:", 2);
    smart_str_append_unsigned(buf, ZSTR_LEN(class_name));
    smart_str_appendl(buf, ":\"", 2);
    smart_str_append(buf, class_name);
    smart_str_appendl(buf, "\":", 2);
    PHP_CLEANUP_CLASS_ATTRIBUTES();
    return incomplete_class;
}
/* }}} */

static HashTable *php_var_serialize_collect_names(HashTable *src, uint32_t count, zend_bool incomplete) /* {{{ */ {
    zval *val;
    HashTable *ht;
    zend_string *key, *name;

    ALLOC_HASHTABLE(ht);
    zend_hash_init(ht, count, NULL, NULL, 0);
    ZEND_HASH_FOREACH_STR_KEY_VAL(src, key, val) {
        if (incomplete && strcmp(ZSTR_VAL(key), MAGIC_MEMBER) == 0) {
            continue;
        }
        if (Z_TYPE_P(val) != IS_STRING) {
            php_error_docref(NULL, E_NOTICE,
                    "__sleep should return an array only containing the names of instance-variables to serialize.");
        }
        name = zval_get_string(val);
        if (zend_hash_exists(ht, name)) {
            php_error_docref(NULL, E_NOTICE,
                    "\"%s\" is returned from __sleep multiple times", ZSTR_VAL(name));
            zend_string_release(name);
            continue;
        }
        zend_hash_add_empty_element(ht, name);
        zend_string_release(name);
    } ZEND_HASH_FOREACH_END();

    return ht;
}
/* }}} */

static void php_var_serialize_class(smart_str *buf, zval *struc, zval *retval_ptr, php_serialize_data_t var_hash) /* {{{ */
{
    uint32_t count;
    zend_bool incomplete_class;
    HashTable *ht;

    incomplete_class = php_var_serialize_class_name(buf, struc);
    /* count after serializing name, since php_var_serialize_class_name
     * changes the count if the variable is incomplete class */
    if (Z_TYPE_P(retval_ptr) == IS_ARRAY) {
        ht = Z_ARRVAL_P(retval_ptr);
        count = zend_array_count(ht);
    } else if (Z_TYPE_P(retval_ptr) == IS_OBJECT) {
        ht = Z_OBJPROP_P(retval_ptr);
        count = zend_array_count(ht);
        if (incomplete_class) {
            --count;
        }
    } else {
        count = 0;
        ht = NULL;
    }

    if (count > 0) {
        zval *d;
        zval nval, *nvalp;
        zend_string *name;
        HashTable *names, *propers;

        names = php_var_serialize_collect_names(ht, count, incomplete_class);

        smart_str_append_unsigned(buf, zend_hash_num_elements(names));
        smart_str_appendl(buf, ":{", 2);

        ZVAL_NULL(&nval);
        nvalp = &nval;
        propers = Z_OBJPROP_P(struc);

        ZEND_HASH_FOREACH_STR_KEY(names, name) {
            if ((d = zend_hash_find(propers, name)) != NULL) {
                if (Z_TYPE_P(d) == IS_INDIRECT) {
                    d = Z_INDIRECT_P(d);
                    if (Z_TYPE_P(d) == IS_UNDEF) {
                        continue;
                    }
                }
                php_var_serialize_string(buf, ZSTR_VAL(name), ZSTR_LEN(name));
                php_var_serialize_intern(buf, d, var_hash);
            } else {
                zend_class_entry *ce = Z_OBJ_P(struc)->ce;
                if (ce) {
                    zend_string *prot_name, *priv_name;

                    do {
                        priv_name = zend_mangle_property_name(
                                ZSTR_VAL(ce->name), ZSTR_LEN(ce->name), ZSTR_VAL(name), ZSTR_LEN(name), ce->type & ZEND_INTERNAL_CLASS);
                        if ((d = zend_hash_find(propers, priv_name)) != NULL) {
                            if (Z_TYPE_P(d) == IS_INDIRECT) {
                                d = Z_INDIRECT_P(d);
                                if (Z_ISUNDEF_P(d)) {
                                    break;
                                }
                            }
                            php_var_serialize_string(buf, ZSTR_VAL(priv_name), ZSTR_LEN(priv_name));
                            zend_string_free(priv_name);
                            php_var_serialize_intern(buf, d, var_hash);
                            break;
                        }
                        zend_string_free(priv_name);
                        prot_name = zend_mangle_property_name(
                                "*", 1, ZSTR_VAL(name), ZSTR_LEN(name), ce->type & ZEND_INTERNAL_CLASS);
                        if ((d = zend_hash_find(propers, prot_name)) != NULL) {
                            if (Z_TYPE_P(d) == IS_INDIRECT) {
                                d = Z_INDIRECT_P(d);
                                if (Z_TYPE_P(d) == IS_UNDEF) {
                                    zend_string_free(prot_name);
                                    break;
                                }
                            }
                            php_var_serialize_string(buf, ZSTR_VAL(prot_name), ZSTR_LEN(prot_name));
                            zend_string_free(prot_name);
                            php_var_serialize_intern(buf, d, var_hash);
                            break;
                        }
                        zend_string_free(prot_name);
                        php_var_serialize_string(buf, ZSTR_VAL(name), ZSTR_LEN(name));
                        php_var_serialize_intern(buf, nvalp, var_hash);
                        php_error_docref(NULL, E_NOTICE,
                                "\"%s\" returned as member variable from __sleep() but does not exist", ZSTR_VAL(name));
                    } while (0);
                } else {
                    php_var_serialize_string(buf, ZSTR_VAL(name), ZSTR_LEN(name));
                    php_var_serialize_intern(buf, nvalp, var_hash);
                }
            }
        } ZEND_HASH_FOREACH_END();
        smart_str_appendc(buf, '}');

        zend_hash_destroy(names);
        FREE_HASHTABLE(names);
    } else {
        smart_str_appendl(buf, "0:{}", 4);
    }
}
/* }}} */

static void php_var_serialize_intern(smart_str *buf, zval *struc, php_serialize_data_t var_hash) /* {{{ */
{
    zend_long var_already;
    HashTable *myht;

    if (EG(exception)) {
        return;
    }

    if (var_hash && (var_already = php_add_var_hash(var_hash, struc))) {
        if (Z_ISREF_P(struc)) {
            smart_str_appendl(buf, "R:", 2);
            smart_str_append_long(buf, var_already);
            smart_str_appendc(buf, ';');
            return;
        } else if (Z_TYPE_P(struc) == IS_OBJECT) {
            smart_str_appendl(buf, "r:", 2);
            smart_str_append_long(buf, var_already);
            smart_str_appendc(buf, ';');
            return;
        }
    }

again:
    switch (Z_TYPE_P(struc)) {
        case IS_FALSE:
            smart_str_appendl(buf, "b:0;", 4);
            return;

        case IS_TRUE:
            smart_str_appendl(buf, "b:1;", 4);
            return;

        case IS_NULL:
            smart_str_appendl(buf, "N;", 2);
            return;

        case IS_LONG:
            php_var_serialize_long(buf, Z_LVAL_P(struc));
            return;

        case IS_DOUBLE: {
            char tmp_str[PHP_DOUBLE_MAX_LENGTH];
            smart_str_appendl(buf, "d:", 2);
            php_gcvt(Z_DVAL_P(struc), (int)PG(serialize_precision), '.', 'E', tmp_str);
            smart_str_appends(buf, tmp_str);
            smart_str_appendc(buf, ';');
            return;
        }
        case IS_STRING:
            php_var_serialize_string(buf, Z_STRVAL_P(struc), Z_STRLEN_P(struc));
            return;

        case IS_OBJECT: {
                zend_class_entry *ce = Z_OBJCE_P(struc);

                if (ce->serialize != NULL) {
                    /* has custom handler */
                    unsigned char *serialized_data = NULL;
                    size_t serialized_length;

                    if (ce->serialize(struc, &serialized_data, &serialized_length, (zend_serialize_data *)var_hash) == SUCCESS) {
                        smart_str_appendl(buf, "C:", 2);
                        smart_str_append_unsigned(buf, ZSTR_LEN(Z_OBJCE_P(struc)->name));
                        smart_str_appendl(buf, ":\"", 2);
                        smart_str_append(buf, Z_OBJCE_P(struc)->name);
                        smart_str_appendl(buf, "\":", 2);

                        smart_str_append_unsigned(buf, serialized_length);
                        smart_str_appendl(buf, ":{", 2);
                        smart_str_appendl(buf, (char *) serialized_data, serialized_length);
                        smart_str_appendc(buf, '}');
                    } else {
                        smart_str_appendl(buf, "N;", 2);
                    }
                    if (serialized_data) {
                        efree(serialized_data);
                    }
                    return;
                }

                if (ce != PHP_IC_ENTRY && zend_hash_str_exists(&ce->function_table, "__sleep", sizeof("__sleep")-1)) {
                    zval fname, tmp, retval;
                    int res;

                    ZVAL_COPY(&tmp, struc);
                    ZVAL_STRINGL(&fname, "__sleep", sizeof("__sleep") - 1);
                    BG(serialize_lock)++;
                    res = call_user_function_ex(CG(function_table), &tmp, &fname, &retval, 0, 0, 1, NULL);
                    BG(serialize_lock)--;
                    zval_dtor(&fname);

                    if (EG(exception)) {
                        zval_ptr_dtor(&retval);
                        zval_ptr_dtor(&tmp);
                        return;
                    }

                    if (res == SUCCESS) {
                        if (Z_TYPE(retval) != IS_UNDEF) {
                            if (HASH_OF(&retval)) {
                                php_var_serialize_class(buf, &tmp, &retval, var_hash);
                            } else {
                                php_error_docref(NULL, E_NOTICE, "__sleep should return an array only containing the names of instance-variables to serialize");
                                /* we should still add element even if it's not OK,
                                 * since we already wrote the length of the array before */
                                smart_str_appendl(buf,"N;", 2);
                            }
                        }
                        zval_ptr_dtor(&retval);
                        zval_ptr_dtor(&tmp);
                        return;
                    }
                    zval_ptr_dtor(&retval);
                    zval_ptr_dtor(&tmp);
                }

                /* fall-through */
            }
        case IS_ARRAY: {
            uint32_t i;
            zend_bool incomplete_class = 0;
            if (Z_TYPE_P(struc) == IS_ARRAY) {
                smart_str_appendl(buf, "a:", 2);
                myht = Z_ARRVAL_P(struc);
                i = zend_array_count(myht);
            } else {
                incomplete_class = php_var_serialize_class_name(buf, struc);
                myht = Z_OBJPROP_P(struc);
                /* count after serializing name, since php_var_serialize_class_name
                 * changes the count if the variable is incomplete class */
                i = zend_array_count(myht);
                if (i > 0 && incomplete_class) {
                    --i;
                }
            }
            smart_str_append_unsigned(buf, i);
            smart_str_appendl(buf, ":{", 2);
            if (i > 0) {
                zend_string *key;
                zval *data;
                zend_ulong index;

                ZEND_HASH_FOREACH_KEY_VAL_IND(myht, index, key, data) {

                    if (incomplete_class && strcmp(ZSTR_VAL(key), MAGIC_MEMBER) == 0) {
                        continue;
                    }

                    if (!key) {
                        php_var_serialize_long(buf, index);
                    } else {
                        php_var_serialize_string(buf, ZSTR_VAL(key), ZSTR_LEN(key));
                    }

                    if (Z_ISREF_P(data) && Z_REFCOUNT_P(data) == 1) {
                        data = Z_REFVAL_P(data);
                    }

                    /* we should still add element even if it's not OK,
                     * since we already wrote the length of the array before */
                    if ((Z_TYPE_P(data) == IS_ARRAY && Z_TYPE_P(struc) == IS_ARRAY && Z_ARR_P(data) == Z_ARR_P(struc))
                        || (Z_TYPE_P(data) == IS_ARRAY && Z_ARRVAL_P(data)->u.v.nApplyCount > 1)
                    ) {
                        smart_str_appendl(buf, "N;", 2);
                    } else {
                        if (Z_TYPE_P(data) == IS_ARRAY && ZEND_HASH_APPLY_PROTECTION(Z_ARRVAL_P(data))) {
                            Z_ARRVAL_P(data)->u.v.nApplyCount++;
                        }
                        php_var_serialize_intern(buf, data, var_hash);
                        if (Z_TYPE_P(data) == IS_ARRAY && ZEND_HASH_APPLY_PROTECTION(Z_ARRVAL_P(data))) {
                            Z_ARRVAL_P(data)->u.v.nApplyCount--;
                        }
                    }
                } ZEND_HASH_FOREACH_END();
            }
            smart_str_appendc(buf, '}');
            return;
        }
        case IS_REFERENCE:
            struc = Z_REFVAL_P(struc);
            goto again;
        default:
            smart_str_appendl(buf, "i:0;", 4);
            return;
    }
}
/* }}} */


void php_var_serialize(smart_str *buf, zval *struc, php_serialize_data_t *data) /* {{{ */
{
    php_var_serialize_intern(buf, struc, *data);
    smart_str_0(buf);
}

