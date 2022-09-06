//
//  ClaimSafeTokenFlow.swift
//  Multisig
//
//  Created by Moaaz on 6/27/22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import Foundation
import SwiftCryptoTokenFormatter

class SelectDelegateFlow: UIFlow {
    var factory: ClaimSafeTokenFlowFactory!
    var safe: Safe
    var guardian: Guardian?
    var customAddress: Address?
    var controller: ClaimingAppController!

    init(safe: Safe,
         controller: ClaimingAppController,
         factory: ClaimSafeTokenFlowFactory = ClaimSafeTokenFlowFactory(),
         completion: @escaping (_ success: Bool) -> Void) {
        self.safe = safe
        self.factory = factory
        self.controller = controller
        super.init(completion: completion)
    }

    override func start() {
        chooseDelegateIntro()
    }

    func chooseDelegateIntro() {
        let vc = factory.chooseDelegateIntro { [unowned self] in
            chooseGuardian()
        } onCustomAddress: { [unowned self] in
            enterCustomAddress()
        }
        show(vc)
        vc.navigationItem.largeTitleDisplayMode = .always
        vc.navigationController?.navigationBar.prefersLargeTitles = true
    }

    func chooseGuardian() {
        let chooseGuardianVC = factory.chooseGuardian() { [unowned self] selectedGuardian in
            guardian = selectedGuardian
            customAddress = nil
            stop(success: true)
        }
        chooseGuardianVC.safe = safe
        chooseGuardianVC.controller = controller
        show(chooseGuardianVC)
    }

    func enterCustomAddress() {
        let enterAddressVC = factory.enterCustomAddress(mainnet: self.safe.chain?.id == Chain.ChainID.ethereumMainnet) { [unowned self] address in
            guardian = nil
            customAddress = address
            stop(success: true)
        }
        show(enterAddressVC)
    }

    func popToStart() {
        guard let vc = navigationController.viewControllers.first(where: { $0 is ChooseDelegateIntroViewController }) else {
            return
        }
        navigationController.popToViewController(vc, animated: true)
    }

}

// TODO: open review screen with data at the end

import Solidity

class ClaimSafeTokenFlow: UIFlow {
    var factory: ClaimSafeTokenFlowFactory!
    var safe: Safe
    var amount: Sol.UInt128?
    var claimData: ClaimingAppController.ClaimingData?
    var timestamp: TimeInterval?
    var selectedGuardian: Guardian?
    var selectedCustomAddress: Address?
    var delegateFlow: SelectDelegateFlow!
    var controller: ClaimingAppController!
    var transactionDetails: SCGModels.TransactionDetails!

    init(safe: Safe,
         factory: ClaimSafeTokenFlowFactory = ClaimSafeTokenFlowFactory(),
         completion: @escaping (_ success: Bool) -> Void) {
        self.safe = safe
        self.factory = factory
        // TODO: switch configuration depending on the safe's chain
        let configuration: ClaimingAppController.Configuration = .rinkeby
        controller = ClaimingAppController(configuration: configuration, chain: safe.chain!)
        super.init(completion: completion)
    }

    override func start() {
        let startVC = factory.start()
        startVC.safe = safe
        startVC.controller = controller

        startVC.completion = { [unowned self] isEligible in
            if isEligible == true {
                showIntro()
                navigationController.viewControllers.remove(at: 0)
            } else if isEligible == false {
                showNotAvailable()
                navigationController.viewControllers.remove(at: 0)
            } else {
                stop(success: false)
            }
        }

        show(startVC)
    }
    
    func showDisclaimer() {
        let vc = factory.legalDisclaimer {[unowned self] in
            chooseDelegate()
        }
        show(vc)
    }

    func showIntro() {
        let introVC = factory.claimGetStarted { [unowned self] in
            chooseTutorial()
        }
        show(introVC, crossDissolve: true)
        introVC.navigationItem.largeTitleDisplayMode = .always
        introVC.navigationController?.navigationBar.prefersLargeTitles = true
    }

    func showNotAvailable() {
        let vc = factory.claimNotAvailable()
        show(vc, crossDissolve: true)
    }

    func chooseTutorial() {
        let vc = factory.chooseTutorial { [unowned self] in
            showDisclaimer()
        }
        show(vc)
    }

