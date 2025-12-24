package com.example.e_learn.e2e;

import io.github.bonigarcia.wdm.WebDriverManager;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.Duration;
import java.util.Arrays;
import java.util.Locale;
import java.util.NoSuchElementException;
import java.util.Optional;
import java.util.function.Supplier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.extension.RegisterExtension;
import org.junit.jupiter.api.extension.TestWatcher;
import org.openqa.selenium.By;
import org.openqa.selenium.OutputType;
import org.openqa.selenium.SessionNotCreatedException;
import org.openqa.selenium.TakesScreenshot;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.WebDriverWait;

/**
 * Base class for Selenium E2E tests.
 * - Manages headless Chrome (toggle with -Dheadless=false)
 * - Auto-manages ChromeDriver via WebDriverManager
 * - Captures screenshot on test failure to target/selenium-screens/<test>_FAIL.png
 */
public abstract class BaseE2ETest {

    protected WebDriver driver;
    protected WebDriverWait wait;

    @RegisterExtension
    TestWatcher screenshotWatcher = new SeleniumTestWatcher(this::currentDriver);

    @BeforeEach
    void setUpDriver() {
        Assumptions.assumeTrue(
            isE2eEnabled(),
            "E2E tests disabled. Enable with -De2e=true or E2E=true"
        );

        WebDriverManager.chromedriver().setup();

        boolean headlessRequested = isHeadless();
        ChromeOptions options = buildChromeOptions(headlessRequested);
        driver = startDriverWithFallback(options, headlessRequested);
        wait = new WebDriverWait(driver, Duration.ofSeconds(15));
    }

    private WebDriver startDriverWithFallback(ChromeOptions options, boolean headlessRequested) {
        try {
            return new ChromeDriver(options);
        } catch (SessionNotCreatedException ex) {
            // Headless Chrome can crash on some Windows setups; retry without headless flags.
            if (headlessRequested) {
                try {
                    ChromeOptions nonHeadless = buildChromeOptions(false);
                    return new ChromeDriver(nonHeadless);
                } catch (SessionNotCreatedException ignored) {
                    // Fall through to original exception below.
                }
            }
            throw ex;
        }
    }

    private ChromeOptions buildChromeOptions(boolean headless) {
        ChromeOptions options = new ChromeOptions();
        if (headless) {
            options.addArguments("--headless=new");
        }
        options.addArguments("--remote-debugging-port=0");
        options.addArguments("--no-sandbox");
        options.addArguments("--disable-dev-shm-usage");
        options.addArguments("--disable-background-networking");
        options.addArguments("--window-size=1280,720");
        options.addArguments("--remote-allow-origins=*");
        options.addArguments("--disable-gpu");
        options.addArguments("--disable-features=RendererCodeIntegrity");
        options.addArguments("--disable-features=ChromeWhatsNewUI");
        options.addArguments("--disable-extensions");
        options.addArguments("--profile-directory=Default");
        options.addArguments("--no-first-run");
        options.addArguments("--no-default-browser-check");
        try {
            Path userDataDir = Files.createTempDirectory("selenium-profile");
            options.addArguments("--user-data-dir=" + userDataDir.toAbsolutePath());
        } catch (IOException ignored) {
            // If we cannot create a temp profile directory, continue with defaults.
        }
        return options;
    }

    protected boolean isHeadless() {
        return !"false".equalsIgnoreCase(System.getProperty("headless", "true"));
    }

    protected Optional<WebDriver> currentDriver() {
        return Optional.ofNullable(driver);
    }

    protected WebElement waitForFirstPresent(Duration timeout, By... locators) {
        WebDriverWait shortWait = new WebDriverWait(driver, timeout);
        for (By locator : locators) {
            try {
                return shortWait.until(ExpectedConditions.presenceOfElementLocated(locator));
            } catch (Exception ignored) {
                // Try next locator
            }
        }
        throw new NoSuchElementException("None of the provided locators matched: " + Arrays.toString(locators));
    }

    /**
     * Resolve the base URL for UI tests.
     * Priority: -De2e.base-url -> E2E_BASE_URL env -> default http://localhost:8080
     * Allows running the backend on a non-default port (e.g. when 8080 is used by Jenkins).
     */
    protected String resolveBaseUrl() {
        String fromProperty = System.getProperty("e2e.base-url");
        if (fromProperty != null && !fromProperty.isBlank()) {
            return fromProperty;
        }
        String fromEnv = System.getenv("E2E_BASE_URL");
        if (fromEnv != null && !fromEnv.isBlank()) {
            return fromEnv;
        }
        return "http://localhost:8080";
    }

    private boolean isE2eEnabled() {
        String fromProperty = System.getProperty("e2e");
        if (fromProperty != null) {
            return fromProperty.equalsIgnoreCase("true") || fromProperty.equals("1");
        }
        String fromEnv = System.getenv("E2E");
        if (fromEnv != null) {
            return fromEnv.equalsIgnoreCase("true")
                || fromEnv.equals("1")
                || fromEnv.equalsIgnoreCase("yes");
        }
        return false;
    }

    /** Simple URL join that is tolerant of trailing/leading slashes. */
    protected String joinUrl(String base, String path) {
        String trimmedBase = base.endsWith("/") ? base.substring(0, base.length() - 1) : base;
        String normalizedPath = path.startsWith("/") ? path : "/" + path;
        return trimmedBase + normalizedPath;
    }

    private static class SeleniumTestWatcher implements TestWatcher {
        private final Supplier<Optional<WebDriver>> driverSupplier;

        SeleniumTestWatcher(Supplier<Optional<WebDriver>> driverSupplier) {
            this.driverSupplier = driverSupplier;
        }

        @Override
        public void testFailed(org.junit.jupiter.api.extension.ExtensionContext context, Throwable cause) {
            driverSupplier.get().ifPresent(driver -> {
                takeScreenshot(context, driver);
                quit(driver);
            });
        }

        @Override
        public void testSuccessful(org.junit.jupiter.api.extension.ExtensionContext context) {
            driverSupplier.get().ifPresent(this::quit);
        }

        @Override
        public void testAborted(org.junit.jupiter.api.extension.ExtensionContext context, Throwable cause) {
            driverSupplier.get().ifPresent(this::quit);
        }

        private void takeScreenshot(org.junit.jupiter.api.extension.ExtensionContext context, WebDriver driver) {
            if (!(driver instanceof TakesScreenshot screenshotTaker)) {
                return;
            }
            try {
                Path outputDir = Paths.get("target", "selenium-screens");
                Files.createDirectories(outputDir);
                String rawName = context.getDisplayName().replaceAll("[^a-zA-Z0-9_-]", "_");
                String filename = rawName.toUpperCase(Locale.ROOT) + "_FAIL.png";
                Path target = outputDir.resolve(filename);
                File srcFile = screenshotTaker.getScreenshotAs(OutputType.FILE);
                Files.copy(srcFile.toPath(), target, StandardCopyOption.REPLACE_EXISTING);
            } catch (IOException ignored) {
                // Best-effort screenshot
            }
        }

        private void quit(WebDriver driver) {
            try {
                driver.quit();
            } catch (Exception ignored) {
                // Best-effort shutdown
            }
        }
    }
}
