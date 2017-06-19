/* -----------------------------------------------------------------------------
 * typemaps.i.
 *
 * SWIG Typemap library for PHP.
 *
 * This library provides standard typemaps for modifying SWIG's behavior.
 * With enough entries in this file, I hope that very few people actually
 * ever need to write a typemap.
 *
 * Define macros to define the following typemaps:
 *
 * TYPE *INPUT.   Argument is passed in as native variable by value.
 * TYPE *OUTPUT.  Argument is returned as an array from the function call.
 * TYPE *INOUT.   Argument is passed in by value, and out as part of returned list
 * TYPE *REFERENCE.  Argument is passed in as native variable with value
 *                   semantics.  Variable value is changed with result.
 *                   Use like this:
 *                   int foo(int *REFERENCE);
 *
 *                   $a = 0;
 *                   $rc = foo($a);
 *
 *                   Even though $a looks like it's passed by value,
 *                   its value can be changed by foo().
 * ----------------------------------------------------------------------------- */

%typemap(out) TYPE *wp_serialize_data
%{

    cout << "on" << endl;
    $result = "sfaasdfasf";
/*
    php_serialize_data_t var_hash;
    PHP_VAR_SERIALIZE_INIT(var_hash);
    php_var_serialize(serialize_str, serialize_data, &var_hash TSRMLS_CC);
    PHP_VAR_SERIALIZE_DESTROY(var_hash);
*/

%}