    func chooseDelegate() {
        delegateFlow = SelectDelegateFlow(safe: safe, controller: controller, factory: factory, completion: { [unowned self] _ in
            selectedGuardian = delegateFlow.guardian
            selectedCustomAddress = delegateFlow.customAddress
            selectAmount()
        })
        push(flow: delegateFlow)
    }

    func selectAmount() {
        let claimVC = factory.selectAmount(
            safe: safe,
            delegate: selectedCustomAddress,
            guardian: selectedGuardian,
            controller: controller
        )

        claimVC.completion = { [unowned self, unowned claimVC] in
            amount = claimVC.inputAmount
            claimData = claimVC.claimData
            timestamp = claimVC.timestamp

            review()
        }
        claimVC.onEditDelegate = { [unowned self] in
            delegateFlow.popToStart()
        }

        show(claimVC)
    }

    func review() {
        assert(selectedCustomAddress != nil || selectedGuardian != nil)
        assert(amount != nil)
        assert(claimData != nil)
        assert(timestamp != nil)

        let reviewVC = ReviewClaimSafeTokenTransactionViewController(safe: safe)

        reviewVC.amount = amount
        reviewVC.claimData = claimData
        reviewVC.timestamp = timestamp
        reviewVC.selectedGuardian = selectedGuardian
        reviewVC.selectedCustomAddress = selectedCustomAddress
        reviewVC.controller = controller
        

        reviewVC.onSuccess = { [unowned self] txDetails in
            transactionDetails = txDetails
            self.success()
        }
        show(reviewVC)
    }

    func success() {
        let displayAmount = TokenFormatter().string(from: BigDecimal(Int256(amount!.big()), 18)) + " SAFE"
        let successVC = factory.success(amount: displayAmount) { [unowned self] in

            NotificationCenter.default.post(
                name: .initiateTxNotificationReceived,
                object: self,
                userInfo: ["transactionDetails": transactionDetails!])

            stop(success: true)
        }

        show(successVC)
    }
}

class ClaimSafeTokenFlowFactory {
    func start() -> ClaimSplashViewController {
        let vc = ClaimSplashViewController()
        return vc
    }

    func legalDisclaimer(onAgree: @escaping () -> ()) -> LegalDisclaimerViewController {
        let vc = LegalDisclaimerViewController()
        vc.onAgree = onAgree
        return vc
    }

    func claimGetStarted(onStartClaim: @escaping () -> ()) -> ClaimGetStartedViewController {
        let vc = ClaimGetStartedViewController()
        vc.onStartClaim = onStartClaim
        return vc
    }

    func claimNotAvailable() -> ClaimNotAvailableViewController {
        let vc = ClaimNotAvailableViewController()
        return vc
    }

    func chooseDelegateIntro(onChooseGuardian: @escaping () -> (),
                             onCustomAddress: @escaping () -> ()) -> ChooseDelegateIntroViewController{
        let vc = ChooseDelegateIntroViewController(onChooseGuardian: onChooseGuardian,
                                                   onCustomAddress: onCustomAddress)
        return vc
    }

    func chooseGuardian(_ onSelected: @escaping (Guardian) -> ()) -> GuardianListViewController {
        let vc = GuardianListViewController()
        vc.onSelected = onSelected
        return vc
    }

    func enterCustomAddress(mainnet: Bool, _ onContinue: @escaping (Address) -> ()) -> EnterCustomAddressViewController {
        let vc = EnterCustomAddressViewController()
        vc.mainnet = mainnet
        vc.onContinue = onContinue
        return vc
    }
    func chooseTutorial(completion: @escaping () -> ()) -> WhatIsSafeViewController {
        let vc = WhatIsSafeViewController(completion: completion)
        return vc
    }

    func selectAmount(safe: Safe, delegate: Address?, guardian: Guardian?, controller: ClaimingAppController) -> ClaimTokensViewController {
        let vc = ClaimTokensViewController(tokenDelegate: delegate, guardian: guardian, safe: safe, controller: controller)
        return vc
    }

    func success(amount: String,
                 completion: @escaping () -> Void) -> ClaimSuccessViewController {
        let successVC = ClaimSuccessViewController()
        successVC.amount = amount
        successVC.onOk = completion
        return successVC
    }
}
