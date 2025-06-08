// Copyright (c) Daniel Bernal 2025

import Network
import Foundation
import Combine

/// Test implementation of Connectable for use in unit tests
public final class MockConnection: Connectable {
    private let lock = NSLock()
    private var _isConnected: Bool
    private var _interfaceType: NWInterface.InterfaceType?
    
    /// Whether the mock is connected
    public var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConnected
    }
    
    /// The mock interface type
    public var interfaceType: NWInterface.InterfaceType? {
        lock.lock()
        defer { lock.unlock() }
        return _interfaceType
    }
    
    private let stateSubject: CurrentValueSubject<Bool, Never>
    
    /// Publisher for connection state changes
    public var statePublisher: AnyPublisher<Bool, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    /// Initialize the mock connection with test values
    /// - Parameters:
    ///   - isConnected: Initial connectivity state
    ///   - interfaceType: Initial interface type
    public init(isConnected: Bool = true, interfaceType: NWInterface.InterfaceType? = .wifi) {
        self._isConnected = isConnected
        self._interfaceType = interfaceType
        self.stateSubject = CurrentValueSubject<Bool, Never>(isConnected)
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
        lock.lock()
        _isConnected = connected
        lock.unlock()
        
        // Emit on publisher
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
        lock.lock()
        _interfaceType = type
        lock.unlock()
    }
}