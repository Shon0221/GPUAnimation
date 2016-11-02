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

fileprivate struct GPUSpringAnimationState{
  // do not change the order of these variables
  // this struct is shared in Metal shader
  var current: float4 = float4()
  var target: float4
  var velocity: float4 = float4()
  var threshold: Float
  var stiffness: Float
  var damping: Float
  var running: Int32 = 1

  init(current c:float4, target t: float4, stiffness s:Float = 150, damping d:Float = 10, threshold th:Float = 0.01) {
    current = c
    target = t
    threshold = th
    stiffness = s
    damping = d
  }
}


fileprivate struct GPUTweenAnimationState{
  // do not change the order of these variables
  // this struct is shared in Metal shader
  var current: float4 = float4()
  var target: float4
  var previous: float4 = float4()
  var currentTime: Float = 0
  var duration: Float
  var curve: Curve
  var running: Int32 = 1
  
  init(target t: float4, duration d:Float, curve c:Curve) {
    target = t
    duration = d
    curve = c
  }
}

public typealias GPUAnimationGetter = () -> float4
public typealias GPUAnimationSetter = (float4) -> Void

fileprivate struct GPUAnimationMetaData{
  var getter:GPUAnimationGetter!
  var setter:GPUAnimationSetter!
  var completion:((Bool)->Void)?
  init(getter:@escaping GPUAnimationGetter, setter:@escaping GPUAnimationSetter, completion:((Bool)->Void)? = nil){
    self.getter = getter
    self.setter = setter
    self.completion = completion
  }
}

open class GPUSpringAnimator: NSObject {
  open static let sharedInstance = GPUSpringAnimator()
  
  private var displayLinkPaused:Bool{
    get{
      return displayLink == nil
    }
    set{
      newValue ? stop() : start()
    }
  }
  
  #if os(macOS)
    private var displayLink : CVDisplayLink?
  #elseif os(iOS)
    private var displayLink : CADisplayLink?
  #endif
  
  class AnimatingPropertyManager{
    class AnimationProperty{
      var animationIds = [Int]()
      var target:float4?
    }
    private var animatingProperties = [Int:[String:AnimationProperty]]()
    var currentAnimationIndex = 0
    func currentTargetFor(hash:Int, key:String) -> float4?{
      return animatingProperties[hash]?[key]?.target
    }
    func add(hash:Int, key:String, target:float4? = nil) -> Int{
      defer{ currentAnimationIndex+=1 }
      if animatingProperties[hash] == nil{
        animatingProperties[hash] = [String:AnimationProperty]()
      }
      if animatingProperties[hash]![key] == nil{
        animatingProperties[hash]![key] = AnimationProperty()
      }
      animatingProperties[hash]![key]!.target = target
      animatingProperties[hash]![key]!.animationIds.append(currentAnimationIndex)
      return currentAnimationIndex
    }
    @discardableResult func remove(hash:Int, key:String? = nil) -> [Int]?{
      if let key = key{
        return animatingProperties[hash]?.removeValue(forKey: key)?.animationIds
      } else {
        let rtn = list(hash: hash)
        animatingProperties.removeValue(forKey: hash)
        return rtn
      }
    }
    func list(hash:Int, key:String? = nil) -> [Int]?{
      if let key = key{
        return animatingProperties[hash]?[key]?.animationIds
      } else if let properties = animatingProperties[hash]?.values{
        return properties.map({ property in
          return property.animationIds
        }).flatMap{ $0 }
      }
      return nil
    }
    func springId(hash:Int, key:String) -> Int?{
      if let p = animatingProperties[hash]?[key], p.target == nil{
        return p.animationIds.first
      }
      return nil
    }
    func animationDone(hash:Int, key:String, id:Int){
      if let index = animatingProperties[hash]?[key]?.animationIds.index(of: id){
        animatingProperties[hash]![key]!.animationIds.remove(at: index)
        if animatingProperties[hash]![key]!.animationIds.count == 0 {
          remove(hash: hash, key: key)
        }
      }
    }
    func clear(){
      animatingProperties.removeAll()
      currentAnimationIndex = 0
    }
  }
  private var propertyManager = AnimatingPropertyManager()
  
  private var worker = GPUWorker()
  
  private var springAnimationBuffer = GPUBuffer<Int, GPUSpringAnimationState, GPUAnimationMetaData>()
  private var tweenAnimationBuffer = GPUBuffer<Int, GPUTweenAnimationState, GPUAnimationMetaData>()
  
  private var paramBuffer = GPUBuffer<String, Float, Any>(1)
  
  private var queuedCommands = [()->()]()
  private var dt:Float = 0
  private var processing = false
  
