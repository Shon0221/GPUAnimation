// The MIT License (MIT)
//
// Copyright (c) 2015 Luke Zhao <me@lkzhao.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import MetalKit

private class Shared {
  static var device: MTLDevice! = MTLCreateSystemDefaultDevice()
  static var queue: MTLCommandQueue! = device?.makeCommandQueue()
  static var metalAvaliable:Bool{
    return library != nil
  }
  static var library: MTLLibrary! = {
    if let device = device, let path = Bundle(for:Shared.self).path(forResource: "default", ofType: "metallib"){
      return try? device.makeLibrary(filepath: path)
    }
    return nil
  }()
}

public protocol GPUBufferType {
  var buffer: MTLBuffer? { get }
  var capacity: Int { get }
}

open class GPUBuffer<Key:Hashable, Value, MetaData>:Sequence, GPUBufferType {
  public func makeIterator() -> DictionaryIterator<Key, Int> {
    return managed.makeIterator()
  }

  public var content: UnsafeMutableBufferPointer<Value>? = nil
  public var buffer: MTLBuffer? = nil

  private var freeIndexes:[Int] = []
  private var managed:[Key:Int] = [:]
  private var metaData:[MetaData?] = []
  
  public var capacity:Int{
    return content?.count ?? 0
  }
  
  public var count:Int{
    return managed.count
  }
  
  public init(_ size:Int = 0){
    if (size == 0) {
      clear()
    } else {
      resize(size:size)
    }
  }
  
  public func indexOf(key:Key) -> Int? {
    return managed[key]
  }

  public func remove(key:Key){
    if let i = managed[key] {
      managed[key] = nil
      metaData[i] = nil
      freeIndexes.append(i)
    }
  }
  
  public func add(key:Key, value:Value, meta:MetaData? = nil){
    if let i = managed[key] {
      metaData[i] = meta
      content![i] = value
    } else {
      if freeIndexes.count == 0 {
        resize(size: (content?.count ?? 1) * 2)
      }
      let i = freeIndexes.popLast()!
      managed[key] = i
      metaData[i] = meta
      content![i] = value
    }
  }
  
  public func metaDataFor(key:Key) -> MetaData?{
    if let i = managed[key] {
      return metaData[i]
    }
    return nil
  }
  
  public func clear(){
    content = nil
    buffer = nil
    freeIndexes = []
    managed = [:]
    metaData = []
  }

  public func resize(size:Int){
    let oldSize = capacity
    if Shared.metalAvaliable {
      let newBuffer: MTLBuffer = Shared.device.makeBuffer(length: MemoryLayout<Value>.size * size, options: [.storageModeShared])
      if buffer != nil {
        // copy one extra block just to be safe.
        memcpy(newBuffer.contents(), buffer!.contents(), Swift.min(size * MemoryLayout<Value>.size, buffer!.length + MemoryLayout<Value>.size))
      }
      buffer = newBuffer
      content = UnsafeMutableBufferPointer(start: buffer!.contents().assumingMemoryBound(to: Value.self), count: buffer!.length / MemoryLayout<Value>.size)
    } else {
      let newLoc = UnsafeMutablePointer<Value>.allocate(capacity: size)
      if content != nil {
        memcpy(newLoc, content!.baseAddress, content!.count * MemoryLayout<Value>.size)
        content!.baseAddress!.deinitialize(count: content!.count)
        content!.baseAddress!.deallocate(capacity: content!.count)
      }
      content = UnsafeMutableBufferPointer(start: newLoc, count: size)
    }
    for i in oldSize..<content!.count{
      freeIndexes.append(i)
      metaData.append(nil)
    }
  }
}

open class GPUJob{
  var computeFn: MTLFunction!
  var computePS: MTLComputePipelineState!
  var buffers:[GPUBufferType] = []
  public var fallbackFunction:((GPUJob)->Void)?
  
  public init(functionName:String, fallback:((GPUJob)->Void)? = nil) {
    self.fallbackFunction = fallback
    if Shared.metalAvaliable {
      computeFn = Shared.library.makeFunction(name: functionName)
      computePS = try! Shared.device.makeComputePipelineState(function: computeFn!)
    } else if _isDebugAssertConfiguration() {
      print("GPUAnimation: Metal Not Avaliable, using fallback function for \(functionName)")
    }
  }
  
  public func addBuffer<K: Hashable,V,M>(buffer:GPUBuffer<K,V,M>){
    buffers.append(buffer)
  }
}
open class GPUWorker {
  var jobs = [GPUJob]()
  var threadExecutionWidth:Int = 32
  public var completionCallback:(()->Void)?
  var processing = false
  var commandBuffer:MTLCommandBuffer!

  public init() {}

  public func process(){
    processing = true
    
    if Shared.metalAvaliable{
      commandBuffer = Shared.queue.makeCommandBuffer()
      for job in jobs{
        let size = job.buffers.first!.capacity
        if size == 0 {
          continue
        }
        let width = min(size, job.computePS.threadExecutionWidth)
        let computeCE = commandBuffer.makeComputeCommandEncoder()
        computeCE.setComputePipelineState(job.computePS)
        for (i, buffer) in job.buffers.enumerated() {
          computeCE.setBuffer(buffer.buffer, offset: 0, at: i)
        }
        
        computeCE.dispatchThreadgroups(MTLSize(width: size/width, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1))
        computeCE.endEncoding()
      }
      commandBuffer.addCompletedHandler(self.doneProcessing)
      commandBuffer.commit()
    } else {
      for job in jobs{
        job.fallbackFunction?(job)
      }
      processing = false
      completionCallback?()
    }
  }
  
  private func doneProcessing(buffer:MTLCommandBuffer){
    processing = false
    if let e = buffer.error{
      print(e)
    } else {
      DispatchQueue.main.async {
        self.completionCallback?()
      }
    }
  }
}
