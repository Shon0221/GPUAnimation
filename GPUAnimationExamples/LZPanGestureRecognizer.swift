//
//  LZPanGestureRecognizer.swift
//  GPUAnimationExamples
//
//  Created by YiLun Zhao on 2016-01-25.
//  Copyright © 2016 lkzhao. All rights reserved.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass


open class LZPanGestureRecognizer: UIPanGestureRecognizer {
  
  open var startViewCenterPoint:CGPoint?
  
  open var translatedViewCenterPoint:CGPoint{
    if let startViewCenterPoint = startViewCenterPoint{
      var p = startViewCenterPoint + translation(in: self.view!.superview!)
      p.x = clamp(p.x, range:xRange, overflowScale:xOverflowScale)
      p.y = clamp(p.y, range:yRange, overflowScale:yOverflowScale)
      return p
    }else{
      return self.view?.center ?? CGPoint.zero
    }
  }

  open func clamp(_ element: CGFloat, range:ClosedRange<CGFloat>, overflowScale:CGFloat = 0) -> CGFloat {
    if element < range.lowerBound{
      return range.lowerBound - (range.lowerBound - element)*overflowScale
    } else if element > range.upperBound{
      return range.upperBound + (element - range.upperBound)*overflowScale
    }
    return element
  }

  open var xOverflowScale:CGFloat = 0.3
  open var yOverflowScale:CGFloat = 0.3
  open var xRange:ClosedRange<CGFloat> = CGFloat.leastNormalMagnitude...CGFloat.greatestFiniteMagnitude
  open var yRange:ClosedRange<CGFloat> = CGFloat.leastNormalMagnitude...CGFloat.greatestFiniteMagnitude
  
  override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesBegan(touches, with: event)
    
    if state == .failed{
      return
    }

    startViewCenterPoint = self.view?.center
  }
  
}
