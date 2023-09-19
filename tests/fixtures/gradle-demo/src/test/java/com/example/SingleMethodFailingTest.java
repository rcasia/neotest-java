import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertTrue;

public class SingleMethodFailingTest {
    @Test
    void shouldFail() {
        assertTrue(false);
    }
    
}
