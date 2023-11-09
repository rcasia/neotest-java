package com.example;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

public class NestedTests {

        public static class SomeNestedTest {

                @Test
                void shouldSucceed() {
                        assertEquals(2, 1 + 1);
                }

                @Test
                void shouldFail() {
                        assertEquals(3, 1 + 1);
                }

        }

}
