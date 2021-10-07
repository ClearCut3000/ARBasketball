//
//  ResultViewController.swift
//  ARBasketball
//
//  Created by Николай Никитин on 06.10.2021.
//

import UIKit

class ResultViewController: UIViewController {
  @IBOutlet weak var resultLabel: UILabel!

  private let result: Int

  init?(coder: NSCoder,_ result: Int){
    self.result = result
    super.init (coder: coder)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func getResult(){
    resultLabel.text = " You have scored \(result) goals!"
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = UIColor(patternImage: UIImage(named: "result.png")!)
    getResult()
  }

  @IBAction func unwind (_ seque: UIStoryboardSegue){
  }
}
