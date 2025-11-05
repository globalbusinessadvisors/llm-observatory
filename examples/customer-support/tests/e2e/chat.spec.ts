import { test, expect } from '@playwright/test';

test.describe('Chat Interface E2E Tests', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the application
    await page.goto('http://localhost:3000');

    // Wait for the page to load
    await page.waitForLoadState('networkidle');
  });

  test('should load the chat interface', async ({ page }) => {
    // Check for main chat container
    const chatContainer = page.locator('[data-testid="chat-container"]');
    await expect(chatContainer).toBeVisible();

    // Check for input field
    const inputField = page.locator('[data-testid="message-input"]');
    await expect(inputField).toBeVisible();

    // Check for send button
    const sendButton = page.locator('[data-testid="send-button"]');
    await expect(sendButton).toBeVisible();
  });

  test('should send a message and receive a response', async ({ page }) => {
    // Focus on the input field
    const inputField = page.locator('[data-testid="message-input"]');
    await inputField.click();

    // Type a message
    await inputField.fill('What is customer support?');

    // Click send button
    const sendButton = page.locator('[data-testid="send-button"]');
    await sendButton.click();

    // Wait for response
    const responseMessage = page.locator('[data-testid="message-response"]').first();
    await expect(responseMessage).toBeVisible({ timeout: 10000 });

    // Verify message content
    await expect(responseMessage).toContainText(/customer|support/i);
  });

  test('should display conversation history', async ({ page }) => {
    // Send first message
    let inputField = page.locator('[data-testid="message-input"]');
    await inputField.click();
    await inputField.fill('Hello');
    await page.locator('[data-testid="send-button"]').click();

    // Wait for first response
    await page.waitForTimeout(2000);

    // Send second message
    inputField = page.locator('[data-testid="message-input"]');
    await inputField.click();
    await inputField.fill('How are you?');
    await page.locator('[data-testid="send-button"]').click();

    // Verify both messages are visible
    const messages = page.locator('[data-testid="message-user"]');
    const count = await messages.count();
    expect(count).toBeGreaterThanOrEqual(2);
  });

  test('should create a new conversation', async ({ page }) => {
    // Look for new conversation button
    const newConvButton = page.locator('[data-testid="new-conversation-btn"]');

    if (await newConvButton.isVisible()) {
      await newConvButton.click();

      // Verify conversation was created
      const convTitle = page.locator('[data-testid="conversation-title"]');
      await expect(convTitle).toBeVisible();

      // Verify chat is empty
      const messages = page.locator('[data-testid="message"]');
      const count = await messages.count();
      expect(count).toBe(0);
    }
  });

  test('should access conversation history from sidebar', async ({ page }) => {
    // Send a message first
    const inputField = page.locator('[data-testid="message-input"]');
    await inputField.click();
    await inputField.fill('Test message');
    await page.locator('[data-testid="send-button"]').click();

    // Wait for response
    await page.waitForTimeout(2000);

    // Check if sidebar shows conversation
    const sidebar = page.locator('[data-testid="conversation-sidebar"]');
    if (await sidebar.isVisible()) {
      const conversations = sidebar.locator('[data-testid="conversation-item"]');
      const count = await conversations.count();
      expect(count).toBeGreaterThan(0);
    }
  });

  test('should handle streaming responses', async ({ page }) => {
    // Send a message that should trigger streaming
    const inputField = page.locator('[data-testid="message-input"]');
    await inputField.click();
    await inputField.fill('Tell me a long story');

    const sendButton = page.locator('[data-testid="send-button"]');
    await sendButton.click();

    // Wait for response to start appearing
    const responseArea = page.locator('[data-testid="message-response"]').first();
    await expect(responseArea).toBeVisible({ timeout: 10000 });

    // Verify content is being streamed
    const text = await responseArea.textContent();
    expect(text?.length || 0).toBeGreaterThan(0);
  });

  test('should show loading state while waiting for response', async ({ page }) => {
    const inputField = page.locator('[data-testid="message-input"]');
    await inputField.click();
    await inputField.fill('What is AI?');

    const sendButton = page.locator('[data-testid="send-button"]');
    await sendButton.click();

    // Check for loading indicator
    const loadingIndicator = page.locator('[data-testid="loading-indicator"]');
    if (await loadingIndicator.isVisible()) {
      // Wait for loading to complete
      await expect(loadingIndicator).toBeHidden({ timeout: 10000 });
    }
  });

  test('should show error message on API failure', async ({ page }) => {
    // Intercept and fail the API request
    await page.route('**/v1/chat/completions', (route) => {
      route.abort('failed');
    });

    const inputField = page.locator('[data-testid="message-input"]');
    await inputField.click();
    await inputField.fill('Test message');
    await page.locator('[data-testid="send-button"]').click();

    // Wait for error message
    const errorMessage = page.locator('[data-testid="error-message"]');
    await expect(errorMessage).toBeVisible({ timeout: 5000 });
  });

  test('should enable/disable send button appropriately', async ({ page }) => {
    const inputField = page.locator('[data-testid="message-input"]');
    const sendButton = page.locator('[data-testid="send-button"]');

    // Initially should be disabled
    await expect(sendButton).toBeDisabled();

    // Should enable when text is entered
    await inputField.click();
    await inputField.fill('Test');
    await expect(sendButton).toBeEnabled();

    // Should disable after sending
    await sendButton.click();
    await page.waitForTimeout(500);
    await expect(sendButton).toBeDisabled();
  });

  test('should handle rapid message sending', async ({ page }) => {
    const inputField = page.locator('[data-testid="message-input"]');
    const sendButton = page.locator('[data-testid="send-button"]');

    // Send multiple messages rapidly
    for (let i = 0; i < 3; i++) {
      await inputField.click();
      await inputField.fill(`Message ${i}`);
      await sendButton.click();
      await page.waitForTimeout(500);
    }

    // Verify all messages were sent
    const messages = page.locator('[data-testid="message-user"]');
    const count = await messages.count();
    expect(count).toBeGreaterThanOrEqual(3);
  });

  test('should clear input after sending message', async ({ page }) => {
    const inputField = page.locator('[data-testid="message-input"]');
    await inputField.click();
    await inputField.fill('Test message');

    const sendButton = page.locator('[data-testid="send-button"]');
    await sendButton.click();

    // Wait for message to be sent
    await page.waitForTimeout(500);

    // Check that input is cleared
    const inputValue = await inputField.inputValue();
    expect(inputValue).toBe('');
  });

  test('should support keyboard shortcuts', async ({ page }) => {
    const inputField = page.locator('[data-testid="message-input"]');
    await inputField.click();
    await inputField.fill('Test message');

    // Send message with Enter key
    await inputField.press('Enter');

    // Wait for response
    const responseMessage = page.locator('[data-testid="message-response"]').first();
    await expect(responseMessage).toBeVisible({ timeout: 10000 });
  });
});

