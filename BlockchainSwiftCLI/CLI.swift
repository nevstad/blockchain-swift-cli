//
//  CLI.swift
//  BlockchainSwiftCLI
//
//  Created by Magnus Nevstad on 22/05/2019.
//

import Foundation
import BlockchainSwift


class CLI {
    private let node: Node
    
    init(runAsCentralNode: Bool) {
        let type: Node.NodeType = runAsCentralNode ? .central : .peer
        let dbDirectoryPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("BlockchainSwift")
        let dbFilePath = dbDirectoryPath.appendingPathComponent("blockchain.sqlite")
        try! FileManager.default.createDirectory(at: dbDirectoryPath, withIntermediateDirectories: true)
        print("🏃🏻‍♂️ Running Node! (\(type.rawValue))")
        print("Connecting node to network...".dim)
        fflush(stdout)
        node = Node(type: type, blockStore: SQLiteBlockStore(path: dbFilePath))
        print("⛓  Blockchain: \(node.blockchain.currentBlockHeight()) blocks, latest hash: \(node.blockchain.latestBlockHash().hex)")
        print("🚰 Mempool: \(node.blockchain.mempool().count) transactions")
        
        class Delegate: NodeDelegate {
            let initialSyncCompleteClosure: () -> Void
            
            init(initialSyncCompleteClosure closure: @escaping () -> Void) {
                initialSyncCompleteClosure = closure
            }
            
            func node(_ node: Node, didConnect success: Bool, error: Error?) {
                print("🚦 Connected".green)
                initialSyncCompleteClosure()
            }
            func node(_ node: Node, didAddPeer peer: NodeAddress) {
                print("← ".blue + "\(peer.urlString) connected".dim)
            }
            func node(_ node: Node, didRemovePeer peer: NodeAddress) {
                print("𝗑 ".red + "\(peer.urlString) disconnected".dim)
            }
            func node(_ node: Node, didCreateTransactions transactions: [Transaction]) {
                print("✔ ".blue + "Transaction created")
            }
            func node(_ node: Node, didSendTransactions transactions: [Transaction]) {
                print("→ ".blue + "Sent \(transactions.count) transactions".dim)
            }
            func node(_ node: Node, didReceiveTransactions transactions: [Transaction]) {
                print("← ".blue + "Received \(transactions.count) transactions".dim)
            }
            func node(_ node: Node, didCreateBlocks blocks: [Block]) {
                print("🎉 Mined block! \(blocks.first!.hash.hex)")
            }
            func node(_ node: Node, didSendBlocks blocks: [Block]) {
                print("→ ".blue + "Sent \(blocks.count) blocks".dim)
            }
            func node(_ node: Node, didReceiveBlocks blocks: [Block]) {
                print("← ".blue + "Got \(blocks.count) blocks".dim)
            }
        }
        let initialSyncGroup = DispatchGroup()
        initialSyncGroup.enter()
        node.delegate = Delegate() {
            initialSyncGroup.leave()
        }
        DispatchQueue.global().async {
            self.node.connect()
        }
        initialSyncGroup.wait()
    }
    
    func run() {
        printAvailableCommands()
        while true {
            let args = getInput(prompt: String.prompt.bold.green).components(separatedBy: " ")
            parseInput(args)
        }
    }
    
    private func printError(_ error: String) {
        print("Error: ".red + error)
    }
    
    private func printCommand(_ command: Command) {
        for usage in command.usage.components(separatedBy: "\n") {
            print("    \(String.prompt) \(usage)")
        }
    }
    
    private func printAvailableCommands() {
        print("  Available commands:")
        Command.allCases.filter{ $0.showInHelp }.forEach { command in
            printCommand(command)
        }
    }
    
    private func getInput(prompt: String? = nil) -> String {
        if let prompt = prompt {
            print(prompt, terminator: "")
            fflush(stdout)
        }
        let inputData = FileHandle.standardInput.availableData
        return String(data: inputData, encoding: .utf8)!.trimmingCharacters(in: .newlines)
    }
    
    private func getConfirmationInput(prompt: String) -> Bool {
        var confirmed = getInput(prompt: prompt)
        while !confirmed.isYesOrNo {
            confirmed = getInput(prompt: "Please enter 'y' or 'n': ".dim)
        }
        return confirmed.isYes
    }
    
