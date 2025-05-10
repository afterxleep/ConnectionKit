// Copyright (c) Daniel Bernal 2025

import Network
import Foundation
import Combine

/// Test implementation of Connectable for use in unit tests
public final class MockConnection: Connectable {
    /// Whether the mock is connected
    public private(set) var isConnected: Bool
    
    /// The mock interface type
    public private(set) var interfaceType: NWInterface.InterfaceType?
    
    private let stateSubject = CurrentValueSubject<Bool, Never>(false)
    
    /// Publisher for connection state changes
    public var statePublisher: AnyPublisher<Bool, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    /// Initialize the mock connection with test values
    /// - Parameters:
    ///   - isConnected: Initial connectivity state
    ///   - interfaceType: Initial interface type
    public init(isConnected: Bool = true, interfaceType: NWInterface.InterfaceType? = .wifi) {
        self.isConnected = isConnected
        self.interfaceType = interfaceType
        self.stateSubject.send(isConnected)
    }
    
    /// Start monitoring (no-op)
    public func startMonitoring() {
        // No-op for test implementation
    }
    
    /// Stop monitoring (no-op)
    public func stopMonitoring() {
        // No-op for test implementation
    }
    
    /// Get the remembered connection state
    public func rememberedConnectionState() -> Bool {
        return isConnected
    }
    
    /// Simulate connection change for testing
    /// - Parameter connected: New connection state
    public func simulateConnection(_ connected: Bool) {
        isConnected = connected
        stateSubject.send(connected)
        
        // Post notification for testing UI reactions
        NotificationCenter.default.post(
            name: .connectionStateDidChange,
            object: self,
            userInfo: ["isConnected": connected]
        )
    }
    
    /// Simulate interface type change for testing
    /// - Parameter type: New interface type
    public func simulateInterface(_ type: NWInterface.InterfaceType?) {
        interfaceType = type
    }
} 