//
//  Bezier.swift
//  GPUAnimationExamples
//
//  Created by Luke Zhao on 2016-10-31.
//  Copyright © 2016 lkzhao. All rights reserved.
//

import Foundation



public struct UnitBezier {
  var ax:Float;
  var bx:Float;
  var cx:Float;
  
  var ay:Float;
  var by:Float;
  var cy:Float;
  
  public static let easeInSine = UnitBezier(0.47,0,0.745,0.715)
  public static let easeOutSine = UnitBezier(0.39,0.575,0.565, 1)
  public static let easeInOutSine = UnitBezier(0.455,0.03,0.515,0.955)
  public static let easeInQuad = UnitBezier(0.55, 0.085, 0.68, 0.53)
  public static let easeOutQuad = UnitBezier(0.25, 0.46, 0.45, 0.94)
  public static let easeInOutQuad = UnitBezier(0.455, 0.03, 0.515, 0.955)
  public static let easeInCubic = UnitBezier(0.55, 0.055, 0.675, 0.19)
  public static let easeOutCubic = UnitBezier(0.215, 0.61, 0.355, 1)
  public static let easeInOutCubic = UnitBezier(0.645, 0.045, 0.355, 1)
  public static let easeInQuart = UnitBezier(0.895, 0.03, 0.685, 0.22)
  public static let easeOutQuart = UnitBezier(0.165, 0.84, 0.44, 1)
  public static let easeInOutQuart = UnitBezier(0.77, 0, 0.175, 1)
  public static let easeInQuint = UnitBezier(0.755, 0.05, 0.855, 0.06)
  public static let easeOutQuint = UnitBezier(0.23, 1, 0.32, 1)
  public static let easeInOutQuint = UnitBezier(0.86,0,0.07,1)
  public static let easeInExpo = UnitBezier(0.95, 0.05, 0.795, 0.035)
  public static let easeOutExpo = UnitBezier(0.19, 1, 0.22, 1)
  public static let easeInOutExpo = UnitBezier(1, 0, 0, 1)
  public static let easeInCirc = UnitBezier(0.6, 0.04, 0.98, 0.335)
  public static let easeOutCirc = UnitBezier(0.075, 0.82, 0.165, 1)
  public static let easeInOutCirc = UnitBezier(0.785, 0.135, 0.15, 0.86)
  public static let easeInBack = UnitBezier(0.6, -0.28, 0.735, 0.045)
  public static let easeOutBack = UnitBezier(0.175, 0.885, 0.32, 1.275)
  public static let easeInOutBack = UnitBezier(0.68, -0.55, 0.265, 1.55)

  init(_ p1x:Float, _ p1y:Float, _ p2x:Float, _ p2y:Float){
    // Calculate the polynomial coefficients, implicit first and last control points are (0,0) and (1,1).
    cx = 3.0 * p1x
    bx = 3.0 * (p2x - p1x) - cx
    ax = 1.0 - cx - bx
    
    cy = 3.0 * p1y
    by = 3.0 * (p2y - p1y) - cy
    ay = 1.0 - cy - by
  }
  
  func sampleCurveX(_ t: Float) -> Float {
    return ((ax * t + bx) * t + cx) * t
  }
  
  func sampleCurveY(_ t: Float) -> Float {
    return ((ay * t + by) * t + cy) * t
  }
  
  func sampleCurveDerivativeX(_ t: Float) -> Float {
    return (3.0 * ax * t + 2.0 * bx) * t + cx
  }
  
  func solveCurveX(x: Float, eps: Float) -> Float {
    var t0: Float = 0.0
    var t1: Float = 0.0
    var t2: Float = 0.0
    var x2: Float = 0.0
    var d2: Float = 0.0
    
    // First try a few iterations of Newton's method -- normally very fast.
    t2 = x
    for _ in 0..<8 {
      x2 = sampleCurveX(t2) - x
      if abs(x2) < eps {
        return t2
      }
      d2 = sampleCurveDerivativeX(t2)
      if abs(d2) < 1e-6 {
        break
      }
      t2 = t2 - x2 / d2
    }
    
    // Fall back to the bisection method for reliability.
    t0 = 0.0
    t1 = 1.0
    t2 = x
    
    if t2 < t0 {
      return t0
    }
    if t2 > t1 {
      return t1
    }
    
    while t0 < t1 {
      x2 = sampleCurveX(t2)
      if abs(x2-x) < eps {
        return t2
      }
      if x > x2 {
        t0 = t2
      } else {
        t1 = t2
      }
      t2 = (t1-t0) * 0.5 + t0
    }
    
    return t2
  }
  
  func solve(x: Float, eps: Float) -> Float {
    return sampleCurveY(solveCurveX(x: x, eps: eps))
  }
}

