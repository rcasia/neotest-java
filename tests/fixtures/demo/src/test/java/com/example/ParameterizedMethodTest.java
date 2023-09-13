import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import static org.junit.jupiter.api.Assertions.assertTrue;

public class ParameterizedMethodTest {

    @ParameterizedTest
    @CsvSource({
            "1,1,2",
            "1,2,3",
            "2,3,5",
            "15,15,30"
    })
    void shouldNotFail(Integer a, Integer b, Integer result) {
        assertTrue(a + b == result);
    }
}
