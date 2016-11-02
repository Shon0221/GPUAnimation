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

#define M_PI   3.14159265358979323846264338327950288

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



enum TweenType:int { linear = 0,
                     quadratic, 
                     cubic, 
                     quartic, 
                     quintic, 
                     sine, 
                     circular, 
                     exponential, 
                     elastic, 
                     back, 
                     bounce };
  
enum EaseType:int { in = 0, out, inOut };

struct Curve {
  TweenType type;
  EaseType ease;
  float easeIn(float t){
    switch (type) {
      case linear:
        return t;
      case quadratic:
        return t*t;
      case cubic:
        return t*t*t;
      case quartic:
        return t*t*t*t;
      case quintic:
        return t*t*t*t*t;
      case sine:
        return sin((t - 1) * M_PI / 2) + 1;
      case circular:
        return 1 - sqrt(1 - (t * t));
      case exponential:
        return (t == 0.0) ? t : pow(2, 10 * (t - 1));
      case elastic:
        return sin(13 * M_PI / 2 * t) * pow(2, 10 * (t - 1));
      case back:
        return t*t*t - t*sin(t * M_PI);
      case bounce:
        t = 1 - t;
        if (t < 1/2.75) {
          return 1 - (7.5625*t*t);
        } else if (t < (2/2.75)) {
          t -= 1.5/2.75;
          return 1 - (7.5625*t*t + .75);
        } else if (t < (2.5/2.75)) {
          t -= 2.25/2.75;
          return 1 - (7.5625*t*t + .9375);
        } else {
          t -= 2.625/2.75;
          return 1 - (7.5625*t*t + .984375);
        }
    }
  }
  float easeOut(float t){
    return 1 - easeIn(1 - t);
  }
  float solve(float t){
    switch (ease) {
      case in:
        return easeIn(t);
      case out:
        return easeOut(t);
      case inOut:
        float side = clamp(sign(t - 0.5), 0.0, 1.0);
        return (mix(easeIn(t*2), easeOut(t*2-1), side) + side) * 0.5;
    }
  }
};

struct TweenAnimationState {
  float4 current;
  float4 target;
  float4 previous;
  float currentTime;
  float duration;
  Curve curve;
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
  float y = ((Curve)a->curve).solve(a->currentTime / a->duration);
  a->current = a->running ? y * a->target : a->target;
}
