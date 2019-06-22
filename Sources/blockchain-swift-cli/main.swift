import Foundation

let runAsCentralNode = CommandLine.argc == 2 && Flag(rawValue: CommandLine.arguments[1]) != nil
let cli = CLI(runAsCentralNode: runAsCentralNode)
cli.interactiveMode()
CFRunLoopRun()
