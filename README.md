## License

Connectable is available under the MIT license. See the LICENSE file for more info.
# Connectable

Modern Swift network monitoring. Elegant, reactive and testable.

## Features

- Elegant network connectivity monitoring
- Detailed connection type awareness (WiFi, Cellular, Ethernet)
- First-class Combine integration with reactive publishers
- Classic notification-based updates
- Persistent memory of connection state
- Flexible dependency injection support
- Comprehensive mocking for tests
- Auto-starts monitoring by default

## Why Use Connectable?

Here's how Connectable compares to alternatives:

| Feature | Classic Reachability | Connectable |
|---------|--------------|-----------|
| Framework | SystemConfiguration (legacy) | Network (modern) |
| Reactive Programming | Not built-in | Native Combine support |
| Auto-start Monitoring | No | Yes |
| Dependency Injection | No | Yes, with elegance |
| State Persistence | No | Yes, with customization |
| Testing | Limited | Protocol-based, easily mocked |
| Notifications | Yes | Yes |
| Design | Singleton-based | Protocol-based |

The main benefits:

- Built on Apple's modern networking APIs for precision and reliability
- Auto-starts monitoring without explicit calls
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

Add Connectable to your project as a package dependency in Xcode.

```swift
dependencies: [
    .package(url: "https://github.com/afterxleep/Connectable", .upToNextMajor(from: "1.0.3"))
]
```

## Migration

If you're transitioning from Reachability to Connectable, check out the detailed [Migration Guide](https://github.com/afterxleep/Connectable/blob/main/docs/migrate.from.reachability.md) for step-by-step instructions on updating your codebase.

## Usage

Connectable offers multiple ways to integrate with your app.

### Basic Usage

```swift
import Connectable

// Simple usage - auto-starts monitoring
let connection = Connection()

// Check connectivity inside regular Task - no await needed
Task {
    if connection.isConnected {
        print("Connected to the digital world")
    } else {
        print("Disconnected from the network")
    }
    
    // Check connection quality
    if let interfaceType = connection.interfaceType {
        print("Connected via \(interfaceType)")
    }
}

// When using Task.detached, await is required
Task.detached {
    if await connection.isConnected {
        print("Connected from detached task")
    }
    
    if let interfaceType = await connection.interfaceType {
        print("Connected via \(interfaceType)")
    }
}
```

### Disable Auto-start

```swift
import Connectable

// Create connection without auto-start
let connection = Connection(autoStart: false)

// Later manually stop monitoring when needed
connection.stopMonitoring()
```

### With Custom Persistence

```swift
import Connectable

// Create custom memory with specific UserDefaults and key
let memory = DefaultConnectionMemory(
    userDefaults: UserDefaults(suiteName: "group.com.yourcompany.app")!,
    storageKey: "connection.remembered.state"
)

// Initialize with custom memory - auto-starts monitoring
let connection = Connection(memory: memory)
```

### With PointFree Dependencies

If you're using PointFree's [Dependencies](https://github.com/pointfreeco/swift-dependencies) package:

```swift
import Connectable
import Dependencies

// Access through dependency injection
@Dependency(\.connection) var connection

// Check connectivity in standard Task - no await needed
Task {
    if connection.isConnected {
        print("Connected to the world")
    }
}

// When using Task.detached, await is required
Task.detached {
    if await connection.isConnected {
        print("Connected from detached task")
    }
}
```

#### Setting up Dependencies

Connectable now includes the swift-dependencies package as a dependency, which simplifies integration. Here's how it works:

1. When both Connectable and Dependencies are imported, the connection dependency is automatically registered
2. Live implementation: Uses the actual Connection class
3. Test implementation: Uses MockConnection for testing

To use it in your app:

```swift
// In Package.swift or Xcode project
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.9.2"))
    .package(url: "https://github.com/afterxleep/Connectable", .upToNextMajor(from: "1.0.3"))
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
        .task {
            // Check connection on appear - no await needed in regular Task
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
import Connectable
import Dependencies

class YourFeatureTests: XCTestCase {
    func testOfflineMode() async {
        let mockConnection = MockConnection(isConnected: false)
        
        await withDependencies {
            $0.connection = mockConnection
        } operation: {
            let sut = YourFeature()
            
            // In Task - no await needed
            Task {
                let offlineMode = sut.isInOfflineMode
                XCTAssertTrue(offlineMode)
            }
            
            // In Task.detached - await is required
            Task.detached {
                let offlineMode = await sut.isInOfflineMode
                XCTAssertTrue(offlineMode)
            }
            
            // Simulate connection recovery
            mockConnection.simulateConnection(true)
            
            // Test online behavior
            Task {
                let onlineMode = sut.isInOfflineMode
                XCTAssertFalse(onlineMode)
            }
        }
    }
}
```

#### Note on Dependencies Integration

While Connectable includes swift-dependencies as a package dependency, the integration is designed to be optional:

- If you use the Dependencies framework, Connectable will automatically register its key
- If you don't use Dependencies, Connectable will work fine without it
- The code that registers with Dependencies is conditionally compiled, so it only activates when Dependencies is available

This approach ensures maximum flexibility while providing seamless integration with the Dependencies ecosystem.

### Reactive Usage with Combine

```swift
import Connectable
import Combine

private var cancellables = Set<AnyCancellable>()

// Get a reference to your connection
let connection = Connection()

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
import Connectable

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
import Connectable

class YourTests: XCTestCase {
    func testNetworkBehavior() async {
        // Create a mock connection
        let mockConnection = MockConnection(isConnected: false)
        
        // Use mock in your code
        let sut = YourService(connection: mockConnection)
        
        // Test offline behavior in Task - no await needed
        Task {
            let isOffline = sut.isInOfflineMode
            XCTAssertTrue(isOffline)
        }
        
        // Simulate connection established
        mockConnection.simulateConnection(true)
        mockConnection.simulateInterface(.cellular)
        
        // Test online behavior in Task - no await needed
        Task {
            let isOnline = sut.isInOfflineMode
            XCTAssertFalse(isOnline)
        }
        
        // In detached tasks, await is required
        Task.detached {
            let isOnline = await sut.isInOfflineMode
            XCTAssertFalse(isOnline)
        }
    }
}
```

## Custom State Persistence

Create your own memory mechanism:

```swift
import Connectable

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

## Async usage

When accessing `isConnected` or `interfaceType` properties:

- In regular `Task` blocks: `await` is NOT required
- In `Task.detached` blocks: `await` IS required
 
 This is due to how actor isolation works differently in detached tasks. Use the appropriate pattern based on your context.