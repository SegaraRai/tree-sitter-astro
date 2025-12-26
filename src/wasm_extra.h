#if defined(NEED_WASM_EXTRA_H) && !defined(WASM_EXTRA_H)
#define WASM_EXTRA_H

#ifndef UINT8_MAX
#define UINT8_MAX 255
#endif

char *strncpy(char *string1, const char *string2, size_t count);
size_t strlen(const char *string);

#endif  // WASM_EXTRA_H
