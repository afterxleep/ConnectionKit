// Copyright (c) Daniel Bernal 2025

import Foundation
import Network

#if canImport(Dependencies)
import Dependencies

/// Extension to support PointFree Dependencies framework
extension Connectable: DependencyKey {
    /// Provide a live implementation for dependency injection
    public static var liveValue: Connectable {
        Connection()
    }
    
    /// Provide a test implementation for dependency injection
    public static var testValue: Connectable {
        MockConnection()
    }
}

/// Extension adding connection monitor to DependencyValues
public extension DependencyValues {
    /// Access the connection monitor through dependency injection
    var connection: Connectable {
        get { self[Connectable.self] }
        set { self[Connectable.self] = newValue }
    }
}
#endif 