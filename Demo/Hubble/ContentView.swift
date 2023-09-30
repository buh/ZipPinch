import SwiftUI

struct ContentView: View {
    
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
                    
                    Text("Top 100 Images")
                        .padding(.bottom)
                        .foregroundColor(.secondary)
                    
                    NavigationLink(destination: ImagesView(
                        title: "Top 100 (Large)",
                        url: URL(string: "https://esahubble.org/static/images/zip/top100/top100-large.zip")!
                    )) {
                        Text("Large Size (ZIP file, 1.2Gb)")
                            .bold()
                            .font(.callout)
                            .padding()
                    }
                    NavigationLink(destination: ImagesView(
                        title: "Top 100 (Original)",
                        url: URL(string: "https://esahubble.org/static/images/zip/top100/top100-original.zip")!
                    )) {
                        Text("Original Size (ZIP file, 4.7Gb)")
                            .bold()
                            .font(.callout)
                            .padding()
                    }
                }
                .buttonStyle(.bordered)
                .padding(.bottom, 64)
            }
        }
    }
    
    @ViewBuilder
    private func stars() -> some View {
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
        .drawingGroup()
        .rotationEffect(starsRotation)
        .onAppear {
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
