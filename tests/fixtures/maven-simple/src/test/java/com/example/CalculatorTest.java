package com.example;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

public class CalculatorTest {

    @Test
    public void testAddition() {
        assertEquals(4, 2 + 2);
    }

    @Test
    public void testSubtraction() {
        assertEquals(0, 2 - 2);
    }

    @Test
    public void testMultiplication() {
        assertEquals(6, 2 * 3);
    }

    @Test
    public void testDivision() {
        assertEquals(2, 4 / 2);
    }
}
