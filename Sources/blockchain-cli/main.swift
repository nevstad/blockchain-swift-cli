import Foundation
import BlockchainSwift

func prompt(_ prompt: String) {
    print(prompt, terminator: "")
    fflush(stdout)
}

func error(_ error: String) {
    print("Error: ".red() + error)
}

extension String {
    func bold() -> String {
        return "\u{001B}[1m\(self)\u{001B}[22m"
    }
    
    func underline() -> String {
        return "\u{001B}[4m\(self)\u{001B}[24m"
    }
    
    func green() -> String {
        return "\u{001B}[32m\(self)\u{001B}[0m"
    }
    
    func red() -> String {
        return "\u{001B}[31m\(self)\u{001B}[0m"
    }
    func dim() -> String {
        return "\u{001B}[2m\(self)\u{001B}[22m"
    }
    
    static var prompt: String { return "> " }
}

extension Data {
    init?(walletAddress: String) {
        if let data = Data(hex: walletAddress), data.count == 32 {
            self = data
        } else {
            return nil
        }
    }
}

class CLI {
    enum Command: String, CaseIterable {
        case wallet
        case mine
        case central
        case help
        case exit
        
        var usage: [String] {
            switch self {
            case .wallet:
                return WalletSubCommand.allCases.map { "\(rawValue.bold()) \($0.usage) \($0.info.dim())" }
            case .mine:
                return ["\(rawValue.bold()) [wallet address] \(info.dim())"]
            case .central:
                return ["\(rawValue.bold()) <wallet address> \(info.dim())"]
            default:
                return [rawValue.bold()]
            }
        }
        
        var info: String {
            switch self {
            case .wallet:
                return "- Create or list wallets stored in keychain."
            case .mine:
                return "- Start minig blocks. Requires a wallet address, for block rewards."
            case .central:
                return "- Run a central node."
            default:
                return ""
            }
        }
    }
    
    enum WalletSubCommand: String, CaseIterable {
        case create
        case list
        case balance
        case send
        
        var usage: String {
            switch self {
            case .create:
                return "\(rawValue.underline()) [wallet name] <--keychain|-kc>"
            case .list:
                return "\(rawValue.underline())"
            case .balance:
                return "\(rawValue.underline()) [address]"
            case .send:
                return "\(rawValue.underline()) [wallet name] [to address] [value]"
            }
        }
        
        var info: String {
            switch self {
            case .create:
                return "- Create a wallet, optionally stored in keychain."
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
    }

    static func getInput() -> String {
        let keyboard = FileHandle.standardInput
        let inputData = keyboard.availableData
        let strData = String(data: inputData, encoding: String.Encoding.utf8)!
        return strData.trimmingCharacters(in: CharacterSet.newlines)
    }
    
    static func parseInput(_ args: [String]) {
        let cmds = args.compactMap { Command(rawValue: $0) }
        let subcmds = args.compactMap { WalletSubCommand(rawValue: $0) }
        let flags = args.compactMap { Flag(rawValue: $0) }
        guard let cmd = cmds.first else {
            error("Unknown command")
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
                    let interactive = args.count < 3
                    if interactive { prompt("Enter wallet name: ".dim()) }
                    let name = interactive ? getInput() : args[2]
                    createWallet(named: name, keychain: flags.contains(.keychain) || flags.contains(.keychainLong))
                case .list:
                    listWallets()
                case .balance:
                    let interactive = args.count < 3
                    if interactive { prompt("Enter wallet address: ".dim()) }
                    let walletAddress = interactive ? getInput() : args[2]
                    if let validWalletAddress = Data(walletAddress: walletAddress) {
                        walletBalance(walletAddress: validWalletAddress)
                    } else {
                        error("You must specify a valid wallet address!")
                    }
                case .send:
                    let interactive = args.count < 5
                    var from: Wallet?
                    var to = Data()
                    var value: UInt64 = 0
                    if interactive {
                        printCommand(cmd)
                        return
                    } else {
                        guard let keys = Keygen.loadKeyPairFromKeychain(name: args[2]) else {
                            error("Could not load wallet named \(args[2])")
                            return
                        }
                        let wallet = Wallet(name: args[2], keyPair: keys)
                        guard let toData = Data(walletAddress: args[3]) else {
                            error("You must specify a valid recipient address")
                            return
                        }
                        guard let valueInput = UInt64(args[4]) else {
                            error("You must specify a valid value")
                            return
                        }
                        from = wallet
                        to = toData
                        value = valueInput
                    }
                    send(from: from!, to: to, value: value)
                }
            } else {
                printCommand(cmd)
            }
        case .mine:
            let interactive = args.count < 2
            if interactive { prompt("Enter wallet address: ".dim()) }
            let walletAddress = interactive ? getInput() : args[1]
            if let validWalletAddress = Data(walletAddress: walletAddress) {
                runNode(type: .peer, minerAddress: validWalletAddress)
            } else {
                error("You must specify a valid wallet address!")
            }
        case .central:
            let interactive = args.count < 2
            if interactive { prompt("Enter wallet address: ".dim()) }
            let walletAddress = interactive ? getInput() : args[1]
            if walletAddress.isEmpty {
                runNode(type: .central, minerAddress: nil)
            }
            if let validWalletAddress = Data(walletAddress: walletAddress) {
                runNode(type: .central, minerAddress: validWalletAddress)
            } else {
                error("You must specify a valid wallet address!")
            }
        }
    }

