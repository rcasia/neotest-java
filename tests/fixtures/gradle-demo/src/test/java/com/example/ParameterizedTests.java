package com.example;

import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

public class ParameterizedTests{

    @ParameterizedTest
    @CsvSource({
        "1, 2, 3",
        "2, 3, 5",
        "3, 4, 7"
    })
    void shouldPass(int a, int b, int c) {
      assertTrue(a + b == c);
    }

    @ParameterizedTest
    @CsvSource({
        "1, 2, 3",
        "2, 3, 5",
        "3, 4, 7"
    })
    void shouldPass2(int a, int b, int c) {
      assertTrue(a + b == c);
    }
    
    @ParameterizedTest
    @CsvSource({
        "1, 2, 2",
        "2, 3, 3",
        "3, 4, 4"
    })
    void shouldFail(int a, int b, int c) {
      assertTrue(a + b == c);
    }
}
