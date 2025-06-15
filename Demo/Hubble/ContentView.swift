import SwiftUI
import ZipPinch

// Navigation path for the archive browser
@Observable
class ArchiveNavigationModel {
    var selectedArchive: ArchiveSource?
    var currentFolder: ZIPFolder = .empty
    var selectedEntry: ZIPEntry?
    var navigationPath: [NavigationItem] = []
    
    enum NavigationItem: Hashable {
        case folder(ZIPFolder)
        case entry(ZIPEntry)
    }
}

struct ArchiveSource: Hashable {
    let title: String
    let subtitle: String
    let url: URL
}

struct ContentView: View {
    @AppStorage("customURLString") var storedCustomURLString = ""
    @State private var customURL: URL?
    @State private var customURLString = ""
    @State private var showCustomURLTextField = false
    @State private var starsRotation = Angle.zero
    @State private var navigationModel = ArchiveNavigationModel()
    
    var body: some View {
        Group {
            #if os(iOS)
            NavigationStack {
                menuContent()
            }
            #else
            NavigationSplitView {
                sidebarContent()
            } content: {
                contentView()
            } detail: {
                detailView()
            }
            .navigationSplitViewStyle(.balanced)
            #endif
        }
        .task {
            if !storedCustomURLString.isEmpty, let url = URL(string: storedCustomURLString) {
                customURL = url
            }
        }
        .alert("Enter your ZIP-file URL", isPresented: $showCustomURLTextField) {
            TextField("https://...", text: $customURLString)
            
            Button("Cancel", role: .cancel) {
                showCustomURLTextField = false
            }
            
            Button("Add") {
                if customURLString.hasPrefix("http"), let url = URL(string: customURLString) {
                    storedCustomURLString = customURLString
                    customURL = url
                }
            }
        }
    }
    
    // MARK: - iOS Content
    @ViewBuilder
    private func menuContent() -> some View {
        ZStack {
            stars()
            
            menuView()
                .buttonStyle(.bordered)
                .padding(.bottom, 64)
        }
        .navigationDestination(for: ArchiveSource.self) { archiveSource in
            ImagesView(title: archiveSource.title, url: archiveSource.url)
                .onAppear {
                    navigationModel.selectedArchive = archiveSource
                }
        }
        .navigationDestination(for: ZIPEntry.self) { entry in
            if let selectedArchive = navigationModel.selectedArchive {
                ImageView(entry: entry, url: selectedArchive.url)
            }
        }
    }
    
