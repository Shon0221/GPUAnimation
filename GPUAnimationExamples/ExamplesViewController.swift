//
//  ExamplesViewController.swift
//  GPUAnimationExamples
//
//  Created by YiLun Zhao on 2016-09-27.
//  Copyright © 2016 Luke Zhao. All rights reserved.
//

import UIKit


class ExamplesViewController: UIViewController {
  @IBOutlet weak var square: UIView!

  override func viewDidLoad() {
    super.viewDidLoad()
    
    square.layer.cornerRadius = 8
    square.animate{
      $0.alpha.target = 0
      $0.alpha.onChange = {
        print($0)
      }
    }.then.animate{
      $0.alpha.target = 1
    }
//    square.animate{}
//    test1()
//    testAlloc()
  }
  
  func testAlloc(){
    for _ in 0...10000{
      square.animate { to in
        to.stiffness = 200
        to.bounds.target = CGRect(x: 0, y: 0, width: 300, height: 300)
      }.animate{ to in
        to.stiffness = 300
        to.center.target = CGPoint(x:200, y:400)
      }
    }
  }
  
  func test1(){
    square.animate { to in
      to.stiffness = 200
      to.bounds.target = CGRect(x: 0, y: 0, width: 300, height: 300)
    }.animate{ to in
      to.stiffness = 300
      to.center.target = CGPoint(x:200, y:400)
    }.then {
      print("First stage done")
    }.delay(2).animate{ to in
      to.bounds.target = CGRect(x: 0, y: 0, width: 100, height: 200)
      to.center.target = CGPoint(x:200, y:100)
      to.backgroundColor.target = UIColor.black
    }.then {
      print("Second stage done")
    }.animate{ to in
      to.stiffness = 200
      to.bounds.target = CGRect(x: 0, y: 0, width: 300, height: 300)
      to.center.target = CGPoint(x:200, y:400)
    }.animate{ to in
      to.damping = 40
      to.backgroundColor.target = UIColor.green
    }.then {
      print("test 1 finished!")
      self.test2()
    }
  }
  
  func test2(){
    let animation = square.animate{
      $0.stiffness = 20
      $0.bounds.target = CGRect(x: 0, y: 0, width: 50, height: 50)
    }.then{
      print("This line shouldn't be printed")
    }.execute()
    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false){ timer in
      animation.stop()
      print("test 2 finished!")
      self.test3()
    }
  }
  
  func test3(){
    let animation = square.delay(2).animate{
      $0.stiffness = 20
      $0.bounds.target = CGRect(x: 0, y: 0, width: 50, height: 500)
    }.then{ print("This line shouldn't be printed") }.execute()
    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false){ timer in
      print("test 3 finished!")
      animation.stop()
      self.test4()
    }
  }
  
  lazy var storedAnimation:UIViewAnimationBuilder = self.square.animate{
    $0.stiffness = 20
    $0.bounds.target = CGRect(x: 0, y: 0, width: 50, height: 500)
  }.then().animate{
    $0.stiffness = 20
    $0.bounds.target = CGRect(x: 0, y: 0, width: 50, height: 50)
  }.then{
    print("Stored animation finished")
    self.storedAnimation.execute()
  }
  func test4(){
    storedAnimation.execute()
  }
}

