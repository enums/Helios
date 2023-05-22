//
//  HeliosSignalTrap.swift
//  
//
//  Created by Yuu Zheng on 2/26/23.
//

import Foundation

public typealias HeliosSignal = Int32
public typealias HeliosSignalHandler = @convention(c) (Int32) -> (Void)

public class HeliosSignalTrap {

    public static var shared = HeliosSignalTrap()
    private init() { }

    public var dispatchQueue = DispatchQueue(label: "signal_trap")

    public func trap(signal: HeliosSignal, handler: @escaping HeliosSignalHandler) {
        #if os(macOS)
            var signalAction = sigaction(__sigaction_u: unsafeBitCast(handler, to: __sigaction_u.self), sa_mask: 0, sa_flags: 0)
            _ = withUnsafePointer(to: &signalAction) { actionPointer in
                sigaction(signal, actionPointer, nil)
            }
        #else
            var sigAction = sigaction()
            sigAction.__sigaction_handler = unsafeBitCast(handler, to: sigaction.__Unnamed_union___sigaction_handler.self)
            _ = sigaction(signal, &sigAction, nil)
        #endif
    }

}
