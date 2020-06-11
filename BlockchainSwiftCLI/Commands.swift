//
//  Commands.swift
//  BlockchainSwiftCLI
//
//  Created by Magnus Nevstad on 04/06/2020.
//  Copyright © 2020 Magnus Nevstad. All rights reserved.
//

import Foundation

enum Command: String, CaseIterable {
    case wallet
    case w
    case mine
    case m
    case peers
    case p
    case mempool
    case mp
    case help
    case h
    case exit
    case q
    
    var usage: String {
        switch self {
        case .w: fallthrough
        case .wallet:
            return WalletSubCommand.allCases.filter{ $0.info != nil }.map { "\(rawValue.bold) \($0.usage) \($0.info!.dim)" }.joined(separator: "\n")
        case .m: fallthrough
        case .mine:
            return "\(rawValue.bold) \(CommandParameter.walletAddress.usage) \(Flag.num.usage) \(info.dim)"
        case .p: fallthrough
        case .peers:
            fallthrough
        case .mp: fallthrough
        case .mempool:
            fallthrough
        case .h: fallthrough
        case .help:
            fallthrough
        case .q: fallthrough
        case .exit:
            return "\(rawValue.bold) \(info.dim)"
        }
    }
    
    var showInHelp: Bool {
        switch self {
        case .w: fallthrough
        case .m: fallthrough
        case .p: fallthrough
        case .mp: fallthrough
        case .h: fallthrough
        case .q:
            return false
        default:
            return true
        }
    }
    
    var info: String {
        switch self {
        case .mine:
            return "- Start mining blocks. Requires a wallet address, for block rewards."
        case .peers:
            return "- List known peers in the network."
        case .mempool:
            return "- List transactions currently in the mempool."
        case .help:
            return "- List all available commands."
        default:
            return ""
        }
    }
}

enum WalletSubCommand: String, CaseIterable {
    case create
    case c
    case delete
    case d
    case list
    case l
    case export
    case e
    case balance
    case b
    case send
    case s
    case history
    case h
    
    var usage: String {
        return "\(rawValue.underline) \(parameters.map{ $0.usage }.joined(separator: " ")) \(flags.map{ $0.usage }.joined(separator: " "))"
    }
    
    var parameters: [CommandParameter] {
        switch self {
        case .c: fallthrough
        case .create:
            return [.walletName]
        case .d: fallthrough
        case .delete:
            return [.walletName]
        case .l: fallthrough
        case .list:
            return []
        case .e: fallthrough
        case .export:
            return [.walletName]
        case .b: fallthrough
        case .balance:
            return [.walletAddress]
        case .s: fallthrough
        case .send:
            return [.walletName, .recipientAddress, .value]
        case .h: fallthrough
        case .history:
            return [.walletName]
        }
    }
    
    var flags: [Flag] {
        switch self {
        case .c: fallthrough
        case .create:
            return [.keychain]
        default:
            return []
        }
    }
    
    var info: String? {
        switch self {
        case .create:
            return "- Create a wallet, optionally stored in keychain."
        case .delete:
            return "- Delete a wallet from the keychain."
        case .list:
            return "- List wallets stored in keychain."
        case .export:
            return "- Export wallet private key."
        case .balance:
            return "- Show wallet balance."
        case .send:
            return "- Send coins to another address."
        case .history:
            return "- See wallet transaction history."
        default:
            return nil
        }
    }
    
}

enum CommandParameter: String {
    case walletAddress = "wallet address"
    case walletName = "wallet name"
    case recipientAddress = "recipient address"
    case value
    
    
    var usage: String {
        return "[" + rawValue + "]"
    }
}

enum Flag: String {
    case keychain = "--keychain"
    case num = "--num"
    case central = "--central"

    var usage: String {
        return "<" + rawValue + ">"
    }
}
