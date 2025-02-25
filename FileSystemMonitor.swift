import SwiftUI

class FileSystemMonitor {
    let perform: () -> ()
    
    let handle: FileHandle
    let source: DispatchSourceFileSystemObject
    
    init(for file: URL, perform: @escaping () -> ()) throws {
        self.perform = perform
        handle = try FileHandle(forReadingFrom: file)
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: handle.fileDescriptor, eventMask: .all, queue: .main)
        source.setEventHandler(handler: perform)
        source.setCancelHandler(handler: { try? self.handle.close() })
        source.resume()
    }
    
    deinit { source.cancel() }
}
