package com.example.e_learn.e2e;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.openqa.selenium.By;
import org.openqa.selenium.support.ui.WebDriverWait;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;
import org.springframework.boot.test.web.server.LocalServerPort;

@SpringBootTest(
    webEnvironment = WebEnvironment.RANDOM_PORT,
    properties = {
        "server.port=0",
        "spring.datasource.url=jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1;MODE=PostgreSQL",
        "spring.datasource.driver-class-name=org.h2.Driver",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.jpa.hibernate.ddl-auto=update",
        "spring.flyway.enabled=false"
    }
)
class SwaggerUiE2ETest extends BaseE2ETest {

    @LocalServerPort
    private int port;

    @Override
    protected String resolveBaseUrl() {
        String fromProperty = System.getProperty("e2e.base-url");
        if (fromProperty != null && !fromProperty.isBlank()) {
            return fromProperty;
        }
        String fromEnv = System.getenv("E2E_BASE_URL");
        if (fromEnv != null && !fromEnv.isBlank()) {
            return fromEnv;
        }
        return "http://localhost:" + port;
    }

    @Test
    void swaggerUiLoads() {
        String swaggerUrl = joinUrl(resolveBaseUrl(), "swagger-ui/index.html");
        driver.navigate().to(swaggerUrl);

        // Fail fast with a helpful message if we're clearly talking to another app (e.g. Jenkins on 8080)
        new WebDriverWait(driver, Duration.ofSeconds(5))
            .until(d -> !d.getPageSource().isEmpty());
        String pageSource = driver.getPageSource();
        boolean looksLikeJenkins = pageSource.contains("Sign in to Jenkins") || pageSource.contains("Jenkins");
        if (looksLikeJenkins) {
            String fallbackUrl = joinUrl("http://localhost:" + port, "swagger-ui/index.html");
            // If we're already using the embedded server, fail fast with context.
            if (swaggerUrl.equals(fallbackUrl)) {
                fail("Swagger UI did not load. Page looked like Jenkins at %s; ensure e-learn is running.".formatted(swaggerUrl));
            }
            // Try the embedded server started for this test class.
            driver.navigate().to(fallbackUrl);
            new WebDriverWait(driver, Duration.ofSeconds(5))
                .until(d -> !d.getPageSource().isEmpty());
            pageSource = driver.getPageSource();
            looksLikeJenkins = pageSource.contains("Sign in to Jenkins") || pageSource.contains("Jenkins");
            if (looksLikeJenkins) {
                fail("Swagger UI did not load. Both configured base URL (%s) and embedded server (%s) returned Jenkins page."
                    .formatted(swaggerUrl, fallbackUrl));
            }
        }

        WebDriverWait longWait = new WebDriverWait(driver, Duration.ofSeconds(30));

        boolean loaded = longWait.until(d -> {
            boolean hasElement = d.findElements(By.id("swagger-ui"))
                .stream()
                .anyMatch(e -> {
                    try {
                        return e.isDisplayed();
                    } catch (Exception ex) {
                        return false;
                    }
                });
            boolean hasClass = d.findElements(By.cssSelector(".swagger-ui"))
                .stream()
                .anyMatch(e -> {
                    try {
                        return e.isDisplayed();
                    } catch (Exception ex) {
                        return false;
                    }
                });
            boolean hasText = d.getPageSource().contains("OpenAPI definition");
            return hasElement || hasClass || hasText;
        });

        assertTrue(loaded, "Swagger UI should load or show 'OpenAPI definition'");
    }
}
