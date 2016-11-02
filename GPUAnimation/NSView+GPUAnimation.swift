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

#if os(macOS)
import AppKit
import MetalKit

extension NSColor:VectorConvertable{
  public var toVec4:float4 {
    if colorSpace == .genericGray{
      return [Float(whiteComponent),Float(whiteComponent),Float(whiteComponent),Float(alphaComponent)]
    }
    return [Float(redComponent),Float(greenComponent),Float(blueComponent),Float(alphaComponent)]
  }
  public static func fromVec4(_ values: float4) -> Self {
    return self.init(red: CGFloat(values[0]), green: CGFloat(values[1]), blue: CGFloat(values[2]), alpha: CGFloat(values[3]))
  }
}

extension NSView{
  var center:CGPoint{
    get{
      return frame.center
    }
    set{
      frame = CGRect(center: newValue, size: frame.size)
    }
  }
  @discardableResult public func delay(_ time:CFTimeInterval) -> ViewAnimationBuilder{
    return ViewAnimationBuilder(view: self).delay(time)
  }
  @discardableResult public func animate(_ block:@escaping (ViewAnimationState) -> Void) -> ViewAnimationBuilder{
    return ViewAnimationBuilder(view: self).animate(block)
  }
  public func stopAllAnimations(){
    return GPUSpringAnimator.sharedInstance.remove(self)
  }
}
#endif
