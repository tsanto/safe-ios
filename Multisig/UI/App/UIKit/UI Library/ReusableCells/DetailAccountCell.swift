//
//  DetailAccountCell.swift
//  Multisig
//
//  Created by Andrey Scherbovich on 02.12.20.
//  Copyright © 2020 Gnosis Ltd. All rights reserved.
//

import UIKit

class DetailAccountCell: UITableViewCell {
    var onViewDetails: (() -> Void)?

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var addressInfoView: AddressInfoView!
    @IBOutlet private weak var titleTopConstraint: NSLayoutConstraint!

    private let titleTopSpace: CGFloat = 16

    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setStyle(.headline)
        addressInfoView.setDetailImage(#imageLiteral(resourceName: "ico-browse-address"))
        addressInfoView.onDisclosureButtonAction = viewDetails
    }

    func setAccount(addressInfo: AddressInfo, title: String?) {
        titleLabel.text = title
        titleTopConstraint.constant = title == nil ? 0 : titleTopSpace
        addressInfoView.setAddressInfo(addressInfo)
    }

    private func viewDetails() {
        onViewDetails?()
    }
}
