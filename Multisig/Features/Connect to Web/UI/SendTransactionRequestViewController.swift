//
// Created by Dmitry Bespalov on 18.02.22.
// Copyright (c) 2022 Gnosis Ltd. All rights reserved.
//

import Foundation
import UIKit

class SendTransactionRequestViewController: WebConnectionContainerViewController, WebConnectionRequestObserver {

    var controller: WebConnectionController!
    var connection: WebConnection!
    var request: WebConnectionSendTransactionRequest!

    override func viewDidLoad() {
        super.viewDidLoad()
        let chain = controller.chain(for: request)
        ribbonView.update(chain: chain)

        if let peer = connection.remotePeer {
            headerView.textLabel.text = peer.name
            headerView.detailTextLabel.text = peer.url.host
            let placeholder = UIImage(named: "connection-placeholder")
            headerView.imageView.setImage(url: peer.icons.first, placeholder: placeholder, failedImage: placeholder)
        } else {
            headerView.isHidden = true
        }

        actionPanelView.setConfirmText("Submit")

        controller.attach(observer: self, to: request)
    }

    deinit {
        controller.detach(observer: self)
    }

    func didUpdate(request: WebConnectionRequest) {
        if request.status == .success || request.status == .failed {
            onFinish()
        }
    }

    override func didCancel() {
        didReject()
    }

    override func didReject() {

    }

    override func didConfirm() {

    }

    // reload the data - rebuild the cells,
        // convert ethTransaction to the UI parameters

    // estimate transaction - do this, because we'll execute "eth_call" and check that it doesn't fail
        // use the estimated results only if the tx's values are not set.

    // modifying estimation - copy from the review execution (form)

    // authorize and sign transaction

    // ask pascode

    // sign
}
