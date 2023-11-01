package com.example;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;

import com.example.demo.DemoApplication;

@SpringBootTest(classes = { DemoApplication.class })
public class ErroneousTest {
    @Value("${foo.property}") String requiredProperty;

    @Test
    void shouldFailOnError(){
      assertEquals("test", requiredProperty);
    }
}
