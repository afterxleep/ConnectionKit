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
    
    public init(userDefaults: UserDefaults = .standard, storageKey: String = "connectable.connection.state") {
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
    static let connectableLogger = Logger(subsystem: "com.connectable", category: "Connection")
}

/// Protocol defining the core functionality of connection monitoring
public protocol Connectable {
    /// Whether the device currently has connectivity
    var isConnected: Bool { get }
    
    /// The current connection interface type (if connected)
    var interfaceType: NWInterface.InterfaceType? { get }
    
    /// A publisher that emits when connection state changes
    var statePublisher: AnyPublisher<Bool, Never> { get }
    
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
    
    /// State management
    private let lock = NSLock() // Thread safety mechanism
    private var _currentConnectionState: Bool = false // Will be set to actual state during init
    private var _currentPath: NWPath?
    
    /// Subject for Combine integration
    private let stateSubject: CurrentValueSubject<Bool, Never>
    
    /// Publisher for connection state changes
    public var statePublisher: AnyPublisher<Bool, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    /// Thread-safe access to connection state
    public var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        Logger.connectableLogger.debug("Reading isConnected property: \(self._currentConnectionState)")
        return _currentConnectionState
    }
    
    /// Thread-safe access to current path
    private var currentPath: NWPath? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentPath
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _currentPath = newValue
        }
    }
    
    /// Thread-safe setter for connection state that ensures publisher and property stay in sync
    private func setConnectionState(_ newState: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        // Only update if state changes
        if self._currentConnectionState != newState {
            Logger.connectableLogger.info("Connection state changing: \(self._currentConnectionState) -> \(newState)")
            _currentConnectionState = newState
            
            // Only send to subject when state actually changes
            stateSubject.send(newState)
            
            // Save to memory
            memory.saveConnectionState(newState)
        }
    }
    
    /// The current connection interface type
    public var interfaceType: NWInterface.InterfaceType? {
        guard let path = currentPath, isConnected else { return nil }
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
    ///   - autoStart: Whether to automatically start monitoring (default: true)
    public init(
        queueLabel: String = "com.connectable.queue",
        qos: DispatchQoS = .utility,
        memory: ConnectionMemory = DefaultConnectionMemory(),
        autoStart: Bool = true
    ) {
        self.monitor = NWPathMonitor()
        self.monitorQueue = DispatchQueue(label: queueLabel, qos: qos)
        self.memory = memory
        
        // Get current network path immediately to determine actual state
        let initialPath = monitor.currentPath
        let currentlyConnected = initialPath.status == .satisfied
        
        // Initialize with actual network state instead of optimistic true
        self._currentConnectionState = currentlyConnected
        self.stateSubject = CurrentValueSubject<Bool, Never>(currentlyConnected)
        
        Logger.connectableLogger.info("Connection monitor initializing with actual state: \(currentlyConnected)")
        
        setupMonitor()
        
        // Set the current path
        self.currentPath = initialPath
        
        Logger.connectableLogger.info("Connection monitor initialized with state: \(currentlyConnected)")
        
        if autoStart {
            startMonitoring()
        }
    }
    
    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            // Get previous state for comparison
            let previousConnected = self.isConnected
            let previousPath = self.currentPath
            
            // Update internal path
            self.currentPath = path
            
            // Get new connection state from path
            let currentIsConnected = path.status == .satisfied
            
            // Update connection state
            self.setConnectionState(currentIsConnected)
            
            // Debugging output if state changed
            if previousConnected != currentIsConnected {
                Logger.connectableLogger.info("Connection status changed: \(previousConnected) -> \(currentIsConnected)")
                
                if let prevPath = previousPath {
                    Logger.connectableLogger.debug("Previous path: \(String(describing: prevPath))")
                }
                Logger.connectableLogger.debug("Current path: \(String(describing: path))")
                
                if currentIsConnected {
                    if path.usesInterfaceType(.wifi) {
                        Logger.connectableLogger.info("Connection type: WiFi")
                    } else if path.usesInterfaceType(.cellular) {
                        Logger.connectableLogger.info("Connection type: Cellular, Expensive: \(path.isExpensive)")
                    } else if path.usesInterfaceType(.wiredEthernet) {
                        Logger.connectableLogger.info("Connection type: Ethernet")
                    }
                }
                
                // Post a notification on the main thread for UI updates
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .connectionStateDidChange,
                        object: self,
                        userInfo: ["isConnected": currentIsConnected]
                    )
                }
            }
        }
    }
    
    /// Start monitoring connectivity (automatically called during initialization unless autoStart is false)
    private func startMonitoring() {
        Logger.connectableLogger.info("Starting connection monitoring")
        monitor.start(queue: monitorQueue)
    }
    
    /// Stop monitoring connectivity
    public func stopMonitoring() {
        Logger.connectableLogger.info("Stopping connection monitoring")
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