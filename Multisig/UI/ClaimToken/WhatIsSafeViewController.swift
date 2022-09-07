//
//  WhatIsSafeViewController.swift
//  Multisig
//
//  Created by Mouaz on 9/5/22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import UIKit

class WhatIsSafeViewController: UIViewController {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var nextButton: UIButton!
    @IBOutlet weak var safeProtocolView: BorderedCheveronButton!
    @IBOutlet weak var interfacesView: BorderedCheveronButton!
    @IBOutlet weak var assetsView: BorderedCheveronButton!
    @IBOutlet weak var tokenomicsView: BorderedCheveronButton!

    private var onNext: (() -> ())?


    convenience init(onNext: @escaping () -> ()) {
        self.init(namedClass: WhatIsSafeViewController.self)
        self.onNext = onNext
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        safeProtocolView.set("Safe Protocol") { [unowned self] in
            let vc = ViewControllerFactory.detailedInfoViewController(title: "Safe Protocol",
                                                                      text: "Safe Deployments (core smart contract deployments across multiple networks\nCuration of “trusted lists” (Token lists, dApp lists, module lists)",
                                                                      attributedText: nil)
            show(vc, sender: self)
        }

        interfacesView.set("Interfaces") { [unowned self] in
            let vc = ViewControllerFactory.detailedInfoViewController(title: "Interfaces",
                                                                      text: "Decentralized hosting of a Safe frontend using the safe.eth domain\nDecentralized hosting of governance frontends",
                                                                      attributedText: nil)
            show(vc, sender: self)
        }

        assetsView.set("On-chain assets") { [unowned self] in
            let vc = ViewControllerFactory.detailedInfoViewController(title: "On-chain assets",
                                                                      text: "ENS names\nOutstanding Safe token supply\nOther Safe Treasury assets (NFTs, tokens, etc.)",
                                                                      attributedText: nil)
            show(vc, sender: self)
        }

        tokenomicsView.set("Tokenomics") { [unowned self] in
            let vc = ViewControllerFactory.detailedInfoViewController(title: "Tokenomics",
                                                                      text: "Ecosystem reward programs\nUser rewards\nValue capture\nFuture token utility",
                                                                      attributedText: nil)

            show(vc, sender: self)
        }

        titleLabel.setStyle(.Updated.title)
        descriptionLabel.setStyle(.secondary)
        nextButton.setText("Next", .filled)
    }

    @IBAction func didTapNext(_ sender: Any) {
        onNext?()
    }
}