    private func parseInput(_ args: [String]) {
        let cmds = args.compactMap { Command(rawValue: $0) }
        let subcmds = args.compactMap { WalletSubCommand(rawValue: $0) }
        let flags = args.compactMap { Flag(rawValue: $0) }
        guard let cmd = cmds.first else {
            printError("Unknown command")
            return
        }
        switch cmd {
        case .q: fallthrough
        case .exit :
            quit()
        case .h: fallthrough
        case .help:
            printAvailableCommands()
        case .p: fallthrough
        case .peers:
            listPeers()
        case .mp: fallthrough
        case .mempool:
            memPool()
        case .m: fallthrough
        case .mine:
            let walletAddress = args.count < 2 ? getInput(prompt: "Enter wallet address: ".dim) : args[1]
            if let validWalletAddress = Data(walletAddress: walletAddress) {
                var num = 1
                if flags.contains(.num) {
                    let numStr = args.count < 4 ? getInput(prompt: "How many blocks to mine: ".dim) : args[3]
                    num = Int(numStr) ?? num
                }
                mine(minerAddress: validWalletAddress, num: num)
            } else {
                printError("You must specify a valid wallet address!")
            }
        case .w: fallthrough
        case .wallet:
            if subcmds.count > 0 {
                switch subcmds[0] {
                case .c: fallthrough
                case .create:
                    let name = args.count < 3 ? getInput(prompt: "Enter wallet name: ".dim) : args[2]
                    createWallet(named: name, keychain: flags.contains(.keychain))
                case .d: fallthrough
                case .delete:
                    let name = args.count < 3 ? getInput(prompt: "Enter wallet name: ".dim) : args[2]
                    let confirmPrompt = "Are you sure you want to delete '\(name)'? [".dim + "y".green + "/".dim + "n".red + "]: ".dim
                    if getConfirmationInput(prompt: confirmPrompt) {
                        deleteWallet(named: name)
                    }
                case .l: fallthrough
                case .list:
                    listWallets()
                case .e: fallthrough
                case .export:
                    let walletName = args.count < 3 ? getInput(prompt: "Enter wallet name: ".dim) : args[2]
                    guard let keys = Keygen.loadKeyPairFromKeychain(name: walletName) else {
                        printError("Could not load wallet named \(walletName)")
                        return
                    }
                    let wallet = Wallet(name: walletName, keyPair: keys)
                    exportWallet(wallet)
                case .b: fallthrough
                case .balance:
                    let walletAddress = args.count < 3 ? getInput(prompt: "Enter wallet address: ".dim) : args[2]
                    if let validWalletAddress = Data(walletAddress: walletAddress) {
                        walletBalance(walletAddress: validWalletAddress)
                    } else {
                        printError("You must specify a valid wallet address!")
                    }
                case .s: fallthrough
                case .send:
                    let walletName = args.count < 3 ? getInput(prompt: "Enter wallet name: ".dim) : args[2]
                    guard let keys = Keygen.loadKeyPairFromKeychain(name: walletName) else {
                        printError("Could not load wallet named \(walletName)")
                        return
                    }
                    let wallet = Wallet(name: walletName, keyPair: keys)
                    let recipientAddress = args.count < 4 ? getInput(prompt: "Enter recipient address: ".dim) : args[3]
                    guard let recipient = Data(walletAddress: recipientAddress) else {
                        printError("You must specify a valid recipient address")
                        return
                    }
                    let valueString = args.count < 5 ? getInput(prompt: "Enter value to send: ".dim) : args[4]
                    guard let value = UInt64(valueString) else {
                        printError("You must specify a valid value")
                        return
                    }
                    send(from: wallet, to: recipient, value: value)
                case .h: fallthrough
                case .history:
                    let walletName = args.count < 3 ? getInput(prompt: "Enter wallet name: ".dim) : args[2]
                    guard let keys = Keygen.loadKeyPairFromKeychain(name: walletName) else {
                        printError("Could not load wallet named \(walletName)")
                        return
                    }
                    let wallet = Wallet(name: walletName, keyPair: keys)
                    history(wallet: wallet)
                }
            } else {
                printCommand(cmd)
            }
        }
    }
    
