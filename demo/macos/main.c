#include <stdio.h>
#include <tesseract/capi.h>

int main(void) {
    printf("Tesseract version: %s\n", TessVersion());
    printf("Tesseract API is available and linked correctly.\n");
    return 0;
}

