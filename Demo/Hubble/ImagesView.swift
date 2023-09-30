import SwiftUI
import ZipPinch

struct ImagesView: View {
    
    let title: String
    let url: URL
    @State private var entries = [ZIPEntry]()
    @State private var hoveredEntry: ZIPEntry?
    
    var body: some View {
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
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task { @MainActor in
            guard entries.isEmpty else { return }
            
            do {
                entries = try await URLSession(configuration: .ephemeral).zipEntries(from: url)
            } catch {
                print("💥 Images:", error)
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
