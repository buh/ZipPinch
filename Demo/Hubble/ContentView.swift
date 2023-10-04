import SwiftUI

struct ContentView: View {
    @AppStorage("customURLString") var storedCustomURLString = ""
    @State private var customURL: URL?
    @State private var customURLString = ""
    @State private var showCustomURLTextField = false
    @State private var starsRotation = Angle.zero
    
    var body: some View {
        NavigationStack {
            ZStack {
                stars()
                
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
                .buttonStyle(.bordered)
                .padding(.bottom, 64)
            }
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
    
    @ViewBuilder
    private func imagesLink(title: String, subtitle: String, url: URL) -> some View {
        NavigationLink(destination: ImagesView(title: title, url: url)) {
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
