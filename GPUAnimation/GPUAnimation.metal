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

#include <metal_stdlib>
using namespace metal;

struct SpringAnimationState {
  float4 current;
  float4 target;
  float4 velocity;
  float threshold;
  float stiffness;
  float damping;
  int running;
};

kernel void springAnimate(
                          uint2 gid                           [[ thread_position_in_grid ]],
                          device SpringAnimationState* params [[ buffer(0) ]],
                          constant float *dt                  [[ buffer(1) ]]
                          )
{
  device SpringAnimationState *a = &params[gid.x];
  float4 diff = a->current - a->target;
  a->running = a->running && any(abs(a->velocity) > a->threshold || abs(diff) > a->threshold);

  float4 Fspring = (-a->stiffness) * diff;
  float4 Fdamper = (-a->damping) * a->velocity;

  float4 acceleration = Fspring + Fdamper;

  float4 newV = a->velocity + acceleration * dt[0];
  float4 newX = a->current + newV * dt[0];
  
  a->velocity = a->running ? newV : float4();
  a->current = a->running ? newX : a->target;
}



struct UnitBezier {
  float sampleCurveX(float t)
  {
    // `ax t^3 + bx t^2 + cx t' expanded using Horner's rule.
    return ((ax * t + bx) * t + cx) * t;
  }
  
  float sampleCurveY(float t)
  {
    return ((ay * t + by) * t + cy) * t;
  }
  
  float sampleCurveDerivativeX(float t)
  {
    return (3.0 * ax * t + 2.0 * bx) * t + cx;
  }
  
  // Given an x value, find a parametric value it came from.
  float solveCurveX(float x, float epsilon)
  {
    float t0;
    float t1;
    float t2;
    float x2;
    float d2;
    int i;
    
    // First try a few iterations of Newton's method -- normally very fast.
    for (t2 = x, i = 0; i < 8; i++) {
      x2 = sampleCurveX(t2) - x;
      if (fabs (x2) < epsilon)
        return t2;
      d2 = sampleCurveDerivativeX(t2);
      if (fabs(d2) < 1e-6)
        break;
      t2 = t2 - x2 / d2;
    }
    
    // Fall back to the bisection method for reliability.
    t0 = 0.0;
    t1 = 1.0;
    t2 = x;
    
    if (t2 < t0)
      return t0;
    if (t2 > t1)
      return t1;
    
    while (t0 < t1) {
      x2 = sampleCurveX(t2);
      if (fabs(x2 - x) < epsilon)
        return t2;
      if (x > x2)
        t0 = t2;
      else
        t1 = t2;
      t2 = (t1 - t0) * .5 + t0;
    }
    
    // Failure.
    return t2;
  }
  
  float solve(float x, float epsilon)
  {
    return sampleCurveY(solveCurveX(x, epsilon));
  }

  float ax;
  float bx;
  float cx;
  
  float ay;
  float by;
  float cy;
};

struct TweenAnimationState {
  float4 current;
  float4 target;
  float4 previous;
  float currentTime;
  float duration;
  UnitBezier bezier;
  int running;
};

kernel void tweenAnimate(
                          uint2 gid                           [[ thread_position_in_grid ]],
                          device TweenAnimationState* params  [[ buffer(0) ]],
                          constant float *dt                  [[ buffer(1) ]]
                          )
{
  device TweenAnimationState *a = &params[gid.x];
  
  a->currentTime += dt[0];
  a->running = a->running && a->currentTime < a->duration;

  a->previous = a->current;
  float y = ((UnitBezier)a->bezier).solve(a->currentTime / a->duration, 0.001 / a->duration);
  a->current = a->running ? y * a->target : a->target;
}
