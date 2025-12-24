package com.example.e_learn.e2e;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.openqa.selenium.By;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.ui.ExpectedConditions;

class MinioConsoleE2ETest extends BaseE2ETest {

    private static final String MINIO_URL = "http://localhost:9001";
    private static final String USERNAME = "minioadmin";
    private static final String PASSWORD = "minioadmin";

    @Test
    void minioConsoleShowsBucketAfterLogin() {
        driver.navigate().to(MINIO_URL);

        WebElement usernameInput = waitForFirstPresent(
            Duration.ofSeconds(5),
            By.cssSelector("input[type='text']"),
            By.id("accessKey"),
            By.name("username")
        );
        usernameInput.clear();
        usernameInput.sendKeys(USERNAME);

        WebElement passwordInput = waitForFirstPresent(
            Duration.ofSeconds(5),
            By.cssSelector("input[type='password']"),
            By.id("secretKey"),
            By.name("password")
        );
        passwordInput.clear();
        passwordInput.sendKeys(PASSWORD);

        WebElement submit = wait.until(
            ExpectedConditions.elementToBeClickable(By.cssSelector("button[type='submit']"))
        );
        submit.click();

        wait.until(ExpectedConditions.or(
            ExpectedConditions.textToBePresentInElementLocated(By.tagName("body"), "lesson-videos"),
            ExpectedConditions.presenceOfElementLocated(By.xpath("//*[contains(text(),'lesson-videos')]"))
        ));

        assertTrue(
            driver.getPageSource().toLowerCase().contains("lesson-videos"),
            "Expected bucket name 'lesson-videos' to appear after login"
        );
    }
}
