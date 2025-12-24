package com.example.e_learn.e2e;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

import java.time.Duration;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.openqa.selenium.By;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.WebDriverWait;

@Tag("e2e")
class MinioConsoleE2ETest extends BaseE2ETest {

    private static final String MINIO_URL = "http://localhost:9001";
    private static final String BUCKET_NAME = "lesson-videos";
    private static final String USERNAME = "minioadmin";
    private static final String PASSWORD = "minioadmin";

    @Test
    void minioConsoleShowsBucketAfterLogin() {
        waitForUrlReady(MINIO_URL, Duration.ofSeconds(30));
        driver.navigate().to(MINIO_URL);
        recordVisitedUrl(MINIO_URL);

        WebElement usernameInput = waitForFirstPresent(
            Duration.ofSeconds(15),
            By.cssSelector("input[type='text']"),
            By.id("accessKey"),
            By.name("username")
        );
        usernameInput.clear();
        usernameInput.sendKeys(USERNAME);

        WebElement passwordInput = waitForFirstPresent(
            Duration.ofSeconds(15),
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

        WebDriverWait postLoginWait = new WebDriverWait(driver, Duration.ofSeconds(30));
        postLoginWait.until(ExpectedConditions.or(
            ExpectedConditions.urlContains("/browser"),
            ExpectedConditions.presenceOfElementLocated(By.tagName("body"))
        ));
        recordVisitedUrl(driver.getCurrentUrl());

        boolean bucketPresent;
        try {
            bucketPresent = postLoginWait.until(d ->
                d.getPageSource().toLowerCase().contains(BUCKET_NAME)
                    || d.findElements(By.xpath("//*[contains(text(),'" + BUCKET_NAME + "')]"))
                        .stream()
                        .anyMatch(WebElement::isDisplayed)
            );
        } catch (org.openqa.selenium.TimeoutException ex) {
            fail(missingBucketMessage(BUCKET_NAME), ex);
            return;
        }

        assertTrue(bucketPresent, () -> missingBucketMessage(BUCKET_NAME));
    }

    private String missingBucketMessage(String bucketName) {
        return "Expected bucket '%s' after logging into MinIO. Create it inside docker-compose if missing:\n"
            + "docker run --rm --network project-sbar-flutter_default -e MC_HOST_minio=http://minioadmin:minioadmin@sbar_minio:9000 minio/mc mb --ignore-existing minio/%s"
            .formatted(bucketName, bucketName);
    }
}
