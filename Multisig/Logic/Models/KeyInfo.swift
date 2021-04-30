//
//  KeyInfo.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 3/3/21.
//  Copyright © 2021 Gnosis Ltd. All rights reserved.
//

import Foundation
import CoreData
import Web3
import WalletConnectSwift

/// Enum for storing key type in the presistanse store. The order of existing items should not be changed.
enum KeyType: Int, CaseIterable {
    case device
    case walletConnect
}

extension KeyInfo {
    /// Blockchain address that this key controls
    var address: Address {
        get { addressString.flatMap(Address.init) ?? Address.zero}
        set { addressString = newValue.checksummed }
    }

    var keyType: KeyType {
        get { KeyType(rawValue: Int(type)) ?? .device }
        set { type = Int16(newValue.rawValue) }
    }

    var hasPrivateKey: Bool {
        (try? privateKey()) != nil
	}

    var displayName: String {
        name ?? "Key \(address.ellipsized())"
    }

    struct WalletConnectKeyMetadata: Codable {
        let walletInfo: Session.WalletInfo
        let installedWallet: InstalledWallet?

        var data: Data {
            try! JSONEncoder().encode(self)
        }

        static func from(data: Data) -> Self? {
            try? JSONDecoder().decode(Self.self, from: data)
        }
    }

    static func name(address: Address) -> String? {
        guard let keyInfo = try? KeyInfo.keys(addresses: [address]).first else { return nil }
        return keyInfo.name
    }

    /// Returns number of existing key infos
    static var count: Int {
        do {
            if App.configuration.toggles.walletConnectEnabled {
                let context = App.shared.coreDataStack.viewContext
                let fr = KeyInfo.fetchRequest().all()
                let itemCount = try context.count(for: fr)
                return itemCount
            } else {
                return try all().count
            }
        } catch {
            LogService.shared.error("Failed to fetch safe count: \(error)")
            return 0
        }
    }

    /// Return the list of KeyInfo sorted alphabetically by name
    static func all() throws -> [KeyInfo] {
        let context = App.shared.coreDataStack.viewContext
        let fr = KeyInfo.fetchRequest().all()
        var items = try context.fetch(fr)
        if !App.configuration.toggles.walletConnectEnabled {
            items = items.filter { $0.keyType == .device }
        }
        return items
    }

    /// This will return a list of KeyInfo for the addresses that it finds in the app.
    /// At most one key info per address will be returned.
    /// - Parameter addresses: all the infos for the same address
    /// - Returns: list of key information
    static func keys(addresses: [Address]) throws -> [KeyInfo] {
        let context = App.shared.coreDataStack.viewContext
        return try addresses.compactMap { address in
            let fr = KeyInfo.fetchRequest().by(address: address)
            let item = try context.fetch(fr)
            return item.first
        }
    }

    /// Returns private keys found by the addresses. The multiple private keys option is needed when we want to sign the "push notification" payload with all of the keys available in the app.
    /// At most one key per address is returned.
    /// 
    /// - Parameter addresses: which addresses you want to get keys?
    /// - Throws: in case of underlying errors
    /// - Returns: private keys for the addresses that were found.
    static func privateKeys(addresses: [Address]) throws -> [PrivateKey] {
        try addresses.compactMap { address in
            try PrivateKey.key(address: address)
        }
    }

    /// Will add a new key to the Keychain/Secure storage and save the key info in the persistence store.
    /// - Parameters:
    ///   - address: address of the imported key
    ///   - name: name of the imported key
    ///   - privateKey: private key to save
    @discardableResult
    static func `import`(address: Address, name: String, privateKey: PrivateKey) throws -> KeyInfo {
        let context = App.shared.coreDataStack.viewContext

        // see if already exists - then update existing, otherwise
        // create a new one
        let fr = KeyInfo.fetchRequest().by(address: address)
        let item: KeyInfo

        if let existing = try context.fetch(fr).first {
            item = existing
            guard existing.keyType == .device else {
                throw GSError.CouldNotImportOwnerKeyWithSameAddress()
            }
        } else {
            item = KeyInfo(context: context)
        }

        item.address = address
        item.name = name
        item.keyID = privateKey.id
        item.keyType = .device

        item.save()
        try privateKey.save()

        return item
    }

    /// Will save the key info from WalletConnect session in the persistence store.
    /// - Parameters:
    ///   - session: WalletConnect session object
    @discardableResult
    static func `import`(session: Session, installedWallet: InstalledWallet?) throws -> KeyInfo? {
        guard let walletInfo = session.walletInfo,
              let addressString = walletInfo.accounts.first,
              let address = Address(addressString) else {
            return nil
        }

        let context = App.shared.coreDataStack.viewContext

        // see if already exists - then update existing, otherwise
        // create a new one
        let fr = KeyInfo.fetchRequest().by(address: address)
        let item: KeyInfo

        if let existing = try context.fetch(fr).first {
            // It is possible to update only key of the same type. Do not update key name for already imported WalletConnect key.
            guard existing.keyType == .walletConnect else {
                throw GSError.CouldNotImportOwnerKeyWithSameAddress()
            }
            item = existing
        } else {
            item = KeyInfo(context: context)
            item.name = walletInfo.peerMeta.name
        }

        item.address = address
        item.keyID = "walletconnect:\(address.checksummed)"
        item.keyType = .walletConnect
        item.metadata = WalletConnectKeyMetadata(walletInfo: walletInfo, installedWallet: installedWallet).data

        item.save()

        return item
    }

    /// Renames the key with a different name
    /// - Parameter newName: new name for the key. Not empty.
    func rename(newName: String) {
        assert(!newName.isEmpty, "name must not be empty")
        name = newName
        save()
    }

    /// Delete all of the keys stored
    static func deleteAll() throws {
        try all().forEach { try $0.delete() }
    }

    /// Deletes keys with matching addresses
    /// - Parameter addresses: addresses of keys to delete
    static func delete(addresses: [Address]) throws {
        try keys(addresses: addresses).forEach { try $0.delete() }
    }

    /// Saves the key to the persistent store
    func save() {
        App.shared.coreDataStack.saveContext()
    }

    /// Will delete the key info and the stored private key
    /// - Throws: in case of underlying error
    func delete() throws {
        if let keyID = keyID, keyType == .device {
            try PrivateKey.remove(id: keyID)
        }
        App.shared.coreDataStack.viewContext.delete(self)
        save()
    }

    func privateKey() throws -> PrivateKey? {
        guard let keyID = keyID else { return nil }
        return try PrivateKey.key(id: keyID)
    }
}

extension NSFetchRequest where ResultType == KeyInfo {

    /// all, sorted by name, ascending
    func all() -> Self {
        sortDescriptors = [
            NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:))),
            NSSortDescriptor(key: "addressString", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
        ]
        return self
    }

    /// return keys with matching address
    func by(address: Address) -> Self {
        sortDescriptors = []
        predicate = NSPredicate(format: "addressString CONTAINS[c] %@", address.checksummed)
        fetchLimit = 1
        return self
    }

}
