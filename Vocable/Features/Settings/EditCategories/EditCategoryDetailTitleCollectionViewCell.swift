//
//  EditCategoryDetailsHeaderCollectionViewCell.swift
//  Vocable AAC
//
//  Created by Steve Foster on 5/7/20.
//  Copyright © 2020 WillowTree. All rights reserved.
//

import UIKit

protocol EditCategoryDetailsHeaderCollectionViewCellDelegate: AnyObject {
    func didTapEdit()
}

protocol EditCategoryDetailTitleCollectionViewCellDelegate: AnyObject {
    func didTapEdit()
}

final class EditCategoryDetailTitleCollectionViewCell: UICollectionViewCell {

    weak var delegate: EditCategoryDetailTitleCollectionViewCellDelegate?

    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var editButton: GazeableButton!

    override func awakeFromNib() {
        super.awakeFromNib()

        editButton.backgroundColor = .collectionViewBackgroundColor
        editButton.setFillColor(.defaultCellBackgroundColor, for: .normal)
        editButton.setTitleColor(.defaultTextColor, for: .normal)
        editButton.isOpaque = true
        editButton.addTarget(self, action: #selector(didTapEdit(_:)), for: .primaryActionTriggered)
    }

    @objc func didTapEdit(_ sender: Any) {
        delegate?.didTapEdit()
    }

}