  private override init(){
    super.init()
    paramBuffer.content![0] = 0
    let springJob = GPUJob(functionName: "springAnimate", fallback:springFallback)
    springJob.addBuffer(buffer: springAnimationBuffer)
    springJob.addBuffer(buffer: paramBuffer)
    
    let tweenJob = GPUJob(functionName: "tweenAnimate", fallback:tweenFallback)
    tweenJob.addBuffer(buffer: tweenAnimationBuffer)
    tweenJob.addBuffer(buffer: paramBuffer)
    
    worker.jobs = [tweenJob, springJob]
    worker.completionCallback = doneProcessing
  }
  
  private func springFallback(job:GPUJob){
    let dt = paramBuffer.content![0]
    for (_, i) in springAnimationBuffer {
      let a = springAnimationBuffer.content!.baseAddress!.advanced(by: i)
      if (a.pointee.running == 0) { continue }
      
      let diff = a.pointee.current - a.pointee.target
      
      a.pointee.running = 0
      let absV = abs(a.pointee.velocity)
      let absD = abs(diff)
      for c in [absD.x,absD.y,absD.z,absD.w,absV.x,absV.y,absV.z,absV.w]{
        if c > a.pointee.threshold{
          a.pointee.running = 1
          break
        }
      }
      
      if a.pointee.running != 0 {
        let Fspring = (-a.pointee.stiffness) * diff;
        let Fdamper = (-a.pointee.damping) * a.pointee.velocity;
        
        let acceleration = Fspring + Fdamper;
        
        a.pointee.velocity = a.pointee.velocity + acceleration * dt;
        a.pointee.current = a.pointee.current + a.pointee.velocity * dt;
      } else {
        a.pointee.velocity = float4();
        a.pointee.current = a.pointee.target;
      }
    }
  }

  private func tweenFallback(job:GPUJob){
    let dt = paramBuffer.content![0]
    for (_, i) in tweenAnimationBuffer {
      let a = tweenAnimationBuffer.content!.baseAddress!.advanced(by: i)
      if (a.pointee.running == 0) { continue }
      a.pointee.currentTime += dt
      a.pointee.running = a.pointee.currentTime > a.pointee.duration ? 0 : 1
      a.pointee.previous = a.pointee.current
      if (a.pointee.running == 1) {
        let y = a.pointee.curve.solve(a.pointee.currentTime / a.pointee.duration)
        a.pointee.current = y * a.pointee.target
      } else {
        a.pointee.current = a.pointee.target
      }
    }
  }

  private func doneProcessing(){
    for (k, i) in springAnimationBuffer {
      let meta = springAnimationBuffer.metaDataFor(key: k)!
      meta.setter(springAnimationBuffer.content![i].current)
      if (springAnimationBuffer.content![i].running == 0) {
        springAnimationBuffer.remove(key: k)
        meta.completion?(true)
      }
    }
    
    for (k, i) in tweenAnimationBuffer {
      let meta = tweenAnimationBuffer.metaDataFor(key: k)!
      let newValue = meta.getter() + tweenAnimationBuffer.content![i].current - tweenAnimationBuffer.content![i].previous
      
      if (tweenAnimationBuffer.content![i].running == 0) {
        tweenAnimationBuffer.remove(key: k)
        meta.setter(newValue) // call setter after removing the animation. so that the velocity is zero
        meta.completion?(true)
      } else {
        meta.setter(newValue)
      }
    }
    
    processing = false
    for fn in queuedCommands{
      fn()
    }
    queuedCommands = []
  }
  
  private func update(duration:Float) {
    dt += duration
    if processing { return }
    
    if springAnimationBuffer.count == 0 && tweenAnimationBuffer.count == 0{
      displayLinkPaused = true
    } else {
      processing = true
//      for (k, i) in springAnimationBuffer {
//        springAnimationBuffer.content![i].current = springAnimationBuffer.metaDataFor(key: k)!.getter()
//      }

      paramBuffer.content![0] = dt
      dt = 0
      if (springAnimationBuffer.count != 0 || tweenAnimationBuffer.count != 0) { worker.process() }
    }
  }
  
  public func remove<T:Hashable>(_ item:T, key:String? = nil){
    let removeFn = {
//      print("Remove \(key)")
      if let ids = self.propertyManager.remove(hash: item.hashValue, key: key){
        for id in ids{
          self.springAnimationBuffer.metaDataFor(key: id)?.completion?(false)
          self.springAnimationBuffer.remove(key: id)
          self.tweenAnimationBuffer.metaDataFor(key: id)?.completion?(false)
          self.tweenAnimationBuffer.remove(key: id)
        }
      }
    }
    if processing {
      queuedCommands.append(removeFn)
    } else {
      removeFn()
    }
  }
  
