#include <iostream>

using namespace std;


enum TypeID {
    TYPE_INT,
    TYPE_FLOAT,
    TYPE_STRING
};    

struct AS_DATA {
    int typeId;
	int intValue;
	double doubleValue;
	std::string strValue;
	
};

typedef map<string, AS_DATA> mDataList;
class AerospikeWP {
    public:
		char *host_key;
        AerospikeWP( char *as_hosts, int as_port, int as_timeout );
        ~AerospikeWP();
		//char *get( char *nspace, char *set, char *key_str  );
		mDataList *get( char *nspace, char *set, char *key_str );
		bool isConnected();
		int getConnectionReusedCount();
};

