#include <iostream>

using namespace std;

enum TypeID {
    WP_NILL,
    WP_LONG,
    WP_DOUBLE,
    WP_STRING,
    WP_TRUE,
    WP_FALSE,
    WP_NULL
};    

struct AS_DATA {
    enum TypeID typeId = {WP_NILL};
	int64_t intValue;
	double doubleValue;
	std::string strValue;
	std::string keyName;
};

//typedef std::map<std::string, AS_DATA> mDataList;
typedef std::vector<AS_DATA> vDataList;
class AerospikeWP {
    public:
		char *host_key;
        AerospikeWP( char *as_hosts, int as_port, int as_timeout );
        ~AerospikeWP();
		vDataList *get( char *nspace, char *set, char *key_str );
		int put( vDataList &input_map );
		bool isConnected();
		int getConnectionReusedCount();
};

