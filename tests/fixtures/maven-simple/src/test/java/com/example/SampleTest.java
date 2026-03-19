package com.example;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

public class SampleTest {

    @Test
    public void testThatPasses() {
        assertEquals(2, 1 + 1);
    }

    @Test
    public void testThatFails() {
        assertEquals(5, 2 + 2); // This will fail
    }

    @Test
    public void anotherPassingTest() {
        assertTrue(true);
    }

    @Test
    public void anotherFailingTest() {
        assertFalse(true); // This will fail
    }
}
