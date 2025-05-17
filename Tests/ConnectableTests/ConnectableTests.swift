// Copyright (c) Daniel Bernal 2025

import XCTest
import Combine
import Network
@testable import Connectable

final class ConnectableTests: XCTestCase {
    
    private var cancellables = Set<AnyCancellable>()
    
    func testMockConnectionInitialState() async {
        // Given
        let connection = MockConnection(isConnected: true, interfaceType: .wifi)
        
        // Then - get the values first
        let isConnected = await connection.isConnected
        let interfaceType = await connection.interfaceType
        let remembered = await connection.rememberedConnectionState()
        
        // Assert on the local variables
        XCTAssertTrue(isConnected)
        XCTAssertEqual(interfaceType, .wifi)
        XCTAssertTrue(remembered)
    }
    
    func testMockConnectionStateChanges() async {
        // Given
        let connection = MockConnection(isConnected: true, interfaceType: .wifi)
        let expectation = self.expectation(description: "Network status changed")
        var receivedStatus: Bool?
        
        // When
        connection.statePublisher
            .dropFirst() // Skip initial value
            .sink { isConnected in
                receivedStatus = isConnected
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        connection.simulateConnection(false)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1)
        let isConnected = await connection.isConnected
        XCTAssertFalse(isConnected)
        XCTAssertEqual(receivedStatus, false)
    }
    
    func testMockConnectionInterfaceTypeChanges() async {
        // Given
        let connection = MockConnection(isConnected: true, interfaceType: .wifi)
        
        // When
        connection.simulateInterface(.cellular)
        
        // Then
        let interfaceType = await connection.interfaceType
        XCTAssertEqual(interfaceType, .cellular)
    }
    
    func testNotificationSent() {
        // Given
        let connection = MockConnection(isConnected: true)
        let notificationExpectation = expectation(forNotification: .connectionStateDidChange, object: connection)
        
        // When
        connection.simulateConnection(false)
        
        // Then
        wait(for: [notificationExpectation], timeout: 1)
    }
    
    func testNotificationContainsCorrectUserInfo() {
        // Given
        let connection = MockConnection(isConnected: true)
        var receivedUserInfo: [AnyHashable: Any]?
        
        let notificationHandler: (Notification) -> Void = { notification in
            receivedUserInfo = notification.userInfo
        }
        
        let observer = NotificationCenter.default.addObserver(
            forName: .connectionStateDidChange,
            object: connection,
            queue: nil,
            using: notificationHandler
        )
        
        // When
        connection.simulateConnection(false)
        
        // Then
        let expectation = self.expectation(description: "Wait for notification")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        XCTAssertNotNil(receivedUserInfo)
        XCTAssertEqual(receivedUserInfo?["isConnected"] as? Bool, false)
        
        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testCustomPersistence() async {
        // Given
        let mockMemory = MockConnectionMemory(initialValue: true)
        let connection = Connection(memory: mockMemory)
        
        // Then
        let initialRemembered = await connection.rememberedConnectionState()
        XCTAssertTrue(initialRemembered)
        
        // When - simulate memory change
        mockMemory.mockState = false
        
        // Then
        let updatedRemembered = await connection.rememberedConnectionState()
        XCTAssertFalse(updatedRemembered)
    }
    
    func testConnectionStateMatchesPropertyImmediately() async {
        // Given
        let connection = MockConnection(isConnected: false)
        let expectation = self.expectation(description: "Network status changed")
        var propertyValueInClosure: Bool?
        
        // When
        connection.statePublisher
            .dropFirst() // Skip initial value
            .sink { isConnected in
                // Capture the isConnected property inside the closure
                // This simulates what's happening in the user's code
                propertyValueInClosure = connection.isConnected
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate connectivity change
        connection.simulateConnection(true)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1)
        
        // The isConnected property should match what was emitted by the publisher
        XCTAssertEqual(propertyValueInClosure, true)
        XCTAssertTrue(propertyValueInClosure!)
    }
}

// MARK: - Test Helper

private class MockConnectionMemory: ConnectionMemory {
    var mockState: Bool
    var saveStateCallCount = 0
    
    init(initialValue: Bool) {
        self.mockState = initialValue
    }
    
    func rememberConnectionState() -> Bool {
        return mockState
    }
    
    func saveConnectionState(_ isConnected: Bool) {
        mockState = isConnected
        saveStateCallCount += 1
    }
} 