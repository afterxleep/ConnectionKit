// Copyright (c) Daniel Bernal 2025

import Network
import Foundation
import Combine
import OSLog

/// Notification sent when connection state changes
public extension Notification.Name {
    static let connectionStateDidChange = Notification.Name("connectionStateDidChange")
}

/// Protocol for connection state memory
public protocol ConnectionMemory {
    func rememberConnectionState() -> Bool
    func saveConnectionState(_ isConnected: Bool)
}

/// Default implementation using UserDefaults for persistence
public struct DefaultConnectionMemory: ConnectionMemory {
    private let userDefaults: UserDefaults
    private let storageKey: String
    
    public init(userDefaults: UserDefaults = .standard, storageKey: String = "reachable.connection.state") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }
    
    public func rememberConnectionState() -> Bool {
        return userDefaults.bool(forKey: storageKey)
    }
    
    public func saveConnectionState(_ isConnected: Bool) {
        userDefaults.set(isConnected, forKey: storageKey)
    }
}

/// Logger for connection monitoring
private extension Logger {
    static let reachableLogger = Logger(subsystem: "com.reachable", category: "Connection")
}

/// Protocol defining the core functionality of connection monitoring
public protocol Connectable {
    /// Whether the device currently has connectivity
    var isConnected: Bool { get }
    
    /// The current connection interface type (if connected)
    var interfaceType: NWInterface.InterfaceType? { get }
    
    /// A publisher that emits when connection state changes
    var statePublisher: AnyPublisher<Bool, Never> { get }
    
    /// Start monitoring connectivity
    func startMonitoring()
    
    /// Stop monitoring connectivity
    func stopMonitoring()
    
    /// Get the last remembered connection state
    func rememberedConnectionState() -> Bool
}

/// Live implementation of Connectable using NWPathMonitor
public final class Connection: Connectable {
    private let monitor: NWPathMonitor
    private let monitorQueue: DispatchQueue
    private let memory: ConnectionMemory
    
    /// Subject for Combine integration
    private let stateSubject = CurrentValueSubject<Bool, Never>(false)
    
    /// Publisher for connection state changes
    public var statePublisher: AnyPublisher<Bool, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    /// In-memory current path for immediate access and detailed info
    private var currentPath: NWPath?
    
    /// Whether the device is currently connected
    public var isConnected: Bool {
        guard let path = currentPath else {
            return rememberedConnectionState()
        }
        return path.status == .satisfied
    }
    
    /// The current connection interface type
    public var interfaceType: NWInterface.InterfaceType? {
        guard let path = currentPath, path.status == .satisfied else { return nil }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wiredEthernet }
        if path.usesInterfaceType(.loopback) { return .loopback }
        return nil
    }
    
    /// Initialize a connection monitor
    /// - Parameters:
    ///   - queueLabel: Label for the monitoring dispatch queue
    ///   - qos: Quality of service for the monitoring queue
    ///   - memory: Storage mechanism for connection state persistence
    public init(
        queueLabel: String = "com.reachable.queue",
        qos: DispatchQoS = .utility,
        memory: ConnectionMemory = DefaultConnectionMemory()
    ) {
        self.monitor = NWPathMonitor()
        self.monitorQueue = DispatchQueue(label: queueLabel, qos: qos)
        self.memory = memory
        
        setupMonitor()
        
        // Initialize with value from memory
        let initiallyConnected = rememberedConnectionState()
        stateSubject.send(initiallyConnected)
        
        Logger.reachableLogger.info("Connection monitor initialized with remembered state: \(initiallyConnected)")
    }
    
    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let previousStatus = self.currentPath?.status
            self.currentPath = path
            
            let currentIsConnected = path.status == .satisfied
            
            // Update connection subject
            self.stateSubject.send(currentIsConnected)
            
            // Remember the connection state
            self.memory.saveConnectionState(currentIsConnected)
            
            // Debugging output
            if previousStatus != path.status {
                Logger.reachableLogger.info("Connection status changed to: \(path.status == .satisfied ? "connected" : "disconnected")")
                if currentIsConnected {
                    if path.usesInterfaceType(.wifi) {
                        Logger.reachableLogger.info("Connection type: WiFi")
                    } else if path.usesInterfaceType(.cellular) {
                        Logger.reachableLogger.info("Connection type: Cellular, Expensive: \(path.isExpensive)")
                    } else if path.usesInterfaceType(.wiredEthernet) {
                        Logger.reachableLogger.info("Connection type: Ethernet")
                    }
                }
            }
            
            // Post a notification on the main thread
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .connectionStateDidChange,
                    object: self,
                    userInfo: ["isConnected": currentIsConnected]
                )
            }
        }
    }
    
    /// Start monitoring connectivity
    public func startMonitoring() {
        Logger.reachableLogger.info("Starting connection monitoring")
        monitor.start(queue: monitorQueue)
    }
    
    /// Stop monitoring connectivity
    public func stopMonitoring() {
        Logger.reachableLogger.info("Stopping connection monitoring")
        monitor.cancel()
    }
    
    /// Get the last remembered connection state
    public func rememberedConnectionState() -> Bool {
        return memory.rememberConnectionState()
    }
    
    deinit {
        stopMonitoring()
    }
}

/// Singleton accessor for use in non-DI applications
public extension Connection {
    /// Shared instance for use when not using dependency injection
    static let shared: Connection = {
        let connection = Connection()
        return connection
    }()
} 