import SwiftUI
import CircularBuffer

let appFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

struct ContentView: View {
    @State private var showFolderPicker = false
    @State private var stdlog = CircularBuffer<String>(capacity: 1024)
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State var isSidebarPresented = false
    @State var starterPackReady = false
    
    @State var longRunTask: Task<Void, Never>?
    @State var longRunBusy = false
    @State var cancellationRequestPending = false
    
    var starterPackView: some View {
        VStack {
            StarterPackView(ready: $starterPackReady)
            Spacer()
        }
    }
    
    var controlView: some View {
        HStack {
            Spacer()
            Button {
                longRunTask = Task { @MainActor in
                    longRunBusy = true
                    do {
                        try await test_gpt2(appFolder, { stdlog.pushBack($0) })
                    } catch { stdlog.pushBack("Exception: \(error.localizedDescription)\n") }
                    longRunBusy = false
                }
            } label: {
                Image(systemName: "checkmark.circle.badge.questionmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 32)
            }
            .disabled(!starterPackReady || longRunBusy)
            Button {
                longRunTask = Task { @MainActor in
                    longRunBusy = true
                    do {
                        try await train_gpt2(appFolder, { stdlog.pushBack($0) })
                    } catch { stdlog.pushBack("Exception: \(error.localizedDescription)\n") }
                    longRunBusy = false
                }
            } label: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 32)
            }
            .disabled(!starterPackReady || longRunBusy)
        }
        .padding()
    }
    
    var consoleView: some View {
        VStack {
            ScrollView {
                Text("\(String(describing: stdlog.joined()))")
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle("LlmSwift")
            Button("Cancel", role: .destructive) {
                cancellationRequestPending = true
                Task { @MainActor in
                    longRunTask?.cancel()
                    let _ = await longRunTask?.value
                    cancellationRequestPending = false
                }
            }
            .disabled(!longRunBusy)
        }
        .padding()
    }
    
    var regularView: some View {
        NavigationSplitView {
            starterPackView
        } detail: {
            VStack {
                controlView
                consoleView
            }
        }
    }
    
    var compactView: some View {
        NavigationStack {
            VStack {
                controlView
                consoleView
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sidebar", systemImage: "sidebar.left") {
                        isSidebarPresented = true
                    }
                }
            }
            .sheet(isPresented: $isSidebarPresented) {
                NavigationStack {
                    starterPackView
                        .navigationTitle("LlmSwift")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    isSidebarPresented = false
                                }
                            }
                        }
                }
            }
        }
    }
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularView
            } else {
                compactView
            }
        }
        .sheet(isPresented: $cancellationRequestPending) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .foregroundColor(.white)
                ProgressView()
            }
            .frame(width: 64, height: 64)
            .presentationBackground(.clear)
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPicker { result in
                switch result {
                case .success(let folder):
                    folder.accessSecurityScopedResource { folder in
                        setAppFolder(url: folder)
                    }
                default: // .failure(let error)
                    break
                }
            }
        }
    }
}

extension URL {
    func accessSecurityScopedResource(_ accessor: (URL) -> Void) -> Void {
        let didStartAccessing = startAccessingSecurityScopedResource()
        defer { if didStartAccessing { stopAccessingSecurityScopedResource() } }
        accessor(self)
    }
    
    // https://developer.apple.com/documentation/foundation/nsurl#1663783
    func obtainSecurityScopedResource() -> URL? {
        var securityScopedUrl: URL?
        if let bookmark = try? self.bookmarkData(options: [/* .withSecurityScope */]) {
            var isStale = false
            securityScopedUrl = try? URL(
                resolvingBookmarkData: bookmark,
                options: [/* .withSecurityScope */],
                bookmarkDataIsStale: &isStale)
        }
        return securityScopedUrl
    }
}

internal func setAppFolder(url: URL) {
    guard
        let bookmark = try? url.bookmarkData(options: [/* .withSecurityScope */])
    else { return }
    UserDefaults.standard.set(bookmark, forKey: "appFolder")
}

internal func getAppFolder() -> URL? {
    var isStale = false
    guard
        let bookmark = UserDefaults.standard.object(forKey: "appFolder") as? Data,
        let appFolder = try? URL(
            resolvingBookmarkData: bookmark,
            options: [/* .withSecurityScope */],
            bookmarkDataIsStale: &isStale)
    else { return nil }
    if isStale { setAppFolder(url: appFolder) }
    return appFolder
}

@main
struct LlmSwift: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
