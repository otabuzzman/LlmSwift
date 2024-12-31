import Metal

enum LaunchPadError: Error {
    case apiReturnedNil(api: String)
    case miscellaneous(info: String)
}

extension LaunchPadError {
    var description: String {
        switch self {
        case .apiReturnedNil(let api):
            return "API \(api) returned nil"
        case .miscellaneous(let info):
            return "internal error: \(info)"
        }
    }
}

struct KernelContext {
    let threadsPerGrid: MTLSize
    let threadsPerGroup: MTLSize
}

protocol KernelParam {}
extension UnsafeMutableRawPointer: KernelParam {}
extension Float: KernelParam {}
extension Int32: KernelParam {}

struct LaunchPad {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    
    private let library: MTLLibrary
    
    private var kernel = [String : MTLComputePipelineState]()
    private var buffer = [MTLBuffer]()
    
    // transient objects
    private var command: MTLCommandBuffer? = nil
    private var encoder: MTLComputeCommandEncoder? = nil
}

extension LaunchPad {
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw LaunchPadError.apiReturnedNil(api: "MTLCreateSystemDefaultDevice")
        }
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            throw LaunchPadError.apiReturnedNil(api: "makeCommandQueue")
        }
        self.queue = queue
        // guard let library = device.makeDefaultLibrary() else {
        guard let library = try? device.makeLibrary(source: defaultLibrary, options: nil) else {
            throw LaunchPadError.apiReturnedNil(api: "makeDefaultLibrary")
        }
        self.library = library
        
        try makeTransientObjects()
    }
    
    private mutating func makeTransientObjects() throws -> Void {
        guard let command = queue.makeCommandBuffer() else {
            throw LaunchPadError.apiReturnedNil(api: "makeCommandBuffer")
        }
        self.command = command
        guard let encoder = command.makeComputeCommandEncoder() else {
            throw LaunchPadError.apiReturnedNil(api: "makeComputeCommandEncoder")
        }
        self.encoder = encoder
    }
    
    mutating func registerKernel(name: String) throws -> Void {
        guard let function = library.makeFunction(name: name) else {
            throw LaunchPadError.apiReturnedNil(api: "makeFunction \(name)")
        }
        let pipeline = try device.makeComputePipelineState(function: function)
        self.kernel[name] = pipeline
    }
    
    @discardableResult
    mutating func registerBuffer(address: UnsafeMutableRawPointer, length: Int) throws -> Int {
        guard
            let buffer = device.makeBuffer(bytesNoCopy: address, length: length, options: [.storageModeShared])
        else { throw LaunchPadError.apiReturnedNil(api: "makeBuffer") }
        self.buffer.append(buffer)
        
        return self.buffer.endIndex - 1
    }
    
    private func lookupBuffer(for address: UnsafeMutableRawPointer) throws -> (Int, UnsafeMutableRawPointer) {
        for index in 0..<buffer.count {
            let bufferBaseAddress = buffer[index].contents()
            let bufferLastAddress = bufferBaseAddress + buffer[index].length
            if (bufferBaseAddress..<bufferLastAddress).contains(address) {
                return (index, bufferBaseAddress)
            }
        }
        throw LaunchPadError.miscellaneous(info: "no buffer found")
    } 
    
    func dispatchKernel(name: String, context: KernelContext, params: [KernelParam]) throws -> Void {
        guard
            let kernel = self.kernel[name]
        else { throw LaunchPadError.miscellaneous(info: "kernel \(name) not registered") }
        encoder?.setComputePipelineState(kernel)
        
        var index = 0
        for param in params {
            switch param {
            case is UnsafeMutableRawPointer:
                let address = param as! UnsafeMutableRawPointer
                let (bufferIndex, bufferAddress) = try lookupBuffer(for: address)
                let offset = address - bufferAddress
                encoder?.setBuffer(buffer[bufferIndex], offset: offset, index: index)
                index += 1
                break
            case is Float:
                var scalar = param as! Float
                encoder?.setBytes(&scalar, length: MemoryLayout<Float>.stride, index: index)
                index += 1
                break
            case is Int32:
                var scalar = param as! Int32
                encoder?.setBytes(&scalar, length: MemoryLayout<Int32>.stride, index: index)
                index += 1
                break
            default:
                break
            }
        }
        
        encoder?.dispatchThreadgroups(context.threadsPerGrid, threadsPerThreadgroup: context.threadsPerGroup)
    }
    
    mutating func commit(wait: Bool = false) throws -> Void {
        encoder?.endEncoding()
        
        command?.commit()
        if wait { command?.waitUntilCompleted() }
        
        try makeTransientObjects()
    }
}