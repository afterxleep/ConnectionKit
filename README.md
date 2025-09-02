## License

ConnectionKit is available under the MIT license. See the LICENSE file for more info.
# ConnectionKit

Modern Swift network monitoring. Elegant, reactive and async/await first.

> **Migration Note**: This package was previously named `Connectable`. If you're upgrading from version 1.x, update your imports from `import Connectable` to `import ConnectionKit`.

## Features

- Elegant network connectivity monitoring
- Detailed connection type awareness (WiFi, Cellular, Ethernet)
- First-class Combine integration with reactive publishers
- Classic notification-based updates
- Persistent memory of connection state
- Flexible dependency injection support
- Comprehensive mocking for tests
- Auto-starts monitoring by default

## Why Use ConnectionKit over Reachability?

Here's a quick comparison:

| Feature | Reachability | ConnectionKit |
|---------|--------------|-----------|
| Framework | SystemConfiguration (legacy) | Network (modern) |
| Reactive Programming | Not built-in | Native Combine support |
| Auto-start Monitoring | No | Yes |
| Dependency Injection | No | Yes, with elegance |
| State Persistence | No | Yes, with customization |
| Testing | Limited | Protocol-based, easily mocked |
| Notifications | Yes | Yes |
| Design | Singleton-based | Protocol-based |
| Actor-based | No | Yes |
| Async/Await Support | No | First-class support |

The main benefits:

- Built on Apple's modern networking APIs for precision and reliability
- Auto-starts monitoring without explicit calls
- Seamless integration with reactive codebases through Combine
- Elegant architecture with dependency injection support
- Effortless test mocking through protocol design
- Intelligent state persistence for immediate startup status
- Actor-based design for safe concurrent access
- First-class async/await support

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.7+

## Installation

### Swift Package Manager

Add ConnectionKit to your project as a package dependency in Xcode.

```swift
dependencies: [
    .package(url: "https://github.com/afterxleep/ConnectionKit", .upToNextMajor(from: "2.0.0"))
]
```

## Migration

If you're transitioning from Reachability to ConnectionKit, check out the detailed [Migration Guide](https://github.com/afterxleep/ConnectionKit/blob/main/docs/migrate.from.reachability.md) for step-by-step instructions on updating your codebase.

## Usage

ConnectionKit offers multiple ways to integrate with your app.

### Basic Usage

```swift
import ConnectionKit

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
import ConnectionKit

// Create connection without auto-start
let connection = Connection(autoStart: false)

// Later manually stop monitoring when needed
connection.stopMonitoring()
```

### With Custom Persistence

```swift
import ConnectionKit

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
import ConnectionKit
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

ConnectionKit now includes the swift-dependencies package as a dependency, which simplifies integration. Here's how it works:

1. When both ConnectionKit and Dependencies are imported, the connection dependency is automatically registered
2. Live implementation: Uses the actual Connection class
3. Test implementation: Uses MockConnection for testing

To use it in your app:

```swift
// In Package.swift or Xcode project
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.9.2"))
    .package(url: "https://github.com/afterxleep/ConnectionKit", .upToNextMajor(from: "2.0.0"))
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
import ConnectionKit
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

While ConnectionKit includes swift-dependencies as a package dependency, the integration is designed to be optional:

- If you use the Dependencies framework, ConnectionKit will automatically register its key
- If you don't use Dependencies, ConnectionKit will work fine without it
- The code that registers with Dependencies is conditionally compiled, so it only activates when Dependencies is available

This approach ensures maximum flexibility while providing seamless integration with the Dependencies ecosystem.

## iOS Simulator Support

ConnectionKit automatically detects when running on iOS Simulator and activates a reliable fallback monitoring system. This is necessary because iOS Simulator doesn't properly support `NWPath` monitoring, leading to unreliable or missing network state updates.

### Automatic Fallback
- **Device**: Uses standard `NWPathMonitor` for optimal performance and immediate detection
- **Simulator**: Uses URLSession-based connectivity checks with 2-second intervals
- **Zero Configuration**: Fallback activates automatically, no setup required
- **100% Reliability**: Actual network requests verify connectivity on simulator
- **No Performance Impact**: Fallback only runs on simulator environment

