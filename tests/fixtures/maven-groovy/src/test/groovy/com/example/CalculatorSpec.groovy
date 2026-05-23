package com.example

import spock.lang.Specification

class CalculatorSpec extends Specification {

    def "addition of two positive numbers"() {
        given:
        def calculator = new Calculator()

        expect:
        calculator.add(2, 3) == 5
    }

    def "subtraction returns correct result"() {
        given:
        def calculator = new Calculator()

        expect:
        calculator.subtract(10, 4) == 6
    }

    def "multiplication by zero returns zero"() {
        given:
        def calculator = new Calculator()

        expect:
        calculator.multiply(5, 0) == 0
    }

    def "division throws exception for zero divisor"() {
        given:
        def calculator = new Calculator()

        when:
        calculator.divide(10, 0)

        then:
        thrown(ArithmeticException)
    }
}
