import SwiftUI
import ZipPinch

struct ImagesView: View {
    
    let title: String
    let url: URL
    @State private var entries = [ZIPEntry]()
    @State private var rootFolder: ZIPFolder
    @State private var hoveredEntry: ZIPEntry?
    @State private var isLoading = false
    @State private var error: String?
    
    init(title: String, url: URL, rootFolder: ZIPFolder? = nil) {
        self.title = title
        self.url = url
        _rootFolder = .init(initialValue: rootFolder ?? .empty)
    }
    
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
                folderView
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task { @MainActor in
            guard entries.isEmpty, rootFolder == .empty else { return }
            
            do {
                isLoading = true
                entries = try await URLSession(configuration: .ephemeral).zipEntries(from: url)
                rootFolder = entries.rootFolder()
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
    private var folderView: some View {
        List {
            ForEach(rootFolder.subfolders) { subfolder in
                folderLink(folder: subfolder)
            }
            
            ForEach(rootFolder.entries) { entry in
                imageLink(entry: entry)
            }
        }
    }
    
    @ViewBuilder
    private func folderLink(folder: ZIPFolder) -> some View {
        NavigationLink {
            ImagesView(title: folder.name, url: url, rootFolder: folder)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "folder")
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.name)
                    
                    HStack(spacing: 8) {
                        if folder.entries.count > 0 {
                            Text("\(folder.entries.count) files")
                        }
                        
                        if folder.subfolders.count > 0 {
                            Text("\(folder.subfolders.count) folders")
                        }
                    }
                    .foregroundColor(.secondary)
                    .font(.footnote)
                }
                
                Spacer()
                
                Text(ByteCountFormatter.appFormatter.string(fromByteCount: folder.size))
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }
    
    @ViewBuilder
    private func imageLink(entry: ZIPEntry) -> some View {
        NavigationLink {
            ImageView(entry: entry, url: url)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "photo")
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.fileName)
                    
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
