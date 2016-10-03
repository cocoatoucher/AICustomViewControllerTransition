//
//  ModalViewController.swift
//  Example
//
//  Created by cocoatoucher on 10/07/16.
//  Copyright © 2016 cocoatoucher. All rights reserved.
//

import UIKit

class ModalViewController: UIViewController {
	
	@IBOutlet weak var headerView: UIView!
	@IBOutlet weak var headerImageView: UIImageView!
	@IBOutlet weak var panIndicatorView: UIView!
	var handlePan: ((_ panGestureRecognizer: UIPanGestureRecognizer) -> Void)?
	var isPanIndicatorHidden: Bool = false {
		didSet {
			if (self.panIndicatorView) != nil {
				self.panIndicatorView.isHidden = isPanIndicatorHidden;
			}
		}
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		self.panIndicatorView.isHidden = self.isPanIndicatorHidden;
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	@IBAction func dismissAction(_ sender: AnyObject) {
		self.dismiss(animated: true, completion: nil)
	}
	
	@IBAction func handlePan(_ sender: UIPanGestureRecognizer) {
		self.handlePan?(sender)
	}

}
