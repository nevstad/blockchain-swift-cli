//
//  String+Terminal.swift
//  BlockchainSwift
//
//  Created by Magnus Nevstad on 22/05/2019.
//

import Foundation

func stripColors() -> Bool {
    return ProcessInfo.processInfo.environment["NO_COLOR"] != nil
}

extension String {
    var bold: String {
        if stripColors() { return self }
        return "\u{001B}[1m\(self)\u{001B}[22m"
    }
    
    var underline: String {
        if stripColors() { return self }
        return "\u{001B}[4m\(self)\u{001B}[24m"
    }
    
    var green: String {
        if stripColors() { return self }
        return "\u{001B}[32m\(self)\u{001B}[0m"
    }
    
    var red: String {
        if stripColors() { return self }
        return "\u{001B}[31m\(self)\u{001B}[0m"
    }
    
    var blue: String {
        if stripColors() { return self }
        return "\u{001B}[34m\(self)\u{001B}[0m"
    }
    var dim: String {
        if stripColors() { return self }
        return "\u{001B}[2m\(self)\u{001B}[22m"
    }
    
    static var prompt: String { return "> " }
}

extension String {
    var isYes: Bool {
        return self == "yes" || self == "y"
    }

    var isNo: Bool {
        return self == "no" || self == "n"
    }
    
    var isYesOrNo: Bool {
        return isYes || isNo
    }
}
