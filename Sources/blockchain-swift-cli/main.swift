import Foundation

let runAsCentralNode = CommandLine.argc == 2 && Flag(rawValue: CommandLine.arguments[1]) != nil
let cli = CLI(runAsCentralNode: runAsCentralNode)
DispatchQueue.global().async {
    cli.interactiveMode()
}
dispatchMain()

