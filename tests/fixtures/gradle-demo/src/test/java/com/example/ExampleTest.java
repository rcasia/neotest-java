package com.example;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertTrue;

public class ExampleTest {
    @Test
    void shouldNotFail() {
        assertTrue(true);
    }
    
    @Test
    void shouldFail() {
        assertTrue(false);
    }
}
