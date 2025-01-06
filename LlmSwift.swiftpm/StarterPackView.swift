import SwiftUI

struct StarterPackView: View {
    @Binding var ready: Bool
    
    @ObservedObject private var viewModel = StarterPackViewModel()
    
    typealias LoadError = (ItemType, Error)
    @State private var loadError: LoadError?
    @State private var showLoadError = false
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Download all") {
                    viewModel.downloadAll()
                }
                .disabled(viewModel.oneItemsMissing || viewModel.nulItemsMissing)
            }
            ForEach(ItemType.allCases, id: \.self) { item in
                HStack {
                    Text(item.description)
                    Spacer()
                    switch viewModel.itemInfo[item]?.state {
                    case .missing, .none:
                        Button {
                            viewModel.download(item: item)
                        } label: {
                            Image(systemName: "icloud.and.arrow.down")
                                .foregroundColor(.accentColor)
                        }
                    case .loading:
                        ProgressView(value: viewModel.itemInfo[item]?.progress)
                            .frame(width: 64)
                    case .loaded:
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    case .failed(let error):
                        Image(systemName: "exclamationmark.icloud")
                            .foregroundColor(.red)
                            .contentShape(Circle())
                            .onTapGesture {
                                loadError = (item, error)
                                showLoadError = true
                            }
                    }
                }
                .padding(2)
            }
        }
        .padding()
        .onChange(of: viewModel.nulItemsMissing, initial: true) {
            if viewModel.nulItemsMissing { ready = true } else { ready = false }
        }
        .alert("Error loading \(loadError?.0.file ?? "nil")", isPresented: $showLoadError) {
            Button("Reset") {
                if let item = loadError?.0 {
                    viewModel.itemInfo[item]?.state = .missing
                }
            }
        } message: {
            if let error = loadError?.1 {
                let type = String(describing: type(of: error))
                let text = error.localizedDescription
                Text("Caught \(type) exception:\n\(text)")
            }
        }
    }
}

enum ItemType {
    case gpt2smallModel
    case gpt2debugModel
    case gpt2vocabulary
    case shakespeareTraining
    case shakespeareValidation
    
    static var allCases: [Self] {
        [.gpt2smallModel, .gpt2debugModel, .gpt2vocabulary, .shakespeareTraining, .shakespeareValidation]
    }
}

extension ItemType: CustomStringConvertible {
    var description: String {
        switch self {
        case .gpt2smallModel:
            return "GPT2 small model (124M)"
        case .gpt2debugModel:
            return "GPT2 small model (debug)"
        case .gpt2vocabulary:
            return "GPT2 tokenizer (vocabulary)"
        case .shakespeareTraining:
            return "Shakespeare training data"
        case .shakespeareValidation:
            return "Shakespeare validation data"
        }
    }
}

extension ItemType {
    var size: Int {
        switch self {
        case .gpt2smallModel:
            return 500_000_000
        case .gpt2debugModel:
            return 600_000_000
        case .gpt2vocabulary:
            return 400_000
        case .shakespeareTraining:
            return 700_000
        case .shakespeareValidation:
            return 100_000
        } 
    }
    
    var file: String {
        switch self {
        case .gpt2smallModel:
            return "gpt2_124M.bin"
        case .gpt2debugModel:
            return "gpt2_124M_debug_state.bin"
        case .gpt2vocabulary:
            return "gpt2_tokenizer.bin"
        case .shakespeareTraining:
            return "dev/data/tinyshakespeare/tiny_shakespeare_train.bin"
        case .shakespeareValidation:
            return "dev/data/tinyshakespeare/tiny_shakespeare_val.bin"
        } 
    }
    
    var remote: URL {
        let file = URL(string: self.file)!.lastPathComponent
        return URL(string: ItemType.site)!.appending(path: file)
    }
    
    static let site = "https://huggingface.co/datasets/karpathy/llmc-starter-pack/resolve/main"
}

enum ItemState {
    case missing
    case loading
    case loaded
    case failed(any Error)
}

struct ItemInfo {
    var state: ItemState
    var progress: Double
    
    // for brevity
    init(_ state: ItemState, _ progress: Double) {
        self.state = state
        self.progress = progress
    }
}

class StarterPackViewModel: ObservableObject {
    private var lock = NSLock()
    
    private var downloadHandler = DownloadHandler()
    @Published var itemInfo = [ItemType : ItemInfo]()
    
    @Published var nulItemsMissing = false
    @Published var oneItemsMissing = false
    
    var count: Int {
        var count = 0
        itemInfo.forEach { item in
            switch item.value.state {
            case .loaded:
                count += 1
            default:
                break
            }
        }
        return count
    }
    
    init() {
        let cwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(cwd) }
        
        FileManager.default.changeCurrentDirectoryPath(appFolder.path)
        
        ItemType.allCases.forEach { item in
            let fileExists = FileManager.default.fileExists(atPath: item.file)
            itemInfo[item] = fileExists ? ItemInfo(.loaded, 1) : ItemInfo(.missing, 0)
        }
        nulItemsMissing = count == 5
        oneItemsMissing = count == 4
    }
    
    func download(item: ItemType) {
        guard
            let attributesOfFileSystem = try? FileManager.default.attributesOfFileSystem(forPath: appFolder.path()),
            let systemFreeSize = attributesOfFileSystem[.systemFreeSize] as? Int
        else { return }
        if item.size > systemFreeSize {
            itemInfo[item]?.state = .failed(LlmSwiftError.noSpace)
            return
        }
        itemInfo[item]?.state = .loading
        downloadHandler.download(url: item.remote) { [self] url, error in
            if let error = error {
                Task { @MainActor in itemInfo[item]?.state = .failed(error) }
                return
            }
            guard
                let url = url
            else {
                Task { @MainActor in itemInfo[item]?.state = .failed(LlmSwiftError.apiReturnedNil(api: "download")) }
                return
            }
            let dst = appFolder.appending(path: item.file)
            try? FileManager.default.moveItem(at: url, to: dst, withIntermediateDirectories: true)
            Task { @MainActor in
                try await Task.sleep(nanoseconds: 1_000_000_000)
                itemInfo[item]?.state = .loaded
                nulItemsMissing = count == 5
                oneItemsMissing = count == 4
            }
        } progress: { [self] progress in
            Task { @MainActor in itemInfo[item]?.progress = progress }
        }
    }
    
    func downloadAll() {
        let cwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(cwd) }
        
        FileManager.default.changeCurrentDirectoryPath(appFolder.path)
        
        ItemType.allCases.forEach { item in
            if !FileManager.default.fileExists(atPath: item.file) {
                download(item: item)
            }
        }
    }
}

extension NSLock {
    func synchronize<T>(code: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try code()
    }
}

extension FileManager {
    func moveItem(at: URL, to: URL, withIntermediateDirectories createIntermediates: Bool) throws {
        if createIntermediates {
            let toDirectory = to.deletingLastPathComponent()
            if toDirectory.pathComponents.count > 0 && !fileExists(atPath: toDirectory.path()) {
                try createDirectory(at: toDirectory, withIntermediateDirectories: true)
            }
        }
        try moveItem(at: at, to: to)
    }
}
