import SwiftUI
import ZipPinch

#if os(macOS)
typealias XImage = NSImage
#else
typealias XImage = UIImage
#endif

struct ImageView: View {
    
    let entry: ZIPEntry?
    let url: URL?
    
    @State private var dataImage: XImage?
    @State private var size = ""
    @State private var error: String?
    
    var body: some View {
        ZStack {
            if let dataImage {
                ZStack(alignment: .bottomTrailing) {
                    ScrollView([.horizontal, .vertical]) {
                        imageView(dataImage: dataImage)
                    }
                    .ignoresSafeArea()
                    
                    imageView(dataImage: dataImage)
                        .resizable()
                        .scaledToFit()
                        .border(Color.accentColor, width: 2)
                        .overlay(alignment: .bottom) {
                            Text(size)
                                .monospaced()
                                .font(.caption.bold())
                                .background(
                                    Capsule(style: .continuous)
                                        .foregroundColor(Color.accentColor)
                                        .padding(.horizontal, -8)
                                        .padding(.vertical, -2)
                                )
                                .padding(.bottom, 12)
                                .foregroundColor(.white)
                        }
                        .frame(width: 150, height: 150)
                        .padding()
                }
            } else if let error {
                Label("ERROR: \(error)", systemImage: "xmark.octagon.fill")
                    .symbolRenderingMode(.multicolor)
                    .padding(.horizontal)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .navigationTitle(entry?.title ?? "")
        .task { @MainActor in
            guard let entry, let url else { return }
            
            do {
                let data = try await URLSession(configuration: .ephemeral).zipEntryData(entry, from: url)
                size = ByteCountFormatter.appFormatter.string(fromByteCount: Int64(data.count))
                #if os(macOS)
                dataImage = NSImage(data: data)
                #else
                dataImage = UIImage(data: data, scale: 3)
                #endif
                
            } catch {
                self.error = error.localizedDescription
                print("💥 Image:", error)
            }
        }
    }
    
    private func imageView(dataImage: XImage) -> Image {
        #if os(macOS)
        Image(nsImage: dataImage)
        #else
        Image(uiImage: dataImage)
        #endif
    }
}

extension ByteCountFormatter {
    static let appFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = .useAll
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()
}

struct ImageView_Previews: PreviewProvider {
    static var previews: some View {
        ImageView(entry: nil, url: nil)
    }
}
