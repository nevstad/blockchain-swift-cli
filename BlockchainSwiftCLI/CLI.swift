//
//  CLI.swift
//  BlockchainSwiftCLI
//
//  Created by Magnus Nevstad on 22/05/2019.
//

import Foundation
import BlockchainSwift

func interceptSigint(_ handleSigint: @escaping () -> Void) {
    signal(SIGINT, SIG_IGN) // // Make sure the signal does not terminate the application.
    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigintSrc.setEventHandler {
        print("Got SIGINT")
        handleSigint()
    }
    sigintSrc.resume()
}

enum Command: String, CaseIterable {
    case wallet
    case mine
    case help
    case exit
    case peers
    
    var usage: [String] {
        switch self {
        case .wallet:
            return WalletSubCommand.allCases.map { "\(rawValue.bold) \($0.usage) \($0.info.dim)" }
        case .mine:
            return ["\(rawValue.bold) [wallet address] \(info.dim)"]
        default:
            return [rawValue.bold]
        }
    }
    
    var info: String {
        switch self {
        case .wallet:
            return "- Create or list wallets stored in keychain."
        case .mine:
            return "- Start mining blocks. Requires a wallet address, for block rewards."
        case .peers:
            return "- List all known peers in the network."
        default:
            return ""
        }
    }
}

enum WalletSubCommand: String, CaseIterable {
    case create
    case delete
    case list
    case balance
    case send
    
    var usage: String {
        switch self {
        case .create:
            return "\(rawValue.underline) [wallet name] <--keychain|-kc>"
        case .delete:
            return "\(rawValue.underline) [wallet name]"
        case .list:
            return "\(rawValue.underline)"
        case .balance:
            return "\(rawValue.underline) [wallet address]"
        case .send:
            return "\(rawValue.underline) [wallet name] [to address] [value]"
        }
    }
    
    var info: String {
        switch self {
        case .create:
            return "- Create a wallet, optionally stored in keychain."
        case .delete:
            return "- Delete a wallet from the keychain."
        case .list:
            return "- List all wallets stored in keychain."
        case .balance:
            return "- Show wallet balance."
        case .send:
            return "- Send coins to another address."
        }
    }
    
}

enum Flag: String {
    case keychain = "-kc"
    case keychainLong = "--keychain"
    case central = "--central"
    case multiple = "-m"
    case multipleLong = "--multiple"
}


class CLI {
    let node: Node
    
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
            
            func nodeDidConnectToNetwork(_ node: Node) {
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
    
    func interactiveMode() {
        printAvailableCommands()
        while true {
            let args = getInput(prompt: String.prompt.bold.green).components(separatedBy: " ")
            parseInput(args)
        }
    }
    
    func printError(_ error: String) {
        print("Error: ".red + error)
    }
    
    func printCommand(_ command: Command) {
        for usage in command.usage {
            print("    \(String.prompt) \(usage)")
        }
    }
    
    func printAvailableCommands() {
        print("  Available commands:")
        Command.allCases.forEach {
            printCommand($0)
        }
    }
    
    func getInput(prompt: String? = nil) -> String {
        if let prompt = prompt {
            print(prompt, terminator: "")
            fflush(stdout)
        }
        let inputData = FileHandle.standardInput.availableData
        return String(data: inputData, encoding: .utf8)!.trimmingCharacters(in: .newlines)
    }
    
    func getConfirmationInput(prompt: String) -> Bool {
        var confirmed = getInput(prompt: prompt)
        while !confirmed.isYesOrNo {
            confirmed = getInput(prompt: "Please enter 'y' or 'n': ".dim)
        }
        return confirmed.isYes
    }
    
    func parseInput(_ args: [String]) {
        let cmds = args.compactMap { Command(rawValue: $0) }
        let subcmds = args.compactMap { WalletSubCommand(rawValue: $0) }
        let flags = args.compactMap { Flag(rawValue: $0) }
        guard let cmd = cmds.first else {
            printError("Unknown command")
            return
        }
        switch cmd {
        case .help:
            printAvailableCommands()
        case .exit :
            print("👋🏻")
            exit(0)
        case .wallet:
            if subcmds.count > 0 {
                switch subcmds[0] {
                case .create:
                    let name = args.count < 3 ? getInput(prompt: "Enter wallet name: ".dim) : args[2]
                    createWallet(named: name, keychain: flags.contains(.keychain) || flags.contains(.keychainLong))
                case .delete:
                    let name = args.count < 3 ? getInput(prompt: "Enter wallet name: ".dim) : args[2]
                    let confirmPrompt = "Are you sure you want to delete '\(name)'? [".dim + "y".green + "/".dim + "n".red + "]: ".dim
                    if getConfirmationInput(prompt: confirmPrompt) {
                        deleteWallet(named: name)
                    }
                case .list:
                    listWallets()
                case .balance:
                    let walletAddress = args.count < 3 ? getInput(prompt: "Enter wallet address: ".dim) : args[2]
                    if let validWalletAddress = Data(walletAddress: walletAddress) {
                        walletBalance(walletAddress: validWalletAddress)
                    } else {
                        printError("You must specify a valid wallet address!")
                    }
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
                }
            } else {
                printCommand(cmd)
            }
        case .mine:
            let walletAddress = args.count < 2 ? getInput(prompt: "Enter wallet address: ".dim) : args[1]
            if let validWalletAddress = Data(walletAddress: walletAddress) {
                var num = 1
                if flags.contains(.multiple) || flags.contains(.multipleLong) {
                    let numStr = args.count < 4 ? getInput(prompt: "How many block to mine: ".dim) : args[3]
                    num = Int(numStr) ?? num
                }
                mine(minerAddress: validWalletAddress, num: num)
            } else {
                printError("You must specify a valid wallet address!")
            }
        case .peers:
            listPeers()
        }
    }
    
    func mine(minerAddress: Data, num: Int = 1) {
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
    
    func createWallet(named: String, keychain: Bool = false) {
        if let wallet = Wallet(name: named, storeInKeychain: keychain) {
            print("💳 Created wallet '\(named)'\(keychain ? " (stored in keychain)".dim : "")")
            print("  🔑 Public: \(wallet.publicKey.hex)".dim)
            print("  🔐 Private: \(wallet.exportPrivateKey()!.hex)".dim)
            print("  📥 Address: \(wallet.address.hex)".dim)
        } else {
            printError("Could not create wallet!")
        }
    }
    
    func deleteWallet(named name: String) {
        if Keygen.clearKeychainKeys(name: name) {
            print("💳 '\(name)' successfully deleted")
        } else {
            printError("Unable to delete wallet '\(name)'")
        }
    }
    
    func listWallets() {
        let walletNames = Keygen.avalaibleKeyPairsNames()
        let wallets = walletNames.map { Wallet(name: $0, keyPair: Keygen.loadKeyPairFromKeychain(name: $0)!) }
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
    
    func walletBalance(walletAddress: Data) {
        let balance = node.blockchain.balance(for: walletAddress)
        print("💰 \(balance)")
    }
    
    func send(from: Wallet, to: Data, value: UInt64) {
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
    
    func listPeers() {
        print("🌐 Known peers:")
        for peer in node.peers {
            print("  \(peer.urlString)")
        }
    }
}
