import Foundation
import BlockchainSwift

func prompt(_ prompt: String) {
    print(prompt, terminator: "")
    fflush(stdout)
}

func printError(_ error: String) {
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
    
    func blue() -> String {
        return "\u{001B}[34m\(self)\u{001B}[0m"
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
        case help
        case exit
        
        var usage: [String] {
            switch self {
            case .wallet:
                return WalletSubCommand.allCases.map { "\(rawValue.bold()) \($0.usage) \($0.info.dim())" }
            case .mine:
                return ["\(rawValue.bold()) [wallet address] \(info.dim())"]
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
                return "\(rawValue.underline()) [wallet address]"
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
        case central = "--central"
    }

    let node: Node
    
    init(type: Node.NodeType) {
        print("🏃🏻‍♂️ Running Node! (\(type.rawValue))")
        let state = Node.loadState()
        if let bc = state.blockchain {
            print("⛓  Blockchain: \(bc.blocks.count) blocks, latest hash: \(bc.lastBlockHash().hex)")
        }
        if let mp = state.mempool {
            print("🚰 Mempool: \(mp.count) transactions")
        }
        print("Connecting node to network...".dim())
        fflush(stdout)
        node = Node(type: type, blockchain: state.blockchain, mempool: state.mempool)
        class Delegate: NodeDelegate {
            let initialSyncCompleteClosure: () -> Void
            
            init(initialSyncCompleteClosure closure: @escaping () -> Void) {
                initialSyncCompleteClosure = closure
            }
            
            func nodeDidConnectToNetwork(_ node: Node) {
                print("🚦 Connected".green())
                initialSyncCompleteClosure()
            }
            func node(_ node: Node, didAddPeer: NodeAddress) {
                print("← ".blue() + "\(didAddPeer.urlString) connected".dim())
            }
            func node(_ node: Node, didCreateTransactions transactions: [Transaction]) {
                print("✔ ".blue() + "Transaction created")
            }
            func node(_ node: Node, didSendTransactions transactions: [Transaction]) {
                print("→ ".blue() + "Sent \(transactions.count) transactions".dim())
            }
            func node(_ node: Node, didReceiveTransactions transactions: [Transaction]) {
                print("← ".blue() + "Received \(transactions.count) transactions".dim())
            }
            func node(_ node: Node, didCreateBlocks blocks: [Block]) {
                print("🎉 Mined block! \(blocks.first!.hash.hex)")
            }
            func node(_ node: Node, didSendBlocks blocks: [Block]) {
                print("→ ".blue() + "Sent \(blocks.count) blocks".dim())
            }
            func node(_ node: Node, didReceiveBlocks blocks: [Block]) {
                print("← ".blue() + "Got \(blocks.count) blocks".dim())
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
    
    func getInput() -> String {
        let keyboard = FileHandle.standardInput
        let inputData = keyboard.availableData
        let strData = String(data: inputData, encoding: String.Encoding.utf8)!
        return strData.trimmingCharacters(in: CharacterSet.newlines)
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
                        printError("You must specify a valid wallet address!")
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
                            printError("Could not load wallet named \(args[2])")
                            return
                        }
                        let wallet = Wallet(name: args[2], keyPair: keys)
                        guard let toData = Data(walletAddress: args[3]) else {
                            printError("You must specify a valid recipient address")
                            return
                        }
                        guard let valueInput = UInt64(args[4]) else {
                            printError("You must specify a valid value")
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
                mine(minerAddress: validWalletAddress)
            } else {
                printError("You must specify a valid wallet address!")
            }
        }
    }

    func printAvailableCommands() {
        print("  Available commands:")
        Command.allCases.forEach {
            printCommand($0)
        }
    }
    
    func printCommand(_ command: Command) {
        for usage in command.usage {
            print("    \(String.prompt) \u{001B}[1m\(usage)\u{001B}[22m")
        }
    }
    
    func interactiveMode() {
        printAvailableCommands()
        while true {
            prompt(String.prompt.bold().green())
            parseInput(getInput().components(separatedBy: " "))
        }
    }
    
    func mine(minerAddress: Data) {
        let minerGroup = DispatchGroup()
        minerGroup.enter()
        let queue = DispatchQueue(label: "mine", attributes: .concurrent)
        queue.async {
            while true {
                let _ = self.node.mineBlock(minerAddress: minerAddress)
                self.node.saveState()
            }
        }
        minerGroup.wait()
    }
    
    func createWallet(named: String, keychain: Bool = false) {
        if let wallet = Wallet(name: named, storeInKeychain: keychain) {
            print("💳 Created wallet '\(named)'\(keychain ? " (stored in keychain)" : "")")
            print("  🔑 Public: \(wallet.publicKey.hex)")
            print("  🔐 Private: \(wallet.exportPrivateKey()!.hex)")
            print("  📥 Address: \(wallet.address.hex)")
        } else {
            print("Error: Could not create wallet!")
        }
    }
    
    func listWallets() {
        printError("Unsupported")
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
}

func interceptSigint(_ handleSigint: @escaping () -> Void) {
    signal(SIGINT, SIG_IGN) // // Make sure the signal does not terminate the application.
    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigintSrc.setEventHandler {
        print("Got SIGINT")
        handleSigint()
    }
    sigintSrc.resume()
    dispatchMain()
}

func run() {
    let type: Node.NodeType = CommandLine.argc == 2 && CLI.Flag(rawValue: CommandLine.arguments[1]) != nil ? .central : .peer
    let cli = CLI(type: type)
    cli.interactiveMode()
}

run()

