import Foundation

struct DownloadHandle {
    let url: URL
    let progress: ((Double) -> Void)?
    let completion: ((URL?, Error?) -> Void)?
}

// handle multiple downloads
class DownloadHandler: NSObject, URLSessionDownloadDelegate {
    private var session: URLSession!
    private var handles: [URLSessionDownloadTask: DownloadHandle] = [:]
    
    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    func download(url: URL, completion: ((URL?, Error?) -> Void)? = nil, progress: ((Double) -> Void)? = nil) {
        let handle = DownloadHandle(url: url, progress: progress, completion: completion)
        let task = session.downloadTask(with: url)
        handles[task] = handle
        task.resume()
    }

    // URLSessionDownloadDelegate: completion
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo temporary: URL) {
        guard let downloadHandle = handles[downloadTask] else { return }
        
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let permanent = temporaryDirectory.appendingPathComponent(downloadHandle.url.lastPathComponent)
        
        do {
            if FileManager.default.fileExists(atPath: permanent.path()) {
                try FileManager.default.removeItem(at: permanent)
            }
            try FileManager.default.moveItem(at: temporary, to: permanent)
            downloadHandle.completion?(permanent, nil)
        } catch {
            downloadHandle.completion?(nil, error)
        }
        
        handles.removeValue(forKey: downloadTask)
    }
    
    // URLSessionDownloadDelegate: progress
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let downloadHandle = handles[downloadTask] else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        downloadHandle.progress?(progress)
    }
    
    // URLSessionDownloadDelegate: error
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, let downloadHandle = handles[task as! URLSessionDownloadTask] {
            downloadHandle.completion?(nil, error)
            handles.removeValue(forKey: task as! URLSessionDownloadTask)
        }
    }
}
