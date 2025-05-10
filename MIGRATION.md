# Migrating from Reachability to Reachable

This guide helps developers migrate from the legacy Reachability implementation to the new Reachable package.

## Overview of Key Differences

| Feature | Reachability | Reachable |
|---------|-------------|---------------|
| API | Callback and notification-based | Combine publishers, DI, and notifications |
| Framework | SystemConfiguration | Network (modern Apple API) |
| Dependency Injection | Not supported | Fully supported via PointFree Dependencies |
| Persistence | Not built-in | Built-in state persistence |
| Reactive Programming | Not supported | First-class Combine support |
| Test Support | Limited | Comprehensive mock implementation |

## Step-by-Step Migration Guide

### 1. Update Package Dependencies

In your `Package.swift` or Xcode project, replace the Reachability dependency with Reachable.

```swift
// Before:
.package(url: "path/to/Reachability", from: "x.x.x"),

// After:
.package(path: "../Reachable"),
```

### 2. Import the New Module

```swift
// Before:
import Reachability

// After:
import Reachable
```

### 3. Updating Code That Creates Reachability Instances

```swift
// Before:
private var reachability: Reachability?

func setupReachability() {
    do {
        reachability = try Reachability()
        try reachability?.startNotifier()
    } catch {
        print("Could not start reachability notifier")
    }
}

// After:
@Dependency(\.connection) private var connection

func setupNetworkMonitoring() {
    connection.startMonitoring()
}
```

### 4. Checking Connection Status

```swift
// Before:
if reachability?.connection != .unavailable {
    // Online
} else {
    // Offline
}

// After:
if connection.isConnected {
    // Online
} else {
    // Offline
}
```

### 5. Checking Connection Type

```swift
// Before:
switch reachability?.connection {
case .cellular:
    // Cellular connection
case .wifi:
    // WiFi connection
default:
    // No connection
}

// After:
if let interfaceType = connection.interfaceType {
    switch interfaceType {
    case .cellular:
        // Cellular connection
    case .wifi:
        // WiFi connection
    case .wiredEthernet:
        // Wired connection (not available in Reachability)
    default:
        // Other connection type
    }
} else {
    // No connection
}
```

### 6. Observing Connection Changes

#### Using Notifications

```swift
// Before:
NotificationCenter.default.addObserver(
    self,
    selector: #selector(reachabilityChanged),
    name: .reachabilityChanged,
    object: reachability
)

@objc func reachabilityChanged(notification: Notification) {
    guard let reachability = notification.object as? Reachability else { return }
    
    if reachability.connection != .unavailable {
        // Online
    } else {
        // Offline
    }
}

// After:
NotificationCenter.default.addObserver(
    self,
    selector: #selector(connectionStateChanged),
    name: .connectionStateDidChange,
    object: nil
)

@objc func connectionStateChanged(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let isConnected = userInfo["isConnected"] as? Bool else { return }
    
    if isConnected {
        // Online
    } else {
        // Offline
    }
}
```

#### Using Reactive Approach (New in Reachable)

```swift
// This approach wasn't available in Reachability
import Combine

private var cancellables = Set<AnyCancellable>()

func observeNetworkStatus() {
    connection.statePublisher
        .receive(on: RunLoop.main)
        .sink { [weak self] isConnected in
            if isConnected {
                // Online
            } else {
                // Offline
            }
        }
        .store(in: &cancellables)
}
```

### 7. Cleanup

```swift
// Before:
deinit {
    reachability?.stopNotifier()
    NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: nil)
}

// After:
deinit {
    // No need to stop monitoring if it's a global singleton
    // For component-level monitoring:
    // connection.stopMonitoring()
    
    NotificationCenter.default.removeObserver(self, name: .connectionStateDidChange, object: nil)
}
```

### 8. Migrating Code Using Callbacks

```swift
// Before:
reachability?.whenReachable = { reachability in
    // Handle reachable state
}

reachability?.whenUnreachable = { reachability in
    // Handle unreachable state
}

// After:
// Using Combine:
connection.statePublisher
    .receive(on: RunLoop.main)
    .sink { isConnected in
        if isConnected {
            // Handle reachable state
        } else {
            // Handle unreachable state
        }
    }
    .store(in: &cancellables)
```

## Migration for LiveObjectsStore

Here's how to migrate the code in `LiveObjectsStore` from using Reachability to Reachable:

```swift
// Before:
@Dependency(\.apiClient) var apiClient
@Dependency(\.modelStore) var modelStore
// ...other dependencies

private lazy var reachability = try? Reachability()  

private func isOnline() -> Bool {
   guard reachability?.connection != .unavailable else {
      return false
    }
    return true
}

// After:
@Dependency(\.apiClient) var apiClient
@Dependency(\.modelStore) var modelStore
@Dependency(\.connection) var connection
// ...other dependencies

private func isOnline() -> Bool {
    return connection.isConnected
}
```

## Integration with AppDelegate

```swift
// In AppDelegate.swift
import Reachable
import Dependencies

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    @Dependency(\.connection) private var connection
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Start the connection monitor early in the app lifecycle
        connection.startMonitoring()
        
        return true
    }
} 