    static func printAvailableCommands() {
        print("  Available commands:")
        Command.allCases.forEach {
            printCommand($0)
        }
    }
    
    static func printCommand(_ command: Command) {
        for usage in command.usage {
            print("    \(String.prompt) \u{001B}[1m\(usage)\u{001B}[22m")
        }
    }
    
    static func interactiveMode() {
        printAvailableCommands()
        while true {
            prompt(String.prompt.bold().green())
            parseInput(getInput().components(separatedBy: " "))
        }
    }
    
    static func runNode(type: Node.NodeType, minerAddress: Data?) {
        print("🏃🏻‍♂️ Running Node! (\(type.rawValue))")
        let state = Node.loadState()
        if let bc = state.blockchain {
            print("⛓  Blockchain: \(bc.blocks.count) blocks, latest hash: \(bc.lastBlockHash().hex)")
        }
        if let mp = state.mempool {
            print("🚰 Mempool: \(mp.count) transactions")
        }
        if let wa = minerAddress {
            print("🛠  Mining with address: \(wa.hex)")
        }
        let node = Node(type: type, blockchain: state.blockchain, mempool: state.mempool)
        while true {
            if let minerAddress = minerAddress {
                let block = node.mineBlock(minerAddress: minerAddress)
                node.saveState()
                print("🎉 Mined block → \(block.hash.hex)")
            } else {
                continue
            }
        }
    }
    
    static func createWallet(named: String, keychain: Bool = false) {
        if let wallet = Wallet(name: named, storeInKeychain: keychain) {
            print("💳 Created wallet '\(named)'\(keychain ? " (stored in keychain)" : "")")
            print("🔑 Public: \(wallet.publicKey.hex)")
            print("🔐 Private: \(wallet.exportPrivateKey()!.hex)")
            print("📥 Address: \(wallet.address.hex)")
        } else {
            print("Error: Could not create wallet!")
        }
    }
    
    static func listWallets() {
        error("Unsupported")
    }
    
    static func walletBalance(walletAddress: Data) {
        let state = Node.loadState()
        if let blockchain = state.blockchain {
            let balance = blockchain.balance(for: walletAddress)
            print("💰 \(balance)")
        } else {
            error("Could not load local blockchain")
        }
    }
    
    static func send(from: Wallet, to: Data, value: UInt64) {
        class Delegate: NodeDelegate {
            func nodeDidConnectToNetwork(_ node: Node) {
                print("Synced".dim())
                do {
                    let _ = try node.createTransaction(sender: from, recipientAddress: to, value: value)
                } catch Node.TxError.insufficientBalance {
                    error("Insufficient balance")
                    completion()
                } catch Node.TxError.invalidValue {
                    error("Invalid value")
                    completion()
                } catch Node.TxError.unverifiedTransaction {
                    error("Unable to verify transaction")
                    completion()
                } catch Node.TxError.sourceEqualDestination {
                    error("You can't send to yourself")
                    completion()
                } catch {
                    completion()
                }
            }
            func node(_ node: Node, didAddPeer: NodeAddress) {}
            func node(_ node: Node, didCreateTransactions transactions: [Transaction]) {}
            func node(_ node: Node, didSendTransactions transactions: [Transaction]) {
                completion()
            }
            func node(_ node: Node, didReceiveTransactions transactions: [Transaction]) {}
            func node(_ node: Node, didCreateBlocks blocks: [Block]) {}
            func node(_ node: Node, didSendBlocks blocks: [Block]) {}
            func node(_ node: Node, didReceiveBlocks blocks: [Block]) {}
            
            let completion: () -> Void
            let from: Wallet
            let to: Data
            let value: UInt64
            init(from: Wallet, to: Data, value: UInt64, completion: @escaping () -> Void) {
                self.from = from
                self.to = to
                self.value = value
                self.completion = completion
            }
        }
        var done = false
        let delegate = Delegate(from: from, to: to, value: value) {
            done = true
        }
        let state = Node.loadState()
        let node = Node(blockchain: state.blockchain, mempool: state.mempool)
        node.delegate = delegate
//        do {
//            let _ = try node.createTransaction(sender: from, recipientAddress: to, value: value)
//        } catch Node.TxError.insufficientBalance {
//            error("Insufficient balance")
//            done = true
//        } catch Node.TxError.invalidValue {
//            error("Invalid value")
//            done = true
//        } catch Node.TxError.unverifiedTransaction {
//            error("Unable to verify transaction")
//            done = true
//        } catch Node.TxError.sourceEqualDestination {
//            error("You can't send to yourself")
//            done = true
//        } catch {
//            done = true
//        }

        while !done {
            continue
        }
    }
}

func run() {
    if CommandLine.argc == 1 {
        CLI.interactiveMode()
    } else {
        CLI.parseInput(Array(CommandLine.arguments.dropFirst()))
    }
}

run()
