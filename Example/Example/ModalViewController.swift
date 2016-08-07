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
	var dismissCallback: ((panGestureRecognizer: UIPanGestureRecognizer, translatedPoint: CGPoint) -> Void)?
	var isPanIndicatorHidden: Bool = false {
		didSet {
			if (self.panIndicatorView) != nil {
				self.panIndicatorView.hidden = isPanIndicatorHidden;
			}
		}
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		self.panIndicatorView.hidden = self.isPanIndicatorHidden;
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	@IBAction func dismissAction(sender: AnyObject) {
		self.dismissViewControllerAnimated(true, completion: nil)
	}
	
	@IBAction func panAction(sender: UIPanGestureRecognizer) {
		self.dismissCallback?(panGestureRecognizer: sender, translatedPoint: sender.translationInView(self.view))
	}

}
