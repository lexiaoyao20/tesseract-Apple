import Foundation
import Tesseract

/// Swift wrapper for the Tesseract C API.
/// Manages lifecycle, memory cleanup, and type conversions.
class TesseractWrapper {
    
    /// Pointer to the Tesseract API instance (C type TessBaseAPI *).
    private var api: OpaquePointer?
    
    /// Initialize Tesseract
    /// - Parameters:
    ///   - language: Language codes like "eng" or "chi_sim+eng".
    ///   - customDataPath: Custom tessdata parent directory. If nil, uses Bundle.main.resourcePath.
    init?(language: String = "eng", customDataPath: String? = nil) {
        // 1. Create API instance
        guard let api = TessBaseAPICreate() else {
            print("[Tesseract] Failed to create API instance (TessBaseAPICreate returned nil)")
            return nil
        }
        self.api = api
        
        // 2. Resolve data path
        let dataPath = customDataPath ?? Bundle.main.resourcePath ?? ""
        
        if dataPath.isEmpty {
            print("[Tesseract] Resource path unavailable and no custom path provided")
            TessBaseAPIDelete(api)
            return nil
        }
        
        // 3. Set TESSDATA_PREFIX
        setenv("TESSDATA_PREFIX", dataPath, 1)
        
        // 4. Initialize API
        let returnCode = TessBaseAPIInit3(api, dataPath, language)
        
        if returnCode != 0 {
            print("[Tesseract] Initialization failed (code: \(returnCode))")
            TessBaseAPIDelete(api)
            self.api = nil
            return nil
        }
        
        print("[Tesseract] Initialized (language: \(language))")
    }
    
    deinit {
        if let api = api {
            TessBaseAPIEnd(api)
            TessBaseAPIDelete(api)
        }
    }
    
    /// Recognize a given image file.
    /// - Parameter imagePath: Absolute path to the image file.
    /// - Returns: Recognized text, or nil on failure.
    func recognize(imagePath: String) -> String? {
        guard let api = api else {
            print("[Tesseract] API was not initialized")
            return nil
        }
        
        // 1. Read image with Leptonica
        guard let rawPix = pixRead(imagePath) else {
            print("[Tesseract] Failed to read image: \(imagePath)")
            return nil
        }
        
        // Convert to OpaquePointer via UnsafeMutableRawPointer to handle any pointer type.
        let pix = OpaquePointer(UnsafeMutableRawPointer(rawPix))
        
        // 2. Set image on Tesseract
        TessBaseAPISetImage2(api, pix)
        
        // 3. Get recognition result (UTF-8 text)
        var textResult: String? = nil
        
        if let textPtr = TessBaseAPIGetUTF8Text(api) {
            // 4. Convert to Swift String
            textResult = String(cString: textPtr)
            
            // 5. Free C string memory
            TessDeleteText(textPtr)
        } else {
            print("[Tesseract] Recognition result was empty")
        }
        
        // 6. Clean up Leptonica image memory; pixDestroy expects UnsafeMutablePointer<OpaquePointer?>
        var pixToDestroy: OpaquePointer? = pix
        pixDestroy(&pixToDestroy)
        
        return textResult
    }
    
    static var version: String {
        if let versionPtr = TessVersion() {
            return String(cString: versionPtr)
        }
        return "Unknown"
    }
}
