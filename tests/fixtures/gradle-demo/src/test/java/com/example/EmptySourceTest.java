package com.example;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EmptySource;

import static org.junit.jupiter.api.Assertions.assertTrue;

import org.apache.logging.log4j.util.Strings;

import static org.junit.jupiter.api.Assertions.assertFalse;

public class EmptySourceTest {

    @ParameterizedTest
    @EmptySource
    void emptySourceShouldPass(String input) {
        assertTrue(Strings.isBlank(input));
    }

    @ParameterizedTest
    @EmptySource
    void emptySourceShouldFail(String input) {
        assertFalse(Strings.isBlank(input));
    }
}