    // MARK: - macOS/iPadOS Sidebar
    @ViewBuilder
    private func sidebarContent() -> some View {
        List(selection: $navigationModel.selectedArchive) {
            Section("Archives") {
                archiveRow(
                    title: "Top 100 large images",
                    subtitle: "ZIP file 1.2 GB",
                    url: URL(string: "https://esahubble.org/static/images/zip/top100/top100-large.zip")!
                )
                
                archiveRow(
                    title: "Top 100 original images",
                    subtitle: "ZIP file 4.7 GB",
                    url: URL(string: "https://esahubble.org/static/images/zip/top100/top100-original.zip")!
                )
                
                if let customURL {
                    archiveRow(
                        title: customURL.lastPathComponent,
                        subtitle: customURL.host() ?? "",
                        url: customURL
                    )
                }
            }
            
            Section {
                Button("Add Custom ZIP URL") {
                    customURLString = ""
                    showCustomURLTextField = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Hubble")
    }
    
    @ViewBuilder
    private func archiveRow(title: String, subtitle: String, url: URL) -> some View {
        let source = ArchiveSource(title: title, subtitle: subtitle, url: url)
        
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .bold()
            
            Text(subtitle)
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .padding(.vertical, 4)
        .tag(source)
    }
    
    // MARK: - Content View (File Browser)
    @ViewBuilder
    private func contentView() -> some View {
        if let selectedArchive = navigationModel.selectedArchive {
            ArchiveBrowserView(
                archiveSource: selectedArchive,
                navigationModel: navigationModel
            )
        } else {
            ContentUnavailableView(
                "Select an Archive",
                systemImage: "folder.badge.plus",
                description: Text("Choose an archive from the sidebar to browse its contents")
            )
        }
    }
    
    // MARK: - Detail View (Image Viewer)
    @ViewBuilder
    private func detailView() -> some View {
        if let selectedEntry = navigationModel.selectedEntry,
           let selectedArchive = navigationModel.selectedArchive {
            ImageView(entry: selectedEntry, url: selectedArchive.url)
        } else {
            ContentUnavailableView(
                "No File Selected",
                systemImage: "photo",
                description: Text("Select a file from the content area to view it")
            )
        }
    }
    
    private func menuView() -> some View {
        VStack(spacing: 20) {
            Label("Hubble", systemImage: "bubbles.and.sparkles.fill")
                .font(.largeTitle.bold())
                .foregroundColor(.accentColor)
                .shadow(color: Color.accentColor, radius: 20)
                .padding(.bottom)
            
            imagesLink(
                title: "Top 100 large images",
                subtitle: "ZIP file 1.2 GB",
                url: URL(string: "https://esahubble.org/static/images/zip/top100/top100-large.zip")!
            )
            
            imagesLink(
                title: "Top 100 original images",
                subtitle: "ZIP file 4.7 GB",
                url: URL(string: "https://esahubble.org/static/images/zip/top100/top100-original.zip")!
            )
            
            Divider()
            
            if let customURL {
                imagesLink(
                    title: customURL.lastPathComponent,
                    subtitle: customURL.host() ?? "",
                    url: customURL
                )
            }
            
            Button("Try your ZIP-file URL") {
                customURLString = ""
                showCustomURLTextField = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func imagesLink(title: String, subtitle: String, url: URL) -> some View {
        NavigationLink(value: ArchiveSource(title: title, subtitle: subtitle, url: url)) {
            VStack(spacing: 4) {
                Text(title)
                    .bold()
                
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func stars() -> some View {
        ZStack {
            GeometryReader { proxy in
                let w = max(proxy.size.width, proxy.size.height)
                
                ForEach(0...100, id: \.self) { _ in
                    let s = CGFloat(Int.random(in: 10...30)) / 10
                    let o = Double(Int.random(in: 30 ... 100)) / 100
                    
                    Circle()
                        .fill(Color.white.opacity(o))
                        .frame(width: s, height: s)
                        .offset(x: CGFloat.random(in: 0...w), y: CGFloat.random(in: 0...w))
                        .shadow(color: Color.white.opacity(o), radius: 2 * s)
                }
            }
        }
        .drawingGroup()
        .rotationEffect(starsRotation)
        .task {
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                starsRotation = .degrees(360)
            }
        }
    }
}

// MARK: - Archive Browser View
struct ArchiveBrowserView: View {
    let archiveSource: ArchiveSource
    let navigationModel: ArchiveNavigationModel
    
    private let urlSession = URLSession(configuration: .default)
    @AppStorage("storedContentLength") var storedContentLength = 0
    @AppStorage("storedEntriesJSON") var storedEntriesJSON = ""
    @State private var entries = [ZIPEntry]()
    @State private var rootFolder: ZIPFolder = .empty
    @State private var currentFolder: ZIPFolder = .empty
    @State private var isLoading = false
    @State private var error: String?
    @State private var folderPath: [ZIPFolder] = []
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading archive...")
                    .progressViewStyle(.circular)
            } else if let error {
                ContentUnavailableView(
                    "Error Loading Archive",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                fileListView
            }
        }
        .navigationTitle(archiveSource.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if !folderPath.isEmpty {
                ToolbarItem(placement: .automatic) {
                    Button("Back") {
                        navigateBack()
                    }
                }
            }
        }
        .task {
            guard entries.isEmpty, rootFolder == .empty else { return }
            await loadEntries()
        }
        .onChange(of: archiveSource) { _, _ in
            // Reset when archive changes
            entries = []
            rootFolder = .empty
            currentFolder = .empty
            folderPath = []
            navigationModel.selectedEntry = nil
            Task {
                await loadEntries()
            }
        }
    }
    
    @ViewBuilder
    private var fileListView: some View {
        List {
            // Show folder metadata
            Section {
                folderMetaInfo(currentFolder == .empty ? rootFolder : currentFolder, isRoot: folderPath.isEmpty)
            }
            
            // Show subfolders
            ForEach(currentFolder == .empty ? rootFolder.subfolders : currentFolder.subfolders) { subfolder in
                Button {
                    navigateToFolder(subfolder)
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(subfolder.name)
                                .bold()
                            folderMetaInfo(subfolder)
                        }
                        
                        Spacer()
                        
                        Text(ByteCountFormatter.appFormatter.string(fromByteCount: subfolder.compressedSize))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Show files
            ForEach(currentFolder == .empty ? rootFolder.entries : currentFolder.entries) { entry in
                Button {
                    navigationModel.selectedEntry = entry
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                        
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
                }
                .buttonStyle(.plain)
            }
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
    
    private func navigateToFolder(_ folder: ZIPFolder) {
        folderPath.append(currentFolder == .empty ? rootFolder : currentFolder)
        currentFolder = folder
    }
    
    private func navigateBack() {
        guard !folderPath.isEmpty else { return }
        currentFolder = folderPath.removeLast()
        if folderPath.isEmpty {
            currentFolder = .empty
        }
    }
    
    private func loadEntries() async {
        do {
            isLoading = true
            
            let contentLength = try await urlSession.zipContentLength(
                from: archiveSource.url,
                cachePolicy: .returnCacheDataElseLoad
            )
            
            if contentLength == storedContentLength, !storedEntriesJSON.isEmpty {
                let entries = [ZIPEntry].decodeFromString(storedEntriesJSON)
                
                if !entries.isEmpty {
                    self.entries = entries
                    rootFolder = entries.rootFolder()
                    isLoading = false
                    print("📀 Returned cached entries: ", entries.count)
                    
                    // Pre-warm URLSession connection to prevent first-download delays
                    Task {
                        do {
                            _ = try await urlSession.zipContentLength(from: archiveSource.url, cachePolicy: .returnCacheDataElseLoad)
                        } catch {
                            // Silently ignore pre-warming errors
                        }
                    }
                    
                    return
                }
            }
            
            entries = try await urlSession.zipEntries(
                from: archiveSource.url,
                contentLength: contentLength,
                cachePolicy: .returnCacheDataElseLoad
            )
            
            rootFolder = entries.rootFolder()
            cacheEntries(contentLength: Int(contentLength))
            
        } catch let zipError as ZIPError {
            self.error = zipError.localizedDescription
            print("💥 ArchiveBrowserView:", zipError)
        } catch {
            self.error = error.localizedDescription
            print("💥 ArchiveBrowserView:", error)
        }
        
        isLoading = false
    }
    
    private func cacheEntries(contentLength: Int) {
        guard let json = try? entries.encodeToString(), !json.isEmpty else { return }
        
        storedEntriesJSON = json
        storedContentLength = contentLength
    }
}

// MARK: - Extensions
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

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
        #if os(macOS)
        .frame(width: 800, height: 800)
        #endif
}
