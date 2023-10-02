import SwiftUI
import ZipPinch

struct ImagesView: View {
    
    let title: String
    let url: URL
    @State private var entries = [ZIPEntry]()
    @State private var hoveredEntry: ZIPEntry?
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            } else if let error {
                Label("**ERROR**\n\(error)", systemImage: "xmark.octagon.fill")
                    .symbolRenderingMode(.multicolor)
                    .padding(.horizontal)
            } else {
                entriesList
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task { @MainActor in
            guard entries.isEmpty else { return }
            
            do {
                isLoading = true
                entries = try await URLSession(configuration: .ephemeral).zipEntries(from: url)
            } catch let zipError as ZIPError {
                self.error = zipError.localizedDescription
                print("💥 ImagesView:", zipError)
            } catch {
                self.error = error.localizedDescription
                print("💥 ImagesView:", error)
            }
            
            isLoading = false
        }
    }
    
    @ViewBuilder
    private var entriesList: some View {
        List(Array(zip(entries.indices, entries)), id: \.0) { index, entry in
            if !entry.isDirectory {
                NavigationLink {
                    ImageView(entry: entry, url: url)
                } label: {
                    HStack(spacing: 16) {
                        Text("\(index).")
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                            
                            if let fileLastModificationDate = entry.fileLastModificationDate {
                                Text("\(fileLastModificationDate, format: .dateTime)")
                                    .foregroundColor(.secondary)
                                    .font(.footnote)
                            }
                        }
                        
                        Spacer()
                        
                        Text(ByteCountFormatter.appFormatter.string(fromByteCount: entry.compressedSize))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                    #if os(macOS)
                    .padding(.horizontal, 4)
                    .background(hoveredEntry == entry ? Color.accentColor.opacity(0.1) : nil)
                    .onHover { isHovered in
                        hoveredEntry = isHovered ? entry : nil
                    }
                    #endif
                }
            }
        }
    }
}

extension ZIPEntry {
    var title: String {
        let fileName = String(filePath.suffix(filePath.count - 7))
        return String(fileName.prefix(fileName.count - 4))
    }
}

struct ImagesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ImagesView(
                title: "Top 100",
                url: URL(string: "https://esahubble.org/static/images/zip/top100/top100-large.zip")!
            )
        }
    }
}
