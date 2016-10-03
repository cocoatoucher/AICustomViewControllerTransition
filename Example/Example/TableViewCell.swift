//
//  TableViewCell.swift
//  Example
//
//  Created by cocoatoucher on 10/07/16.
//  Copyright © 2016 cocoatoucher. All rights reserved.
//

import UIKit

class TableViewCell: UITableViewCell {
	
	@IBOutlet weak var innerView: UIView!
	@IBOutlet weak var thumbnail: UIImageView!
	
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
