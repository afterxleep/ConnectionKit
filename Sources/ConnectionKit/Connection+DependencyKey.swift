// Copyright (c) Daniel Bernal 2025

import Foundation
import Network

#if canImport(Dependencies)
import Dependencies

/// Create a wrapper to act as the DependencyKey
public enum ConnectableKey: DependencyKey {
    public static var liveValue: Connectable {
        LiveConnection()
    }
    
    public static var testValue: Connectable {
        MockConnection()
    }
}

/// Extension adding connection monitor to DependencyValues
extension DependencyValues {
    /// Access the connection monitor through dependency injection
    public var connection: Connectable {
        get { self[ConnectableKey.self] }
        set { self[ConnectableKey.self] = newValue }
    }
}
#endif
