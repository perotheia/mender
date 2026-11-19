/* Ubuntu 24.04's cross libstdc++.a (gcc 11) was compiled against glibc 2.39
 * headers and so calls __isoc23_strtoul (GLIBC_2.38: C23 strtoul, which also
 * accepts a "0b" prefix with base 0 or 2). We link against glibc 2.36, so
 * provide it on top of the classic strtoul. libstdc++ does not rely on
 * binary-prefix parsing. Linked as an object into each executable. */
#include <stdlib.h>

unsigned long __isoc23_strtoul(const char *nptr, char **endptr, int base);

unsigned long __isoc23_strtoul(const char *nptr, char **endptr, int base) {
	return strtoul(nptr, endptr, base);
}
