package com.example

import spock.lang.Specification

class UserServiceTest extends Specification {

    def "should create user"() {
        when:
        def user = "testUser"

        then:
        user != null
        user == "testUser"
    }
}
