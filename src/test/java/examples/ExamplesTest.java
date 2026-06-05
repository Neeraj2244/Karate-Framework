package examples;

import io.karatelabs.core.Runner;
import io.karatelabs.core.SuiteResult;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ExamplesTest {

    @Test
    void testAll() {
        SuiteResult result = Runner.path("classpath:examples")
            .outputHtmlReport(true)
            .parallel(5);
        assertTrue(result.isPassed());
    }
}