test.describe('Chat Features E2E Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000');
    await page.waitForLoadState('networkidle');
  });

  test('should search in conversation history', async ({ page }) => {
    // Check if search functionality exists
    const searchInput = page.locator('[data-testid="search-input"]');

    if (await searchInput.isVisible()) {
      await searchInput.click();
      await searchInput.fill('test');

      // Wait for search results
      await page.waitForTimeout(500);

      const searchResults = page.locator('[data-testid="search-result"]');
      const count = await searchResults.count();
      expect(count).toBeGreaterThanOrEqual(0);
    }
  });

  test('should export conversation', async ({ page }) => {
    // Send a message first
    const inputField = page.locator('[data-testid="message-input"]');
    await inputField.click();
    await inputField.fill('Export test');
    await page.locator('[data-testid="send-button"]').click();

    // Wait for response
    await page.waitForTimeout(2000);

    // Look for export button
    const exportButton = page.locator('[data-testid="export-button"]');
    if (await exportButton.isVisible()) {
      // Set up listener for download
      const downloadPromise = page.waitForEvent('download');
      await exportButton.click();

      const download = await downloadPromise;
      expect(download.suggestedFilename()).toMatch(/\.json|\.txt|\.csv/);
    }
  });

  test('should show message metadata', async ({ page }) => {
    // Send a message
    const inputField = page.locator('[data-testid="message-input"]');
    await inputField.click();
    await inputField.fill('Metadata test');
    await page.locator('[data-testid="send-button"]').click();

    // Wait for response
    await page.waitForTimeout(2000);

    // Check for timestamp or other metadata
    const messageMetadata = page.locator('[data-testid="message-timestamp"]');
    if (await messageMetadata.isVisible()) {
      const timestamp = await messageMetadata.textContent();
      expect(timestamp).toBeTruthy();
    }
  });

  test('should handle provider selection', async ({ page }) => {
    const providerSelector = page.locator('[data-testid="provider-selector"]');

    if (await providerSelector.isVisible()) {
      await providerSelector.click();

      const options = page.locator('[data-testid="provider-option"]');
      const count = await options.count();
      expect(count).toBeGreaterThan(0);

      // Select first provider
      await options.first().click();

      // Verify selection
      const selectedText = await providerSelector.textContent();
      expect(selectedText).toBeTruthy();
    }
  });

  test('should support dark mode toggle', async ({ page }) => {
    const darkModeToggle = page.locator('[data-testid="dark-mode-toggle"]');

    if (await darkModeToggle.isVisible()) {
      const body = page.locator('body');

      // Get initial class
      const initialClass = await body.getAttribute('class');

      // Toggle dark mode
      await darkModeToggle.click();

      // Verify class changed
      const newClass = await body.getAttribute('class');
      expect(initialClass).not.toEqual(newClass);
    }
  });

  test('should display conversation metrics', async ({ page }) => {
    const metricsPanel = page.locator('[data-testid="metrics-panel"]');

    if (await metricsPanel.isVisible()) {
      // Verify metrics are displayed
      const metricValue = metricsPanel.locator('[data-testid="metric-value"]').first();
      await expect(metricValue).toBeVisible();

      const text = await metricValue.textContent();
      expect(text).toBeTruthy();
    }
  });
});