  public func animate<T:Hashable>(_ item:T,
                    key:String,
                    getter:@escaping () -> float4,
                    setter:@escaping (float4) -> Void,
                    target:float4,
                    stiffness:Float = 200,
                    damping:Float = 10,
                    threshold:Float = 0.01,
                    completion:((Bool) -> Void)? = nil) {
    let insertFn = {
//      print("Spring \(key) \(target)")
      let hash = item.hashValue
      let metaData = GPUAnimationMetaData(getter:getter, setter:setter, completion:completion)
      var state = GPUSpringAnimationState(current: getter(), target: target, stiffness: stiffness, damping: damping, threshold: threshold)
      
      if let springId = self.propertyManager.springId(hash: hash, key: key), let index = self.springAnimationBuffer.indexOf(key: springId){
        state.velocity = self.springAnimationBuffer.content![index].velocity
      }
      
      // clear all existing animation. since spring doesn't addup with tween animations
      self.remove(hash, key: key)
      
      // generate a new id for our new spring animation
      let animationId = self.propertyManager.add(hash: hash, key: key)
      self.springAnimationBuffer.add(key: animationId, value: state, meta:metaData)
      if self.displayLinkPaused {
        self.displayLinkPaused = false
      }
    }
    if processing {
      queuedCommands.append(insertFn)
    } else {
      insertFn()
    }
  }
  
  public func animate<T:Hashable>(_ item:T,
                      key:String,
                      getter:@escaping () -> float4,
                      setter:@escaping (float4) -> Void,
                      target:float4,
                      duration:Float,
                      curve:Curve = .ease,
                      completion:((Bool) -> Void)? = nil) {
    let insertFn = {
//      print("Tween \(key) \(target)")
      let hash = item.hashValue
      let metaData = GPUAnimationMetaData(getter:getter, setter:setter, completion:completion)
      
      if let _ = self.propertyManager.springId(hash: hash, key: key){
        // currently running a spring animation, clear that one
        self.remove(hash, key: key)
      } else if let ids = self.propertyManager.list(hash: hash, key: key){
        // loop through existing animations and clear information for completed ones
        // this is needed so that we wont grab the incorrect target
        var count = ids.count
        for id in ids{
          if self.tweenAnimationBuffer.indexOf(key: id) == nil{
            self.propertyManager.animationDone(hash:hash, key:key, id:id)
            count -= 1;
          }
        }
        if count > 5{
          // Composing more than 5 animations is not supported, will stop all previous animations
          self.remove(hash, key: key)
        }
      }
      
      // For additive tween animation, we set the target to be the difference between the real target and the current target
      let initialValue = self.propertyManager.currentTargetFor(hash: hash, key: key) ?? getter()
      
      let state = GPUTweenAnimationState(target: target - initialValue, duration: duration, curve: curve)
      let animationId = self.propertyManager.add(hash: hash, key: key, target: target)
      self.tweenAnimationBuffer.add(key: animationId, value: state, meta:metaData)
      if self.displayLinkPaused {
        self.displayLinkPaused = false
      }
    }
    if processing {
      queuedCommands.append(insertFn)
    } else {
      insertFn()
    }
  }
  
  public func velocityFor<T:Hashable>(_ item:T, key:String) -> float4{
    let hash = item.hashValue
    if let springId = self.propertyManager.springId(hash: hash, key: key){
      let index = self.springAnimationBuffer.indexOf(key: springId)!
      return self.springAnimationBuffer.content![index].velocity
    } else if let ids = self.propertyManager.list(hash: hash, key: key) {
      var v = float4()
      for id in ids{
        if let index = self.tweenAnimationBuffer.indexOf(key: id){
          v += self.tweenAnimationBuffer.content![index].current - self.tweenAnimationBuffer.content![index].previous
        } else {
          self.propertyManager.animationDone(hash:hash, key:key, id:id)
        }
      }
      return v * (1 / paramBuffer.content![0])
    }
    return float4()
  }
  
  private func start() {
    if !displayLinkPaused {
      return
    }
    
    #if os(macOS)
      CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
      CVDisplayLinkSetOutputCallback(displayLink!, { (_, _, outTime, _, _, userInfo) -> CVReturn in
        let this = Unmanaged<GPUSpringAnimator>.fromOpaque(userInfo!).takeUnretainedValue()
        let out = outTime.pointee
        let duration = Float(1.0 / (out.rateScalar * Double(out.videoTimeScale) / Double(out.videoRefreshPeriod)))
        this.update(duration:duration)
        return kCVReturnSuccess
      }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
      CVDisplayLinkStart(displayLink!)
    #elseif os(iOS)
      displayLink = CADisplayLink(target: self, selector: #selector(updateIOS))
      displayLink!.add(to: RunLoop.main, forMode: RunLoopMode(rawValue: RunLoopMode.commonModes.rawValue))
    #endif
  }
  
  #if os(iOS)
  @objc private func updateIOS(){
    self.update(duration:Float(displayLink!.duration))
  }
  #endif
  
  private func stop() {
    if displayLinkPaused { return }
    springAnimationBuffer.clear()
    propertyManager.clear()
    #if os(macOS)
      CVDisplayLinkStop(displayLink!)
    #elseif os(iOS)
      displayLink!.isPaused = true
      displayLink!.remove(from: RunLoop.main, forMode: RunLoopMode(rawValue: RunLoopMode.commonModes.rawValue))
    #endif
    displayLink = nil
  }
}




