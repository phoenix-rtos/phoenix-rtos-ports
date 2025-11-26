#include "wasm_export.h"
#include "example.h"
#include <string.h>
#include <stdio.h>

int foo1(wasm_exec_env_t exec_env, int a, int b)
{
	return a * b + 3;
}

void foo2(wasm_exec_env_t exec_env, unsigned char *msg, uint8_t *buffer, int buf_len)
{
	strncpy(msg, buffer, buf_len);
}
