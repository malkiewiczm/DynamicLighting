#include "common.hpp"

void _fatal(const char *msg, const char *file, const int line)
{
	fprintf(stderr, "fatal: %s (%s:%d)\n", msg, file, line);
	exit(1);
}
