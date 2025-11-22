//
//  ContentView.swift
//  OCRTest
//
//  Created by Subo on 11/17/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @State private var imagePath: String = ""
    @State private var recognizedText: String = "Recognition result will be shown here"
    @State private var isProcessing: Bool = false
    @State private var isCopyAvailable: Bool = false
    @State private var isShowingCopyToast: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Input field - display image path
            TextField("Image path", text: $imagePath)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(true)
                .padding(.horizontal)
            
            // Buttons - select image, copy result
            HStack(spacing: 12) {
                Button(action: selectImage) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text(isProcessing ? "Recognizing..." : "Select Image")
                    }
                    .frame(width: 150)
                }
                .disabled(isProcessing)

                Button(action: copyRecognizedText) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Result")
                    }
                    .frame(width: 120)
                }
                .disabled(!isCopyAvailable)
                .help(isCopyAvailable ? "Copy recognized text to clipboard" : "Copy becomes available after successful recognition")
            }
            
            // Text area - recognition result
            ScrollView {
                Text(recognizedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(height: 300)
            .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .overlay(alignment: .bottom) {
            if isShowingCopyToast {
                ToastView(text: "Copied to clipboard")
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    func selectImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = "Select an image to recognize"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.imagePath = url.path
                self.performOCR(on: url)
            }
        }
    }
    
    func performOCR(on imageURL: URL) {
        isProcessing = true
        recognizedText = "Recognizing, please wait..."
        isCopyAvailable = false
        
        let imagePath = imageURL.path
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Combine multiple languages with `+`, e.g., `chi_sim+eng`
            // Add trained data to the app bundle: https://github.com/tesseract-ocr/tessdata_best
            guard let tesseract = TesseractWrapper(language: "eng", customDataPath: nil) else {
                DispatchQueue.main.async {
                    self.recognizedText = "Error: failed to initialize Tesseract"
                    self.isCopyAvailable = false
                    self.isProcessing = false
                }
                return
            }

            let result = tesseract.recognize(imagePath: imagePath)

            DispatchQueue.main.async {
                if let text = result, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.recognizedText = text
                    self.isCopyAvailable = true
                } else {
                    self.recognizedText = "No text detected. Please try another image."
                    self.isCopyAvailable = false
                }
                self.isProcessing = false
            }
        }
    }

    func copyRecognizedText() {
        guard isCopyAvailable else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(recognizedText, forType: .string)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isShowingCopyToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.2)) {
                self.isShowingCopyToast = false
            }
        }
    }
}

private struct ToastView: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
            Text(text)
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.8))
        .cornerRadius(12)
        .shadow(radius: 6, y: 3)
    }
}
