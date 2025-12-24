package com.example.e_learn.e2e;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

import java.time.Duration;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.openqa.selenium.By;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.ui.WebDriverWait;

@Tag("e2e")
class SwaggerUiE2ETest extends BaseE2ETest {

    @Test
    void swaggerUiLoads() {
        String swaggerUrl = joinUrl(resolveBaseUrl(), "swagger-ui/index.html");
        waitForUrlReady(swaggerUrl, Duration.ofSeconds(30));
        driver.navigate().to(swaggerUrl);
        recordVisitedUrl(swaggerUrl);

        new WebDriverWait(driver, Duration.ofSeconds(10))
            .until(d -> !d.getPageSource().isEmpty());
        recordVisitedUrl(driver.getCurrentUrl());

        String pageSource = driver.getPageSource();
        boolean looksLikeJenkins = pageSource.contains("Sign in to Jenkins") || pageSource.contains("Jenkins");
        if (looksLikeJenkins) {
            fail("Swagger UI did not load at %s. Page looked like Jenkins; set -De2e.base-url=http://localhost:8080 (or your backend URL)."
                .formatted(swaggerUrl));
        }

        WebDriverWait longWait = new WebDriverWait(driver, Duration.ofSeconds(30));
        boolean loaded = longWait.until(d -> {
            boolean hasElement = d.findElements(By.id("swagger-ui"))
                .stream()
                .anyMatch(WebElement::isDisplayed);
            boolean hasClass = d.findElements(By.cssSelector(".swagger-ui"))
                .stream()
                .anyMatch(WebElement::isDisplayed);
            boolean hasText = d.getPageSource().toLowerCase().contains("openapi definition");
            return hasElement || hasClass || hasText;
        });

        assertTrue(loaded, "Swagger UI should load and show #swagger-ui or 'OpenAPI definition'");
    }
}