### How It Works
On iOS Simulator, ConnectionKit:
1. Bypasses unreliable `NWPathMonitor` path status
2. Performs lightweight HEAD requests to Apple's connectivity check endpoint
3. Updates connection state based on actual network reachability
4. Maintains consistent behavior with device implementation

### Testing on Simulator
⚠️ Switching WiFi off/on on your Mac while running the app in a simulator can cause the app to never detect re-connection.  This is not a ConnectionKit bug, but a Simulator limitation.

To properly test network changes on iOS Simulator:

1. Use Network link conditioner (XCode > Open Developer Tools > More Tools), and get 
Additional Tools for Xcode
2. Install Network Link Conditioner and change connectivity to 100% los
3. ConnectionKit will detect changes within 2 seconds on simulator
4. Interface type on simulator always returns `.wifi` when connected


### Reactive Usage with Combine

```swift
import ConnectionKit
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
import ConnectionKit

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
import ConnectionKit

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
import ConnectionKit

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

### Why?

The `Connection` class in ConnectionKit is implemented as an actor, which provides thread-safe access to its mutable state by ensuring only one execution context can access it at a time.

### Task vs Task.detached

**Regular Tasks:**
- Inherit the actor isolation context from where they're created
- Maintain the synchronization context of their parent
- Allow direct access to actor properties without explicit `await`
- The Swift compiler handles synchronization implicitly

```swift
// Regular Task example - no await needed
Task {
    if connection.isConnected {
        print("Connected via \(connection.interfaceType ?? .unknown)")
    }
}
```

**Detached Tasks:**
- Run completely independently from their parent context
- Don't inherit any actor isolation from where they're created
- Must explicitly await when accessing actor properties
- Require manual synchronization through `await`

```swift
// Detached Task example - await IS required
Task.detached {
    if await connection.isConnected {
        print("Connected via \(await connection.interfaceType ?? .unknown)")
    }
}
```

## Changelog

### v1.1.0 (Latest)
- **NEW FEATURE**: Added iOS Simulator support with automatic fallback monitoring
- Resolved iOS Simulator network detection issues where NWPathMonitor doesn't trigger updates properly
- Automatic timer-based fallback monitoring (2-second intervals) activates only on simulator
- No performance impact on real devices - fallback only runs on simulator environment
- Added 2 new tests specifically for simulator support with extended timeouts
- Enhanced lifecycle management with proper timer cleanup on stopMonitoring()
- All 26 tests now pass reliably on both real devices and iOS Simulator

### v1.0.9
- **CRITICAL FIX**: Fixed state inversion bug where WiFi toggle events emitted wrong states
- Resolved issue where WiFi OFF triggered ONLINE events and WiFi ON triggered OFFLINE events
- Fixed double emission of states during initialization that caused apparent inversion
- Publisher now correctly detects and emits actual network state (online OR offline) without false initial states
- Enhanced thread-safe subject initialization to prevent race conditions
- Complete test suite rewrite with 24 comprehensive tests covering all connection scenarios
- Added tests for rapid state changes, WiFi toggle sequences, and RunLoop.main synchronization

### v1.0.8
- **CRITICAL FIX**: Fixed false positive initial state bug where `statePublisher` always emitted `true` on subscription
- Removed optimistic initialization that caused incorrect initial connection state
- Publisher now only emits when connection state actually changes
- Initialization now uses actual network state instead of assuming connectivity
- Enhanced test coverage to prevent regression of this issue

### v1.0.7
- Completely rebuilt thread-safety mechanisms for networking state
- Added proper locking for all state changes
- Enhanced logging for diagnosing connectivity issues


### v1.0.6
- Fixed synchronization between statePublisher and isConnected property
- Ensures consistent connection state when accessing property inside publisher callbacks
- Fixed racing condition where property might return different value than publisher

### v1.0.5
- Fixed initial connection state detection to use actual network status instead of remembered state
- Improved reliability of connectivity detection at app startup
- Better handling of network transitions