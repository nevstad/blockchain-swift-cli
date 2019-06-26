//
//  main.swift
//  BlockchainSwiftCLI
//
//  Created by Magnus Nevstad on 26/06/2019.
//  Copyright © 2019 Magnus Nevstad. All rights reserved.
//

import Foundation

let runAsCentralNode = CommandLine.argc == 2 && Flag(rawValue: CommandLine.arguments[1]) != nil
let cli = CLI(runAsCentralNode: runAsCentralNode)
cli.interactiveMode()
CFRunLoopRun()
