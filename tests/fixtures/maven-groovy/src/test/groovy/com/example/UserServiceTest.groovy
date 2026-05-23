package com.example

import org.junit.jupiter.api.Test
import static org.junit.jupiter.api.Assertions.*

class UserServiceTest {

    @Test
    void "should create user with valid name"() {
        def userService = new UserService()
        def user = userService.createUser("John")

        assertNotNull(user)
        assertEquals("John", user.getName())
    }

    @Test
    void "should throw exception for empty name"() {
        def userService = new UserService()

        assertThrows(IllegalArgumentException.class, {
            userService.createUser("")
        })
    }

    @Test
    void "should return user count"() {
        def userService = new UserService()
        userService.createUser("Alice")
        userService.createUser("Bob")

        assertEquals(2, userService.getUserCount())
    }

    @Test
    void "should fail intentionally"() {
        assertEquals(5, 2 + 2)
    }
}
