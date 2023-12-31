//
//  VocableListCell.swift
//  Vocable
//
//  Created by Jesse Morgan on 3/14/22.
//  Copyright © 2022 WillowTree. All rights reserved.
//
import UIKit

final class VocableListCell: UICollectionViewListCell {

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)

        var background = UIBackgroundConfiguration.listSidebarCell()
        background.backgroundColor = .primaryBackgroundColor
        backgroundConfiguration = background
    }
}