    private func quit() {
        print("👋🏻")
        exit(0)
    }
    
    private func mine(minerAddress: Data, num: Int = 1) {
        func doMine() {
            do {
                try self.node.mineBlock(minerAddress: minerAddress)
            } catch {
                printError("Someone else mined this block")
            }
        }
        
        let queue = DispatchQueue(label: "mine", attributes: .concurrent)
        let minerGroup = DispatchGroup()
        minerGroup.enter()
        queue.async {
            for _ in 1...num {
                doMine()
            }
            minerGroup.leave()
        }
        minerGroup.wait()
    }
    
    private func createWallet(named: String, keychain: Bool = false) {
        if let wallet = Wallet(name: named, storeInKeychain: keychain) {
            print("💳 Created wallet '\(named)'\(keychain ? " (stored in keychain)".dim : "")")
            print("  🔑 Public: \(wallet.publicKey.hex)".dim)
            if !keychain {
                print("  🔐 Private: \(wallet.exportPrivateKey()!.hex)".dim)
            }
            print("  📥 Address: \(wallet.address.hex)".dim)
        } else {
            printError("Could not create wallet!")
        }
    }
    
    private func deleteWallet(named name: String) {
        if Keygen.clearKeychainKeys(name: name) {
            print("💳 '\(name)' successfully deleted")
        } else {
            printError("Unable to delete wallet '\(name)'")
        }
    }
    
    private func listWallets() {
        let wallets = Keygen.avalaibleKeyPairsNames().compactMap { Wallet(name: $0) }
        if !wallets.isEmpty {
            print("💳 Available wallets:")
            for wallet in wallets {
                print("  '\(wallet.name)' " + "- Address: \(wallet.address.hex)".dim)
            }
        } else {
            print("You have no wallets in the keychain")
        }
        print()
    }
    
    private func exportWallet(_ wallet: Wallet) {
        print("💳 Wallet '\(wallet.name)':")
        print("  🔑 Public: \(wallet.publicKey.hex)".dim)
        print("  🔐 Private: \(wallet.exportPrivateKey()!.hex)".red)
        print("  📥 Address: \(wallet.address.hex)".dim)
    }
    
    private func walletBalance(walletAddress: Data) {
        let balance = node.blockchain.balance(address: walletAddress)
        print("💰 \(balance)")
    }
    
    private func send(from: Wallet, to: Data, value: UInt64) {
        do {
            let _ = try node.createTransaction(sender: from, recipientAddress: to, value: value)
        } catch Node.TxError.insufficientBalance {
            printError("Insufficient balance")
        } catch Node.TxError.invalidValue {
            printError("Invalid value")
        } catch Node.TxError.unverifiedTransaction {
            printError("Unable to verify transaction")
        } catch Node.TxError.sourceEqualDestination {
            printError("You can't send to yourself")
        } catch {
            printError("Unknown error")
        }
    }
    
    private func history(wallet: Wallet) {
        let payments = node.blockchain.payments(publicKey: wallet.publicKey)
        if payments.isEmpty {
            print("💳 Wallet '\(wallet.name)' has no transaction history.")
        } else {
            print("💳 Wallet '\(wallet.name)' txs (\(payments.count)):")
            for payment in payments {
                if payment.from == wallet.address {
                    print("  → ".red + payment.to.readableHex.dim + ": \(payment.value)" + (payment.pending ? " (pending)".dim : ""))
                } else if payment.to == wallet.address {
                    print("  ← ".green + payment.from.readableHex.dim + ": \(payment.value)" + (payment.pending ? " (pending)".dim : ""))
                }
            }
        }
    }
    
    private func listPeers() {
        print("🌐 Known peers:")
        for peer in node.peers {
            print("  \(peer.urlString)")
        }
    }
    
    private func memPool() {
        let pool = node.blockchain.mempool()
        if pool.isEmpty {
            print("🚰 Mempool is empty.")
        } else {
            print("🚰 Mempool (\(pool.count)):")
            for tx in pool {
                print("  \(tx.txId)")
            }
        }
    }

}
