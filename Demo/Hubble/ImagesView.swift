import SwiftUI
import ZipPinch

struct ImagesView: View {
    
    let title: String
    let url: URL
    private let urlSession = URLSession(configuration: .default)
    @AppStorage("storedContentLength") var storedContentLength = 0
    @AppStorage("storedEntriesJSON") var storedEntriesJSON = ""
    @State private var entries = [ZIPEntry]()
    @State private var rootFolder: ZIPFolder
    @State private var hoveredEntry: ZIPEntry?
    @State private var isLoading = false
    @State private var error: String?
    @State private var progress: Double = 0
    @State private var progressFolderId: UUID?
    @State private var folderDownloadingTask: Task<(), Error>?
    
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
            await loadEntries()
        }
    }
    
    @ViewBuilder
    private var folderView: some View {
        List {
            Section {
                HStack {
                    folderMetaInfo(rootFolder, isRoot: true)
                }
            }
            
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
            ZStack(alignment: .bottom) {
                HStack(spacing: 16) {
                    Image(systemName: "folder")
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(folder.name)
                        folderMetaInfo(folder)
                    }
                    
                    Spacer()
                    
                    Text(ByteCountFormatter.appFormatter.string(fromByteCount: folder.compressedSize))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                if progressFolderId == folder.id {
                    ProgressView(value: progress)
                        .offset(y: 10)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(action: {
                folderDownloadingTask?.cancel()
                folderDownloadingTask = Task {
                    progressFolderId = folder.id
                    
                    do {
                        _ = try await urlSession.zipFolderData(
                            folder, from: url,
                            progress: .init(callback: { value in
                                Task { @MainActor in
                                    self.progress = value
                                    
                                    if value == 1 {
                                        self.progressFolderId = nil
                                    }
                                }
                            })
                        )
                    } catch let zipError as ZIPError {
                        self.error = zipError.localizedDescription
                        print("💥 ImagesView:", zipError)
                    } catch {
                        self.error = error.localizedDescription
                        print("💥 ImagesView:", error)
                    }
                }
            }, label: {
                Image(systemName: "arrow.down.circle.fill")
            })
        }
        .onDisappear {
            folderDownloadingTask?.cancel()
        }
    }
    
    @ViewBuilder
    private func folderMetaInfo(_ folder: ZIPFolder, isRoot: Bool = false) -> some View {
        Group {
            HStack(spacing: 8) {
                if folder.subfolders.count > 0 {
                    Text("\(folder.subfolders.count) folder(s)")
                }
                
                if folder.entries.count > 0 {
                    Text("\(folder.entries.count) file(s)")
                }
            }
            
            if isRoot {
                Spacer()
            }
            
            Text("\(folder.lastModificationDate, format: .dateTime)")
        }
        .foregroundColor(.secondary)
        .font(.footnote)
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
                    
                    Text("\(entry.fileLastModificationDate, format: .dateTime)")
                        .foregroundColor(.secondary)
                        .font(.footnote)
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

private extension ImagesView {
    func loadEntries() async {
        do {
            isLoading = true
            
            let contentLength = try await urlSession.zipContentLength(
                from: url,
                cachePolicy: .returnCacheDataElseLoad
            )
            
            if contentLength == storedContentLength, !storedEntriesJSON.isEmpty {
                let entries = [ZIPEntry].decodeFromString(storedEntriesJSON)
                
                if !entries.isEmpty {
                    self.entries = entries
                    rootFolder = entries.rootFolder()
                    isLoading = false
                    print("📀 Returned cached entries: ", entries.count)
                    return
                }
            }
            
            entries = try await urlSession.zipEntries(
                from: url,
                contentLength: contentLength,
                cachePolicy: .returnCacheDataElseLoad
            )
            
            rootFolder = entries.rootFolder()
            cacheEntries(contentLength: Int(contentLength))
            
        } catch let zipError as ZIPError {
            self.error = zipError.localizedDescription
            print("💥 ImagesView:", zipError)
        } catch {
            self.error = error.localizedDescription
            print("💥 ImagesView:", error)
        }
        
        isLoading = false
    }
    
    private func cacheEntries(contentLength: Int) {
        guard let json = try? entries.encodeToString(), !json.isEmpty else { return }
        
        storedEntriesJSON = json
        storedContentLength = contentLength
    }
}

private extension [ZIPEntry] {
    func encodeToString() throws -> String {
        let jsonData = try JSONEncoder().encode(self)
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
    
    static func decodeFromString(_ json: String) -> [ZIPEntry] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([ZIPEntry].self, from: data)) ?? []
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
