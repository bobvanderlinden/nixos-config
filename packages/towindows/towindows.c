#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, const char *argv) {
  int result;
  result = setuid(0);
  if (result) return result;
  result = system(PREFIX "/bin/towindows.sh");
  if (result) return result;
  return 0;
}
