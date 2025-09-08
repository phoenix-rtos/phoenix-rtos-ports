#include <stddef.h>
#include "wasm_export.h"
#include "example/example.h"

NativeSymbol native_symbols[] = {
	{ "foo1",     // the name of WASM function name
		foo1,     // the native function pointer
		"(ii)i",  // the function prototype signature
		NULL },
	{ "foo2",     // the name of WASM function name
		foo2,     // the native function pointer
		"($*~)",  // the function prototype signature
		NULL }
};

int n_native_symbols = sizeof(native_symbols) / sizeof(NativeSymbol);
