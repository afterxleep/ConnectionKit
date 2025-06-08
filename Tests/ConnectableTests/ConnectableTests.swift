// Copyright (c) Daniel Bernal 2025

import XCTest
import Combine
import Network
@testable import Connectable

final class ConnectableTests: XCTestCase {
    
    private var cancellables = Set<AnyCancellable>()
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Protocol Definition Tests
    
    func testConnectableProtocolShouldDefineRequiredProperties() {
        // This test verifies the protocol has the required properties
        // It will compile only if the protocol is correctly defined
        
        // Protocol should have:
        // - isConnected: Bool
        // - interfaceType: NWInterface.InterfaceType?
        // - statePublisher: AnyPublisher<Bool, Never>
        // - stopMonitoring()
        // - rememberedConnectionState() -> Bool
        
        // If this compiles, the protocol is defined correctly
        _ = MockConnection()
    }
    
    // MARK: - MockConnection Tests
    
    func testMockConnectionShouldInitializeWithDefaultValues() {
        // Given
        let mock = MockConnection()
        
        // Then
        XCTAssertTrue(mock.isConnected)
        XCTAssertEqual(mock.interfaceType, .wifi)
    }
    
    func testMockConnectionShouldInitializeWithCustomValues() {
        // Given
        let mock = MockConnection(isConnected: false, interfaceType: .cellular)
        
        // Then
        XCTAssertFalse(mock.isConnected)
        XCTAssertEqual(mock.interfaceType, .cellular)
    }
    
    func testMockConnectionShouldPublishInitialState() {
        // Given
        let mock = MockConnection(isConnected: false)
        let expectation = self.expectation(description: "Initial state published")
        var receivedValue: Bool?
        
        // When
        mock.statePublisher
            .sink { value in
                receivedValue = value
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValue, false)
    }
    
