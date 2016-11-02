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


import Foundation

public enum TweenType:Int32 { case linear = 0;
                       case quadratic;
                       case cubic;
                       case quartic;
                       case quintic;
                       case sine;
                       case circular;
                       case exponential;
                       case elastic;
                       case back;
                       case bounce; };

public enum EaseType:Int32 { case easeIn = 0; case easeOut; case easeInOut };

public struct Curve {
  
  public static let linear = Curve(type:.linear, ease:.easeIn)
  public static let ease = Curve(type:.sine, ease:.easeInOut)
  public static let elastic = Curve(type:.elastic, ease:.easeOut)
  public static let bounce = Curve(type:.bounce, ease:.easeOut)
  
  
  private var rawType:Int32 = TweenType.sine.rawValue
  private var rawEase:Int32 = EaseType.easeIn.rawValue

  public var type:TweenType{
    get {
      return TweenType(rawValue: rawType)!
    }
    set {
      rawType = type.rawValue
    }
  }
  public var ease:EaseType{
    get {
      return EaseType(rawValue: rawEase)!
    }
    set {
      rawEase = ease.rawValue
    }
  }
  
  public init(type:TweenType, ease:EaseType){
    rawType = type.rawValue
    rawEase = ease.rawValue
  }

  func solveEaseIn(_ p:Float) -> Float{
    var t = p
    switch (TweenType(rawValue: rawType)!) {
      case .linear:
        return t;
      case .quadratic:
        return t*t;
      case .cubic:
        return t*t*t;
      case .quartic:
        return t*t*t*t;
      case .quintic:
        return t*t*t*t*t;
      case .sine:
        return sin((t - 1) * Float(M_PI) / 2) + 1;
      case .circular:
        return 1 - sqrt(1 - (t * t));
      case .exponential:
        return (t == 0.0) ? t : pow(2, 10 * (t - 1));
      case .elastic:
        return sin(13 * Float(M_PI) / 2 * t) * pow(2, 10 * (t - 1));
      case .back:
        return t*t*t - t*sin(t * Float(M_PI));
      case .bounce:
        t = 1 - t;
        if (t < 1/2.75) {
          return 1 - (7.5625*t*t);
        } else if (t < (2/2.75)) {
          t -= 1.5/2.75;
          return 1 - (7.5625*t*t + 0.75);
        } else if (t < (2.5/2.75)) {
          t -= 2.25/2.75;
          return 1 - (7.5625*t*t + 0.9375);
        } else {
          t -= 2.625/2.75;
          return 1 - (7.5625*t*t + 0.984375);
        }
    }
  }
  func solveEaseOut(_ t:Float) -> Float{
    return 1 - solveEaseIn(1 - t);
  }
  func solve(_ t:Float) -> Float{
    switch (EaseType(rawValue: rawEase)!) {
      case .easeIn:
        return solveEaseIn(t);
      case .easeOut:
        return solveEaseOut(t);
      case .easeInOut:
        if t < 0.5 {
          return 0.5 * solveEaseIn(t*2);
        } else {
          return 0.5 * solveEaseOut(t * 2 - 1) + 0.5;
        }
    }
  }
}

