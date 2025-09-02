// Copyright (c) Daniel Bernal 2025

import Network
import Foundation
import Combine

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
    
    public init(userDefaults: UserDefaults = .standard, storageKey: String = "connectionkit.connection.state") {
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
    private var simulatorTimer: Timer?
    
    /// State management
    private let lock = NSLock()
    private var _currentConnectionState: Bool = false
    private var _currentPath: NWPath?
    private var _hasEmittedInitialState = false
    
    /// Subject for Combine integration - will be initialized with correct initial state
    private var stateSubject: CurrentValueSubject<Bool, Never>?
    
    /// Publisher for connection state changes
    public var statePublisher: AnyPublisher<Bool, Never> {
        // Thread-safe access to subject
        lock.lock()
        let subject = stateSubject
        lock.unlock()
        
        if let subject = subject {
            // Subject is ready with correct initial state
            return subject.eraseToAnyPublisher()
        } else {
            // Subject not ready yet, return a deferred publisher that waits
            return Deferred {
                Future<Bool, Never> { [weak self] promise in
                    func checkForSubject() {
                        guard let self = self else { return }
                        
                        self.lock.lock()
                        let currentSubject = self.stateSubject
                        self.lock.unlock()
                        
                        if let subject = currentSubject {
                            // Subject is ready, fulfill with current value and switch to subject
                            promise(.success(subject.value))
                        } else {
                            // Still waiting, check again soon
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                checkForSubject()
                            }
                        }
                    }
                    checkForSubject()
                }
                .flatMap { [weak self] initialValue in
                    // After getting initial value, switch to the actual subject
                    guard let self = self else {
                        return Empty<Bool, Never>().eraseToAnyPublisher()
                    }
                    
                    self.lock.lock()
                    let subject = self.stateSubject
                    self.lock.unlock()
                    
                    return subject?.eraseToAnyPublisher() ?? Empty<Bool, Never>().eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
        }
    }
    
    /// Thread-safe access to connection state
    public var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
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
    
    /// The current connection interface type
    public var interfaceType: NWInterface.InterfaceType? {
        // On simulator, we'll always return wifi when connected
        if isRunningOnSimulator {
            return isConnected ? .wifi : nil
        }
        
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
        queueLabel: String = "com.connectionkit.queue",
        qos: DispatchQoS = .utility,
        memory: ConnectionMemory = DefaultConnectionMemory(),
        autoStart: Bool = true
    ) {
        self.monitor = NWPathMonitor()
        self.monitorQueue = DispatchQueue(label: queueLabel, qos: qos)
        self.memory = memory
        
        // Don't create the subject yet - wait for real initial state from monitor
        // This prevents the false initial state emission that causes inversion issues
        self._currentConnectionState = false  // Temporary placeholder
        
        setupMonitor()
        
        if autoStart {
            startMonitoring()
            
            // Start simulator fallback if needed
            if isRunningOnSimulator {
                startSimulatorFallback()
            }
        }
    }
    
    private func setupMonitor() {
        // On simulator, we completely ignore NWPathMonitor
        if isRunningOnSimulator {
            // Set up initial state
            lock.lock()
            _hasEmittedInitialState = false
            _currentConnectionState = false
            lock.unlock()
            return
        }
        
        // Device: Use normal NWPathMonitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let newIsConnected = path.status == .satisfied
            
            // Update state atomically and check if this is initial state or a real change
            self.lock.lock()
            let previousConnected = self._currentConnectionState
            let hasEmittedInitial = self._hasEmittedInitialState
            self._currentConnectionState = newIsConnected
            self._currentPath = path
            
            if !hasEmittedInitial {
                // This is the REAL initial state detection - could be online OR offline
                self._hasEmittedInitialState = true
                
                // Create subject with the actual initial state (not false assumption)
                self.stateSubject = CurrentValueSubject<Bool, Never>(newIsConnected)
                self.lock.unlock()
                
                
                // Save to memory but don't post notification - this is initial detection, not a change
                self.memory.saveConnectionState(newIsConnected)
                
            } else {
                // This is a real state change after initial state was established
                let stateChanged = previousConnected != newIsConnected
                self.lock.unlock()
                
                
                // Only emit and notify if state actually changed
                if stateChanged {
                    // Thread-safe subject update
                    self.lock.lock()
                    let subject = self.stateSubject
                    self.lock.unlock()
                    
                    subject?.send(newIsConnected)
                    self.memory.saveConnectionState(newIsConnected)
                    
                    // Post notification for real state changes only
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .connectionStateDidChange,
                            object: self,
                            userInfo: ["isConnected": newIsConnected]
                        )
                    }
                }
            }
        }
    }
    
    /// Check if running on iOS Simulator
    private var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    /// Start simulator-specific fallback monitoring
    /// iOS Simulator doesn't always trigger NWPathMonitor updates properly
    private func startSimulatorFallback() {
        // Start with immediate check
        checkSimulatorNetworkState()
        
        // Then check every 2 seconds
        simulatorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkSimulatorNetworkState()
        }
    }
    
    /// Check network state on simulator using URLSession only
    private func checkSimulatorNetworkState() {
        Task { [weak self] in
            guard let self = self else { return }
            
            // Perform connectivity check
            let isConnected = await self.performSimulatorConnectivityCheck()
            
            // Update state
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                
                self.lock.lock()
                let previousState = self._currentConnectionState
                let hasEmittedInitial = self._hasEmittedInitialState
                self._currentConnectionState = isConnected
                
                if !hasEmittedInitial {
                    // First time - emit initial state
                    self._hasEmittedInitialState = true
                    self.stateSubject = CurrentValueSubject<Bool, Never>(isConnected)
                    self.lock.unlock()
                    
                    // Save to memory
                    self.memory.saveConnectionState(isConnected)
                } else {
                    // Check if state changed
                    let stateChanged = previousState != isConnected
                    self.lock.unlock()
                    
                    if stateChanged {
                        // State changed - update everything
                        self.lock.lock()
                        let subject = self.stateSubject
                        self.lock.unlock()
                        
                        subject?.send(isConnected)
                        self.memory.saveConnectionState(isConnected)
                        
                        // Post notification
                        NotificationCenter.default.post(
                            name: .connectionStateDidChange,
                            object: self,
                            userInfo: ["isConnected": isConnected]
                        )
                    }
                }
            }
        }
    }
    
    /// Perform actual network connectivity check for simulator
    private func performSimulatorConnectivityCheck() async -> Bool {
        // Use a lightweight connectivity check with timeout
        let url = URL(string: "https://captive.apple.com/hotspot-detect.html")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"  // Only get headers, not full content
        request.timeoutInterval = 3.0  // 3 second timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // Configure URLSession to handle network transitions better
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false  // Don't wait, we want immediate result
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        
        let session = URLSession(configuration: config)
        
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // Apple's captive portal returns 200 when connected
                return httpResponse.statusCode == 200
            }
        } catch let error as NSError {
            // Log only non-transient errors for debugging
            if error.code != -1009 && error.code != -1001 {  // -1009: offline, -1001: timeout
                print("[ConnectionKit] Simulator connectivity check error: \(error.localizedDescription)")
            }
            return false
        }
        
        return false
    }
    
    
    /// Start monitoring connectivity (automatically called during initialization unless autoStart is false)
    private func startMonitoring() {
        // On simulator, don't start NWPathMonitor at all
        if !isRunningOnSimulator {
            monitor.start(queue: monitorQueue)
        }
    }
    
    /// Stop monitoring connectivity
    public func stopMonitoring() {
        monitor.cancel()
        simulatorTimer?.invalidate()
        simulatorTimer = nil
    }
    
    /// Get the last remembered connection state
    public func rememberedConnectionState() -> Bool {
        return memory.rememberConnectionState()
    }
    
    deinit {
        stopMonitoring()
    }
}

/// Alternative name for the Connection class - use when you need to disambiguate from the protocol
public typealias LiveConnection = Connection