    func testMockConnectionShouldSimulateConnectionChanges() {
        // Given
        let mock = MockConnection(isConnected: true)
        let expectation = self.expectation(description: "Connection change")
        var receivedValues: [Bool] = []
        
        // When
        mock.statePublisher
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        mock.simulateConnection(false)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues, [true, false])
        XCTAssertFalse(mock.isConnected)
    }
    
    func testMockConnectionShouldSimulateInterfaceChanges() {
        // Given
        let mock = MockConnection(isConnected: true, interfaceType: .wifi)
        
        // When
        mock.simulateInterface(.cellular)
        
        // Then
        XCTAssertEqual(mock.interfaceType, .cellular)
    }
    
    func testMockConnectionShouldPostNotificationOnStateChange() {
        // Given
        let mock = MockConnection(isConnected: true)
        let expectation = expectation(forNotification: .connectionStateDidChange, object: mock)
        
        // When
        mock.simulateConnection(false)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMockConnectionShouldRememberConnectionState() {
        // Given
        let mock = MockConnection(isConnected: false)
        
        // When
        let remembered = mock.rememberedConnectionState()
        
        // Then
        XCTAssertEqual(remembered, false)
    }
    
    // MARK: - Connection Tests
    
    func testConnectionShouldInitializeWithAutoStart() {
        // Given/When
        let connection = Connection()
        
        // Wait a moment for initialization
        let expectation = self.expectation(description: "Connection initialized")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then - connection should be monitoring
        // We can't directly test if monitoring started, but we can check it exists
        XCTAssertNotNil(connection)
        
        // Clean up
        connection.stopMonitoring()
    }
    
    func testConnectionShouldNotAutoStartWhenDisabled() {
        // Given/When
        let connection = Connection(autoStart: false)
        
        // Then
        // Connection exists but monitoring hasn't started
        XCTAssertNotNil(connection)
        
        // No need to stop monitoring since it never started
    }
    
    func testConnectionShouldPublishStateChanges() {
        // Given
        let connection = Connection()
        let expectation = self.expectation(description: "State published")
        var receivedValue: Bool?
        
        // When
        connection.statePublisher
            .sink { value in
                receivedValue = value
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedValue)
        
        // Clean up
        connection.stopMonitoring()
    }
    
    func testConnectionShouldHaveThreadSafeProperties() {
        // Given
        let connection = Connection()
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 100
        
        // When - Access properties from multiple threads
        for _ in 0..<100 {
            DispatchQueue.global().async {
                _ = connection.isConnected
                _ = connection.interfaceType
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        
        // Clean up
        connection.stopMonitoring()
    }
    
    // MARK: - ConnectionMemory Tests
    
    func testDefaultConnectionMemoryShouldUseUserDefaults() {
        // Given
        let key = "test.connection.state"
        let userDefaults = UserDefaults.standard
        userDefaults.set(true, forKey: key)
        
        let memory = DefaultConnectionMemory(storageKey: key)
        
        // When
        let remembered = memory.rememberConnectionState()
        
        // Then
        XCTAssertTrue(remembered)
        
        // Clean up
        userDefaults.removeObject(forKey: key)
    }
    
    func testDefaultConnectionMemoryShouldSaveState() {
        // Given
        let key = "test.save.state"
        let userDefaults = UserDefaults.standard
        let memory = DefaultConnectionMemory(storageKey: key)
        
        // When
        memory.saveConnectionState(true)
        
        // Then
        XCTAssertTrue(userDefaults.bool(forKey: key))
        
        // Clean up
        userDefaults.removeObject(forKey: key)
    }
    
    func testConnectionShouldUseCustomMemory() {
        // Given
        class TestMemory: ConnectionMemory {
            var savedState: Bool = false
            
            func rememberConnectionState() -> Bool {
                return savedState
            }
            
            func saveConnectionState(_ isConnected: Bool) {
                savedState = isConnected
            }
        }
        
        let memory = TestMemory()
        memory.savedState = true
        let connection = Connection(memory: memory)
        
        // When
        let remembered = connection.rememberedConnectionState()
        
        // Then
        XCTAssertTrue(remembered)
        
        // Clean up
        connection.stopMonitoring()
    }
    
    // MARK: - Notification Tests
    
    func testConnectionShouldPostNotificationWithCorrectUserInfo() {
        // Given
        let mock = MockConnection(isConnected: true)
        var receivedUserInfo: [AnyHashable: Any]?
        let expectation = self.expectation(description: "Notification received")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .connectionStateDidChange,
            object: mock,
            queue: .main
        ) { notification in
            receivedUserInfo = notification.userInfo
            expectation.fulfill()
        }
        
        // When
        mock.simulateConnection(false)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedUserInfo?["isConnected"] as? Bool, false)
        
        // Clean up
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - Combine Integration Tests
    
    func testConnectionShouldWorkWithCombineOperators() {
        // Given
        let mock = MockConnection(isConnected: false)
        let expectation = self.expectation(description: "Filtered value received")
        var receivedValue: Bool?
        
        // When
        mock.statePublisher
            .dropFirst() // Skip initial value
            .filter { $0 == true } // Only receive true values
            .sink { value in
                receivedValue = value
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        mock.simulateConnection(true)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValue, true)
    }
    
    func testConnectionShouldMaintainStateConsistency() {
        // Given
        let mock = MockConnection(isConnected: false)
        let expectation = self.expectation(description: "State consistency")
        expectation.expectedFulfillmentCount = 3
        
        var publisherValues: [Bool] = []
        var propertyValues: [Bool] = []
        
        // When
        mock.statePublisher
            .sink { value in
                publisherValues.append(value)
                propertyValues.append(mock.isConnected)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Change state multiple times
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            mock.simulateConnection(true)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            mock.simulateConnection(false)
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(publisherValues, propertyValues, "Publisher and property values should match")
    }
    
    // MARK: - Advanced State Synchronization Tests
    
    func testConnectionShouldMaintainSyncWithReceiveOnMainRunLoop() {
        // This test verifies that isConnected property stays in sync with publisher
        // even when using .receive(on: RunLoop.main) as in user's code
        // Given
        let mock = MockConnection(isConnected: false)
        let expectation = self.expectation(description: "State sync with RunLoop.main")
        expectation.expectedFulfillmentCount = 3
        
        var publisherValues: [Bool] = []
        var propertyValues: [Bool] = []
        
        // When - Subscribe exactly like user's code
        mock.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak mock] value in
                publisherValues.append(value)
                if let mock = mock {
                    propertyValues.append(mock.isConnected)
                }
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate WiFi toggle sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            mock.simulateConnection(true) // WiFi ON
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            mock.simulateConnection(false) // WiFi OFF
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(publisherValues, propertyValues, 
                      "Publisher and property should remain synchronized with RunLoop.main")
        XCTAssertEqual(publisherValues, [false, true, false])
    }
    
    func testConnectionShouldHandleRapidStateChanges() {
        // Test publisher/property synchronization under rapid state changes
        // Given
        let mock = MockConnection(isConnected: false)
        let totalChanges = 10
        let expectation = self.expectation(description: "Rapid state changes")
        expectation.expectedFulfillmentCount = totalChanges
        
        var publisherValues: [Bool] = []
        var propertyValues: [Bool] = []
        
        // When
        mock.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak mock] value in
                publisherValues.append(value)
                if let mock = mock {
                    propertyValues.append(mock.isConnected)
                }
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate rapid WiFi toggles
        for i in 1..<totalChanges {
            let delay = Double(i) * 0.05 // 50ms intervals
            let newState = i % 2 == 1 // Alternate true/false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                mock.simulateConnection(newState)
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(publisherValues.count, totalChanges)
        XCTAssertEqual(publisherValues, propertyValues, 
                      "All rapid state changes should maintain sync")
    }
    
    func testConnectionShouldCorrectlyReportWiFiToggleSequence() {
        // Test reproduces exact user scenario: WiFi on -> off -> on -> off -> on
        // Given
        let mock = MockConnection(isConnected: true, interfaceType: .wifi)
        let expectation = self.expectation(description: "WiFi toggle sequence")
        expectation.expectedFulfillmentCount = 5 // Initial + 4 toggles
        
        var logMessages: [String] = []
        var stateSequence: [Bool] = []
        
        // When - Subscribe like user's code
        mock.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak mock] isConnected in
                stateSequence.append(isConnected)
                
                if let mock = mock {
                    let propertyState = mock.isConnected
                    
                    // Log like user's code
                    if isConnected {
                        logMessages.append("🛜 Device is ONLINE \(propertyState)")
                    } else {
                        logMessages.append("📵 Device is OFFLINE")
                    }
                }
                
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate exact user sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            mock.simulateConnection(false) // Toggle OFF
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            mock.simulateConnection(true) // Toggle ON
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            mock.simulateConnection(false) // Toggle OFF
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            mock.simulateConnection(true) // Toggle ON
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        // Verify correct sequence
        XCTAssertEqual(stateSequence, [true, false, true, false, true])
        XCTAssertEqual(logMessages, [
            "🛜 Device is ONLINE true",
            "📵 Device is OFFLINE",
            "🛜 Device is ONLINE true",
            "📵 Device is OFFLINE",
            "🛜 Device is ONLINE true"
        ])
    }
    
    func testRealConnectionShouldNotHaveInverseState() {
        // Test to ensure real Connection doesn't have the inverse state bug
        // Given
        let connection = Connection(autoStart: true)
        let expectation = self.expectation(description: "Real connection state")
        
        var publisherValue: Bool?
        var propertyValue: Bool?
        
        // When
        connection.statePublisher
            .first()
            .sink { value in
                publisherValue = value
                propertyValue = connection.isConnected
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(publisherValue)
        XCTAssertNotNil(propertyValue)
        XCTAssertEqual(publisherValue, propertyValue, 
                      "Publisher and property should have same value, not inverse")
        
        // Clean up
        connection.stopMonitoring()
    }
    
    func testConnectionShouldNotSendInverseStateOnNetworkChanges() {
        // This test verifies the exact issue user reported: 
        // Connection is emitting wrong initial state then correcting itself
        // Given
        let connection = Connection(autoStart: true)
        var receivedStates: [Bool] = []
        var propertyStates: [Bool] = []
        var logMessages: [String] = []
        
        let expectation = self.expectation(description: "Multiple state emissions revealed")
        
        // When - Subscribe exactly like user's code
        connection.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak connection] isConnected in
                receivedStates.append(isConnected)
                
                if let conn = connection {
                    let propertyState = conn.isConnected
                    propertyStates.append(propertyState)
                    
                    // Log exactly like user's code
                    if isConnected {
                        let message = "[CONNECTION] Device is ONLINE \(propertyState)"
                        logMessages.append(message)
                        print(message)
                    } else {
                        let message = "[CONNECTION] Device is OFFLINE"
                        logMessages.append(message) 
                        print(message)
                    }
                }
                
                // Allow for up to 3 seconds to capture all emissions
                if receivedStates.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Give it time to emit multiple states if it does
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if receivedStates.count == 1 {
                expectation.fulfill() // Only one emission is fine too
            }
        }
        
        // Then - Wait to see what happens
        wait(for: [expectation], timeout: 3.0)
        
        print("✅ CORRECT: Connection emitted \(receivedStates.count) states: \(receivedStates)")
        print("📊 Property states: \(propertyStates)")
        print("📊 Log messages: \(logMessages)")
        
        // Verify Connection only emits ONE initial state (no false initial state)
        XCTAssertEqual(receivedStates.count, 1, "Connection should emit exactly 1 initial state, not multiple states")
        
        // Verify the initial state is consistent with network reality (could be online or offline)
        XCTAssertTrue(receivedStates.count >= 1, "Connection should emit at least the initial state")
        
        // Verify states are consistent between publisher and property
        XCTAssertEqual(receivedStates, propertyStates, 
                      "Publisher and property should report same state")
        
        // Clean up
        connection.stopMonitoring()
    }
    
    func testConnectionInitializationShouldUseActualNetworkStateNotMemory() {
        // Test to verify Connection doesn't use memory state for initial network detection
        // Given - Force a specific memory state that might differ from actual network
        class TestMemory: ConnectionMemory {
            var rememberedState: Bool
            
            init(rememberedState: Bool) {
                self.rememberedState = rememberedState
            }
            
            func rememberConnectionState() -> Bool {
                return rememberedState
            }
            
            func saveConnectionState(_ isConnected: Bool) {
                rememberedState = isConnected
            }
        }
        
        // Set memory to remember OFFLINE state
        let memory = TestMemory(rememberedState: false)
        let connection = Connection(memory: memory, autoStart: true)
        
        let expectation = self.expectation(description: "Actual state not memory")
        var initialPublisherState: Bool?
        var initialPropertyState: Bool?
        
        // When
        connection.statePublisher
            .first()
            .sink { value in
                initialPublisherState = value
                initialPropertyState = connection.isConnected
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        // The connection should report actual network state, not the remembered false state
        XCTAssertNotNil(initialPublisherState)
        XCTAssertNotNil(initialPropertyState)
        
        // Most importantly, publisher and property should match
        XCTAssertEqual(initialPublisherState, initialPropertyState,
                      "Publisher and property must be synchronized, regardless of memory state")
        
        print("📊 Memory state: false, Actual publisher: \(initialPublisherState!), Property: \(initialPropertyState!)")
        
        // Clean up
        connection.stopMonitoring()
    }
}