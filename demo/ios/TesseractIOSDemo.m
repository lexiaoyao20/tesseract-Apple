#import <Foundation/Foundation.h>
#import <tesseract/capi.h>

void RunTesseractDemo(void) {
    NSLog(@"Tesseract version: %s", TessVersion());
    NSLog(@"Tesseract iOS demo call succeeded.");
}

