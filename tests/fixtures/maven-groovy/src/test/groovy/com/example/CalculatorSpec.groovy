package com.example

import spock.lang.Specification
import spock.lang.Title

@Title("Calculator Specification")
class CalculatorSpec extends Specification {

    def "should add two numbers"() {
        given:
        def a = 2
        def b = 3

        when:
        def result = a + b

        then:
        result == 5
    }

    def "should subtract two numbers"() {
        given:
        def a = 5
        def b = 3

        when:
        def result = a - b

        then:
        result == 2
    }
}
