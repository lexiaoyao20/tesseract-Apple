import SwiftUI
import AppKit
import UniformTypeIdentifiers
import TesseractSwift

struct ContentView: View {
    @ObservedObject var viewModel: OCRViewModel
    @State private var variableKey: String = ""
    @State private var variableValue: String = ""
    @State private var isTargeted: Bool = false
    @State private var showingFileImporter = false

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                sidebar
                    .frame(minWidth: 340, idealWidth: 360, maxWidth: 400)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .overlay(Divider(), alignment: .trailing)

                ZStack {
                    Color(nsColor: .textBackgroundColor)
                        .ignoresSafeArea()
                    resultsStack
                }
            }
        }
        .navigationTitle("TesseractSwift Demo")
        .frame(minWidth: 1200, minHeight: 800)
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                Task { @MainActor in
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    guard let image = ImageUtilities.image(from: url) else {
                        viewModel.reportError("Unable to open image.")
                        return
                    }
                    viewModel.loadImage(image)
                }
            case .failure(let error): viewModel.reportError(error.localizedDescription)
            }
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                imagePanel
                configPanel
                variablePanel
                outputPanel
                actionButtons
                statusRow
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var resultsStack: some View {
        GeometryReader { proxy in
            let isWideLayout = proxy.size.width > 900

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    previewPanel
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    if isWideLayout {
                        HStack(alignment: .top, spacing: 20) {
                            resultsPanel
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .layoutPriority(1)

                            VStack(alignment: .leading, spacing: 16) {
                                rendererPanel
                                metricsPanel
                                tokensPanel
                            }
                            .frame(width: max(proxy.size.width * 0.32, 340),
                                   alignment: .topLeading)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            resultsPanel
                            rendererPanel
                            metricsPanel
                            tokensPanel
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("TesseractSwift Demo").font(.title2).fontWeight(.semibold)
                Text("Version \(TesseractSwift.version)").font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(viewModel.status).font(.subheadline)
                if viewModel.isRunning {
                    ProgressView(value: Double(viewModel.progress) / 100.0)
                        .frame(width: 160)
                }
            }
        }
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workspace").font(.title3).fontWeight(.semibold)
                    Text(viewModel.status).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                if viewModel.isRunning {
                    HStack(spacing: 8) {
                        ProgressView(value: Double(viewModel.progress) / 100.0)
                            .frame(width: 160)
                        Text("\(viewModel.progress)%").foregroundColor(.secondary)
                    }
                } else {
                    Button(action: viewModel.recognize) {
                        Label("Run recognition", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.currentImage == nil || viewModel.isRunning)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor.opacity(0.15),
                                Color(nsColor: .windowBackgroundColor)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
                    )

                if let image = viewModel.currentImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle").font(.system(size: 38, weight: .semibold))
                        Text("Load or drop an image to preview and run OCR.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 48)
                }
            }
            .frame(minHeight: 320, maxHeight: 420)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.12)))
    }

    private var imagePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Image").font(.headline)
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [6]))
                    )
                    .frame(height: 200)

                Group {
                    if let image = viewModel.currentImage {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.accentColor)
                            Text("Image loaded")
                                .font(.headline)
                            Text("\(Int(image.size.width)) × \(Int(image.size.height)) px")
                                .foregroundColor(.secondary)
                            Text("Preview and run OCR on the right.")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled").font(.largeTitle)
                            Text("Drop an image, paste, or open a file")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL, .image], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }

            HStack(spacing: 10) {
                Button(action: { showingFileImporter = true }) {
                    Label("Open", systemImage: "folder")
                }
                Button(action: pasteImage) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                Button(action: viewModel.loadSampleImage) {
                    Label("Sample", systemImage: "wand.and.stars")
                }
            }
        }
    }

    private var configPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Engine").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                TextField("Language (e.g. eng or chi_sim+eng)", text: $viewModel.language)
                TextField("tessdata path (parent of *.traineddata)", text: $viewModel.dataPath)
                HStack {
                    Picker("Engine", selection: $viewModel.engineMode) {
                        ForEach(OCREngineMode.demoOptions, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    Picker("PSM", selection: $viewModel.pageSegMode) {
                        ForEach(PageSegmentationMode.demoOptions, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                }
            }
        }
    }

    private var variablePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Variables").font(.headline)
            HStack {
                TextField("key", text: $variableKey).textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("value", text: $variableValue).textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Add") {
                    viewModel.addVariable(key: variableKey, value: variableValue)
                    variableKey = ""; variableValue = ""
                }.buttonStyle(.bordered)
            }
            if !viewModel.variables.isEmpty {
                ForEach(viewModel.variables) { pair in
                    HStack {
                        Text(pair.key).fontWeight(.semibold)
                        Spacer()
                        Text(pair.value).foregroundColor(.secondary)
                        Button(action: { viewModel.removeVariable(pair) }) {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(8)
                }
            }
        }
    }

    private var cropPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Crop (optional)").font(.headline)
            HStack {
                TextField("x", text: $viewModel.crop.x).frame(width: 60)
                TextField("y", text: $viewModel.crop.y).frame(width: 60)
                TextField("w", text: $viewModel.crop.width).frame(width: 60)
                TextField("h", text: $viewModel.crop.height).frame(width: 60)
                Spacer()
                if viewModel.crop.rect != nil {
                    Text("Using crop").foregroundColor(.secondary)
                }
            }
        }
    }

    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Outputs").font(.headline)
            VStack(alignment: .leading) {
                Toggle("HOCR", isOn: $viewModel.outputOptions.wantHOCR)
                Toggle("ALTO", isOn: $viewModel.outputOptions.wantAlto)
                Toggle("PAGE XML", isOn: $viewModel.outputOptions.wantPageXML)
                Toggle("TSV", isOn: $viewModel.outputOptions.wantTSV)
                Toggle("PDF", isOn: $viewModel.outputOptions.wantPDF)
                Toggle("PDF text-only", isOn: $viewModel.outputOptions.pdfTextOnly)
                    .disabled(!viewModel.outputOptions.wantPDF)
                Toggle("Box text", isOn: $viewModel.outputOptions.wantBoxText)
                Toggle("LSTM box", isOn: $viewModel.outputOptions.wantLSTMBox)
                Toggle("Word-str box", isOn: $viewModel.outputOptions.wantWordBox)
                Toggle("UNLV", isOn: $viewModel.outputOptions.wantUNLV)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: viewModel.recognize) {
                Label("Recognize", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRunning)

            Button(action: viewModel.cancel) {
                Label("Cancel", systemImage: "stop.fill")
            }
            .disabled(!viewModel.isRunning)
        }
    }

    private var statusRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let error = viewModel.errorMessage {
                Text("Error: \(error)").foregroundColor(.red)
            }
            if let path = viewModel.result?.dataPathUsed {
                Text("Tessdata: \(path)").font(.footnote).foregroundColor(.secondary)
            }
            if let engineUsed = viewModel.result?.engineUsed {
                Text("Engine: \(engineUsed.label)").font(.footnote).foregroundColor(.secondary)
            }
        }
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text outputs").font(.title3).fontWeight(.semibold)
            if let text = viewModel.result?.utf8Text {
                OutputSection(title: "UTF-8 Text", content: text)
            } else {
                placeholderCard("Run recognition to see extracted text.")
            }
            if let hocr = viewModel.result?.hocr {
                OutputSection(title: "HOCR", content: hocr)
            }
            if let alto = viewModel.result?.alto {
                OutputSection(title: "ALTO", content: alto)
            }
            if let page = viewModel.result?.pageXML {
                OutputSection(title: "PAGE XML", content: page)
            }
            if let tsv = viewModel.result?.tsv {
                OutputSection(title: "TSV", content: tsv)
            }
            if let box = viewModel.result?.boxText {
                OutputSection(title: "Box Text", content: box)
            }
            if let lstm = viewModel.result?.lstmBoxText {
                OutputSection(title: "LSTM Box", content: lstm)
            }
            if let wordBox = viewModel.result?.wordStrBoxText {
                OutputSection(title: "WordStr Box", content: wordBox)
            }
            if let unlv = viewModel.result?.unlv {
                OutputSection(title: "UNLV", content: unlv)
            }
        }
    }

    private var rendererPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Renderer outputs").font(.title3).fontWeight(.semibold)
            if let outputs = viewModel.result?.rendererOutputs, !outputs.isEmpty {
                ForEach(outputs) { item in
                    HStack {
                        Text(item.kind)
                        Spacer()
                        Text(item.url.lastPathComponent).foregroundColor(.secondary)
                        Button("Reveal") { reveal(item.url) }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.15)))
                }
            } else {
                placeholderCard("No renderer outputs yet")
            }
        }
    }

    private var metricsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metrics").font(.title3).fontWeight(.semibold)
            HStack {
                if let mean = viewModel.result?.meanConfidence {
                    Label("Mean conf: \(mean)", systemImage: "chart.bar")
                }
                if let blocks = viewModel.result?.blockCount {
                    Label("Blocks: \(blocks)", systemImage: "square.grid.3x2")
                }
            }
            if let confs = viewModel.result?.wordConfidences, !confs.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(Array(confs.prefix(80).enumerated()), id: \.offset) { item in
                            Text("\(item.element)")
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.accentColor.opacity(0.12))
                                .cornerRadius(8)
                        }
                    }
                }
            } else {
                placeholderCard("Run recognition to populate metrics.")
            }
        }
    }

    private var tokensPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tokens (word iterator)").font(.title3).fontWeight(.semibold)
            if let tokens = viewModel.result?.tokens, !tokens.isEmpty {
                ForEach(tokens.prefix(50)) { token in
                    HStack {
                        Text(token.text)
                        Spacer()
                        Text(String(format: "%.1f", token.confidence))
                            .foregroundColor(.secondary)
                        if let box = token.box {
                            Text("(\(Int(box.origin.x)),\(Int(box.origin.y)))")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                if (viewModel.result?.tokens.count ?? 0) > 50 {
                    Text("… \(viewModel.result?.tokens.count ?? 0) tokens total").foregroundColor(.secondary)
                }
            } else {
                placeholderCard("Run recognition to populate tokens.")
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    if let data, let image = NSImage(data: data) {
                        DispatchQueue.main.async { viewModel.loadImage(image) }
                    }
                }
                return true
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let url = item as? URL {
                        DispatchQueue.main.async { viewModel.loadImage(from: url) }
                    }
                }
                return true
            }
        }
        return false
    }

    private func pasteImage() {
        let pasteboard = NSPasteboard.general
        if let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage], let first = images.first {
            viewModel.loadImage(first)
        }
    }

    private func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

private struct OutputSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(content, forType: .string) }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }.buttonStyle(.borderless)
            }
            TextEditor(text: .constant(content))
                .frame(minHeight: 140)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
        }
    }
}

private func placeholderCard(_ message: String) -> some View {
    HStack {
        Image(systemName: "info.circle").foregroundColor(.secondary)
        Text(message).foregroundColor(.secondary)
        Spacer()
    }
    .padding(12)
    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15)))
}
