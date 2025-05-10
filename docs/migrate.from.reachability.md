# Migrating from Reachability to Connectable

This guide helps developers migrate from the legacy Reachability implementation to the new Connectable package.

> **Important Note about Async Usage**: 
> When accessing `isConnected` or `interfaceType` properties:
> - In regular `Task` blocks: `await` is NOT required
> - In `Task.detached` blocks: `await` IS required
> 
> This is due to how actor isolation works differently in detached tasks. Use the appropriate pattern based on your context.

## Overview of Key Differences

| Feature | Reachability | Connectable |
|---------|-------------|---------------|
| API | Callback and notification-based | Combine publishers, DI, and notifications |
| Framework | SystemConfiguration | Network (modern Apple API) |
| Dependency Injection | Not supported | Fully supported via PointFree Dependencies |
| Persistence | Not built-in | Built-in state persistence |
| Reactive Programming | Not supported | First-class Combine support |
| Test Support | Limited | Comprehensive mock implementation |
| Async/Await | Not supported | First-class async/await support |

## Step-by-Step Migration Guide

### 1. Update Package Dependencies

In your `Package.swift` or Xcode project, replace the Reachability dependency with Connectable.

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
import Connectable
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

// After (in regular Task) - no await needed:
Task {
    if connection.isConnected {
        // Online
    } else {
        // Offline
    }
}

// After (in detached Task) - await required:
Task.detached {
    if await connection.isConnected {
        // Online
    } else {
        // Offline
    }
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

// After (in regular Task) - no await needed:
Task {
    let isConnected = connection.isConnected
    if isConnected, let interfaceType = connection.interfaceType {
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
}

// After (in detached Task) - await required:
Task.detached {
    let isConnected = await connection.isConnected
    if isConnected, let interfaceType = await connection.interfaceType {
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
}
```

### 6. Updating LiveObjectsStore Example

Before:

```
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

// After (for use in regular Task - no await needed):
@Dependency(\.apiClient) var apiClient
@Dependency(\.modelStore) var modelStore
@Dependency(\.connection) var connection
// ...other dependencies

private func isOnline() -> Bool {
    return connection.isConnected
}

// After (for use in detached Task - await required):
@Dependency(\.apiClient) var apiClient
@Dependency(\.modelStore) var modelStore
@Dependency(\.connection) var connection
// ...other dependencies

private func isOnline() async -> Bool {
    return await connection.isConnected
}