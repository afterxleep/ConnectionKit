# Reachable

Modern Swift network monitoring. Elegant, reactive and testable.

## Features

- Elegant network connectivity monitoring
- Detailed connection type awareness (WiFi, Cellular, Ethernet)
- First-class Combine integration with reactive publishers
- Classic notification-based updates
- Persistent memory of connection state
- Flexible dependency injection support
- Comprehensive mocking for tests

## Why Use Reachable?

Here's how Reachable compares to the classic Reachability:

| Feature | Reachability | Reachable |
|---------|--------------|-----------|
| Framework | SystemConfiguration (legacy) | Network (modern) |
| Reactive Programming | Not built-in | Native Combine support |
| Dependency Injection | No | Yes, with elegance |
| State Persistence | No | Yes, with customization |
| Testing | Limited | Protocol-based, easily mocked |
| Notifications | Yes | Yes |
| Design | Singleton-based | Protocol-based |

The main benefits:

- Built on Apple's modern networking APIs for precision and reliability
- Seamless integration with reactive codebases through Combine
- Elegant architecture with dependency injection support
- Effortless test mocking through protocol design
- Intelligent state persistence for immediate startup status

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.7+
- Xcode 14.0+

## Installation

### Swift Package Manager

Add Reachable to your project as a package dependency in Xcode.

```swift
dependencies: [
    .package(url: "https://github.com/afterxleep/Reachable", from: "1.0.0")
]
```

## Migration

If you're transitioning from Reachability to Reachable, check out the detailed [Migration Guide](https://github.com/afterxleep/Reachable/blob/main/docs/migrate.from.reachability.md) for step-by-step instructions on updating your codebase.

## Usage

Reachable offers multiple ways to integrate with your app.

### Basic Usage

```swift
import Reachable

// Simple usage without dependencies
let connection = Connection()
connection.startMonitoring()

// Or use the shared instance
let connection = Connection.shared

// Begin monitoring
connection.startMonitoring()

// Check connectivity
if connection.isConnected {
    print("Connected to the digital world")
} else {
    print("Disconnected from the network")
}

// Check connection quality
if let interfaceType = connection.interfaceType {
    print("Connected via \(interfaceType)")
}
```

### With Custom Persistence

```swift
import Reachable

// Create custom memory with specific UserDefaults and key
let memory = DefaultConnectionMemory(
    userDefaults: UserDefaults(suiteName: "group.com.yourcompany.app")!,
    storageKey: "connection.remembered.state"
)

// Initialize with custom memory
let connection = Connection(memory: memory)
connection.startMonitoring()
```

### With PointFree Dependencies

If you're using PointFree's [Dependencies](https://github.com/pointfreeco/swift-dependencies) package:

```swift
import Reachable
import Dependencies

// Access through dependency injection
@Dependency(\.connection) var connection

// Begin monitoring
connection.startMonitoring()

// Check connectivity
if connection.isConnected {
    print("Connected to the world")
}
```

#### Setting up Dependencies

Reachable automatically registers with the Dependencies system when both packages are imported. The setup includes:

1. Live implementation: Uses the actual Connection class
2. Test implementation: Uses MockConnection for testing

To use it in your app:

```swift
// In Package.swift or Xcode project
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    .package(url: "path/to/Reachable", from: "1.0.0"),
]

// In your SwiftUI views
struct ConnectionAwareView: View {
    @Dependency(\.connection) var connection
    @State private var isConnected = false
    
    var body: some View {
        VStack {
            Text(isConnected ? "Connected" : "No Connection")
            // ... other UI components
        }
        .onAppear {
            connection.startMonitoring()
            isConnected = connection.isConnected
        }
        .onReceive(connection.statePublisher) { newState in
            isConnected = newState
        }
    }
}
```

#### Testing with Dependencies

Override the connection dependency in your tests:

```swift
import XCTest
import Reachable
import Dependencies

class YourFeatureTests: XCTestCase {
    func testOfflineMode() {
        let mockConnection = MockConnection(isConnected: false)
        
        withDependencies {
            $0.connection = mockConnection
        } operation: {
            let sut = YourFeature()
            
            // Test offline behavior
            XCTAssertTrue(sut.isInOfflineMode)
            
            // Simulate connection recovery
            mockConnection.simulateConnection(true)
            
            // Test online behavior
            XCTAssertFalse(sut.isInOfflineMode)
        }
    }
}
```

### Reactive Usage with Combine

```swift
import Reachable
import Combine

private var cancellables = Set<AnyCancellable>()

// Get a reference to your connection
let connection = Connection.shared

// Subscribe to connection changes
connection.statePublisher
    .receive(on: RunLoop.main)
    .sink { isConnected in
        if isConnected {
            print("Connection established")
        } else {
            print("Connection lost")
        }
    }
    .store(in: &cancellables)
```

### Notification-based Usage

```swift
import Reachable

// Register for notifications
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleConnectionChange),
    name: .connectionStateDidChange,
    object: nil
)

@objc func handleConnectionChange(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let isConnected = userInfo["isConnected"] as? Bool else {
        return
    }
    
    if isConnected {
        print("Connection restored")
    } else {
        print("Connection severed")
    }
}
```

## Testing

Elegantly mock connections in your tests:

```swift
import XCTest
import Reachable

class YourTests: XCTestCase {
    func testNetworkBehavior() {
        // Create a mock connection
        let mockConnection = MockConnection(isConnected: false)
        
        // Use mock in your code
        let sut = YourService(connection: mockConnection)
        
        // Test offline behavior
        XCTAssertTrue(sut.isInOfflineMode)
        
        // Simulate connection established
        mockConnection.simulateConnection(true)
        mockConnection.simulateInterface(.cellular)
        
        // Test online behavior
        XCTAssertFalse(sut.isInOfflineMode)
    }
}
```

## Custom State Persistence

Create your own memory mechanism:

```swift
import Reachable

// Create a custom memory implementation
struct SecureConnectionMemory: ConnectionMemory {
    func rememberConnectionState() -> Bool {
        // Retrieve from your secure storage
        return YourSecureStorage.retrieveBool(forKey: "networkStatus") ?? false
    }
    
    func saveConnectionState(_ isConnected: Bool) {
        // Save to your secure storage
        YourSecureStorage.storeBool(isConnected, forKey: "networkStatus")
    }
}

// Use custom memory
let connection = Connection(memory: SecureConnectionMemory())
```

## License

Reachable is available under the MIT license. See the LICENSE file for more info.