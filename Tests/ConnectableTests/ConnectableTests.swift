// Copyright (c) Daniel Bernal 2025

import XCTest
import Combine
import Network
@testable import Connectable

final class ConnectableTests: XCTestCase {
    
    private var cancellables = Set<AnyCancellable>()
    
    func testMockConnectionInitialState() {
        // Given
        let connection = MockConnection(isConnected: true, interfaceType: .wifi)
        
        // Then
        XCTAssertTrue(connection.isConnected)
        XCTAssertEqual(connection.interfaceType, .wifi)
        XCTAssertTrue(connection.rememberedConnectionState())
    }
    
    func testMockConnectionStateChanges() {
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
        waitForExpectations(timeout: 1)
        XCTAssertFalse(connection.isConnected)
        XCTAssertEqual(receivedStatus, false)
    }
    
    func testMockConnectionInterfaceTypeChanges() {
        // Given
        let connection = MockConnection(isConnected: true, interfaceType: .wifi)
        
        // When
        connection.simulateInterface(.cellular)
        
        // Then
        XCTAssertEqual(connection.interfaceType, .cellular)
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
    
    func testCustomPersistence() {
        // Given
        let mockMemory = MockConnectionMemory(initialValue: true)
        let connection = Connection(memory: mockMemory)
        
        // Then
        XCTAssertTrue(connection.rememberedConnectionState())
        
        // When - simulate memory change
        mockMemory.mockState = false
        
        // Then
        XCTAssertFalse(connection.rememberedConnectionState())
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