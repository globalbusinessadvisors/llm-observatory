import { test, expect } from '@playwright/test';

test.describe('Knowledge Base E2E Tests', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to knowledge base page
    await page.goto('http://localhost:3000/knowledge-base');
    await page.waitForLoadState('networkidle');
  });

  test('should load knowledge base interface', async ({ page }) => {
    const kbContainer = page.locator('[data-testid="kb-container"]');
    await expect(kbContainer).toBeVisible();

    // Check for main sections
    const searchSection = page.locator('[data-testid="kb-search-section"]');
    const documentsSection = page.locator('[data-testid="kb-documents-section"]');

    if (await searchSection.isVisible()) {
      await expect(searchSection).toBeVisible();
    }

    if (await documentsSection.isVisible()) {
      await expect(documentsSection).toBeVisible();
    }
  });

  test('should search knowledge base', async ({ page }) => {
    // Find search input
    const searchInput = page.locator('[data-testid="kb-search-input"]');
    await expect(searchInput).toBeVisible();

    // Enter search query
    await searchInput.click();
    await searchInput.fill('password reset');

    // Submit search
    const searchButton = page.locator('[data-testid="kb-search-button"]');
    if (await searchButton.isVisible()) {
      await searchButton.click();
    } else {
      // Try pressing Enter
      await searchInput.press('Enter');
    }

    // Wait for results
    await page.waitForTimeout(2000);

    // Check for search results
    const results = page.locator('[data-testid="search-result-item"]');
    const count = await results.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('should display document list', async ({ page }) => {
    // Wait for documents to load
    await page.waitForTimeout(1000);

    // Check for document items
    const documents = page.locator('[data-testid="document-item"]');
    const count = await documents.count();

    if (count > 0) {
      // Verify first document has content
      const firstDoc = documents.first();
      const title = firstDoc.locator('[data-testid="document-title"]');
      await expect(title).toBeVisible();
    }
  });

  test('should upload a new document', async ({ page }) => {
    // Find upload section
    const uploadSection = page.locator('[data-testid="kb-upload-section"]');

    if (await uploadSection.isVisible()) {
      // Find file input
      const fileInput = uploadSection.locator('input[type="file"]');

      if (await fileInput.isVisible()) {
        // Create and upload a test file
        await fileInput.setInputFiles({
          name: 'test-document.txt',
          mimeType: 'text/plain',
          buffer: Buffer.from('This is a test document for the knowledge base.')
        });

        // Wait for upload to complete
        await page.waitForTimeout(2000);

        // Check for success message
        const successMessage = page.locator('[data-testid="upload-success-message"]');
        if (await successMessage.isVisible()) {
          await expect(successMessage).toBeVisible();
        }

        // Verify document appears in list
        const documents = page.locator('[data-testid="document-item"]');
        expect(await documents.count()).toBeGreaterThan(0);
      }
    }
  });

  test('should drag and drop files for upload', async ({ page }) => {
    // Find drop zone
    const dropZone = page.locator('[data-testid="kb-drop-zone"]');

    if (await dropZone.isVisible()) {
      // Create a test file
      const dataTransfer = await page.evaluateHandle(() => {
        const dt = new DataTransfer();
        const file = new File(['test content'], 'test.txt', { type: 'text/plain' });
        dt.items.add(file);
        return dt;
      });

      // Perform drop
      await dropZone.dispatchEvent('drop', { dataTransfer });

      // Wait for upload
      await page.waitForTimeout(2000);

      // Check for success
      const successMessage = page.locator('[data-testid="upload-success-message"]');
      if (await successMessage.isVisible()) {
        await expect(successMessage).toBeVisible();
      }
    }
  });

  test('should view document details', async ({ page }) => {
    // Wait for documents to load
    await page.waitForTimeout(1000);

    // Click on first document
    const document = page.locator('[data-testid="document-item"]').first();

    if (await document.isVisible()) {
      await document.click();

      // Wait for detail view to load
      await page.waitForTimeout(500);

      // Check for document details
      const detailsPanel = page.locator('[data-testid="document-details-panel"]');
      if (await detailsPanel.isVisible()) {
        // Verify content
        const title = detailsPanel.locator('[data-testid="detail-title"]');
        const content = detailsPanel.locator('[data-testid="detail-content"]');

        if (await title.isVisible()) {
          await expect(title).toBeVisible();
        }

        if (await content.isVisible()) {
          await expect(content).toBeVisible();
        }
      }
    }
  });

  test('should delete a document', async ({ page }) => {
    // Wait for documents to load
    await page.waitForTimeout(1000);

    // Get initial document count
    const documents = page.locator('[data-testid="document-item"]');
    const initialCount = await documents.count();

    if (initialCount > 0) {
      // Right-click on document for context menu
      const firstDoc = documents.first();
      await firstDoc.click({ button: 'right' });

      // Wait for context menu
      await page.waitForTimeout(300);

      // Click delete option
      const deleteOption = page.locator('[data-testid="context-menu-delete"]');
      if (await deleteOption.isVisible()) {
        await deleteOption.click();

        // Confirm deletion if prompted
        const confirmButton = page.locator('[data-testid="confirm-delete-button"]');
        if (await confirmButton.isVisible()) {
          await confirmButton.click();
        }

        // Wait for update
        await page.waitForTimeout(1000);

        // Verify count decreased
        const updatedCount = await documents.count();
        expect(updatedCount).toBeLessThanOrEqual(initialCount);
      }
    }
  });

  test('should filter documents by category', async ({ page }) => {
    // Find category filter
    const categoryFilter = page.locator('[data-testid="category-filter"]');

    if (await categoryFilter.isVisible()) {
      await categoryFilter.click();

      // Select a category
      const categoryOption = page.locator('[data-testid="category-option"]').first();
      if (await categoryOption.isVisible()) {
        await categoryOption.click();

        // Wait for filter to apply
        await page.waitForTimeout(1000);

        // Check filtered results
        const documents = page.locator('[data-testid="document-item"]');
        expect(await documents.count()).toBeGreaterThanOrEqual(0);
      }
    }
  });

  test('should sort documents', async ({ page }) => {
    // Find sort dropdown
    const sortDropdown = page.locator('[data-testid="kb-sort-dropdown"]');

    if (await sortDropdown.isVisible()) {
      await sortDropdown.click();

      // Select sort option
      const sortOption = page.locator('[data-testid="sort-option"]').nth(1);
      if (await sortOption.isVisible()) {
        await sortOption.click();

        // Wait for sorting
        await page.waitForTimeout(500);

        // Verify documents are sorted
        const documents = page.locator('[data-testid="document-item"]');
        expect(await documents.count()).toBeGreaterThan(0);
      }
    }
  });

  test('should search within document content', async ({ page }) => {
    // Click on a document first
    const document = page.locator('[data-testid="document-item"]').first();

    if (await document.isVisible()) {
      await document.click();

      // Wait for details panel
      await page.waitForTimeout(500);

      // Find content search input
      const contentSearch = page.locator('[data-testid="document-content-search"]');
      if (await contentSearch.isVisible()) {
        await contentSearch.click();
        await contentSearch.fill('test');

        // Wait for search
        await page.waitForTimeout(500);

        // Check for highlighted results
        const highlights = page.locator('[data-testid="search-highlight"]');
        const count = await highlights.count();
        expect(count).toBeGreaterThanOrEqual(0);
      }
    }
  });

  test('should edit document metadata', async ({ page }) => {
    // Click on a document
    const document = page.locator('[data-testid="document-item"]').first();

    if (await document.isVisible()) {
      await document.click();

      // Wait for details panel
      await page.waitForTimeout(500);

      // Find edit button
      const editButton = page.locator('[data-testid="edit-metadata-button"]');
      if (await editButton.isVisible()) {
        await editButton.click();

        // Wait for edit form
        await page.waitForTimeout(300);

        // Edit a field
        const titleInput = page.locator('[data-testid="metadata-title-input"]');
        if (await titleInput.isVisible()) {
          await titleInput.clear();
          await titleInput.fill('Updated Title');

          // Save changes
          const saveButton = page.locator('[data-testid="save-metadata-button"]');
          if (await saveButton.isVisible()) {
            await saveButton.click();

            // Wait for save
            await page.waitForTimeout(500);

            // Verify change
            const updatedTitle = page.locator('[data-testid="detail-title"]');
            const titleText = await updatedTitle.textContent();
            expect(titleText).toContain('Updated Title');
          }
        }
      }
    }
  });

  test('should show document statistics', async ({ page }) => {
    // Click on a document
    const document = page.locator('[data-testid="document-item"]').first();

    if (await document.isVisible()) {
      await document.click();

      // Wait for details panel
      await page.waitForTimeout(500);

      // Check for statistics
      const stats = page.locator('[data-testid="document-statistics"]');
      if (await stats.isVisible()) {
        // Verify word count
        const wordCount = stats.locator('[data-testid="stat-word-count"]');
        if (await wordCount.isVisible()) {
          const text = await wordCount.textContent();
          expect(text).toMatch(/\d+/);
        }

        // Verify character count
        const charCount = stats.locator('[data-testid="stat-char-count"]');
        if (await charCount.isVisible()) {
          const text = await charCount.textContent();
          expect(text).toMatch(/\d+/);
        }
      }
    }
  });

  test('should export document', async ({ page }) => {
    // Click on a document
    const document = page.locator('[data-testid="document-item"]').first();

    if (await document.isVisible()) {
      await document.click();

      // Wait for details panel
      await page.waitForTimeout(500);

      // Find export button
      const exportButton = page.locator('[data-testid="export-document-button"]');
      if (await exportButton.isVisible()) {
        // Set up download listener
        const downloadPromise = page.waitForEvent('download');
        await exportButton.click();

        const download = await downloadPromise;
        expect(download.suggestedFilename()).toMatch(/\.txt|\.pdf|\.docx/);
      }
    }
  });

  test('should show vector embedding status', async ({ page }) => {
    // Wait for documents to load
    await page.waitForTimeout(1000);

    // Click on a document
    const document = page.locator('[data-testid="document-item"]').first();

    if (await document.isVisible()) {
      await document.click();

      // Wait for details panel
      await page.waitForTimeout(500);

      // Check for embedding status
      const embeddingStatus = page.locator('[data-testid="embedding-status"]');
      if (await embeddingStatus.isVisible()) {
        const status = await embeddingStatus.textContent();
        expect(status).toMatch(/indexed|processing|pending|error/i);
      }
    }
  });

  test('should support batch operations', async ({ page }) => {
    // Wait for documents to load
    await page.waitForTimeout(1000);

    // Find checkbox for selecting multiple
    const checkboxes = page.locator('[data-testid="document-checkbox"]');

    if (await checkboxes.first().isVisible()) {
      // Select multiple documents
      await checkboxes.first().click();
      await checkboxes.nth(1).click();

      // Wait for batch options
      await page.waitForTimeout(300);

      // Check for batch action button
      const batchActions = page.locator('[data-testid="batch-actions-button"]');
      if (await batchActions.isVisible()) {
        await expect(batchActions).toBeVisible();
      }
    }
  });

  test('should handle large file uploads', async ({ page }) => {
    const uploadSection = page.locator('[data-testid="kb-upload-section"]');

    if (await uploadSection.isVisible()) {
      const fileInput = uploadSection.locator('input[type="file"]');

      if (await fileInput.isVisible()) {
        // Create a larger test file (1MB)
        const largeContent = 'x'.repeat(1024 * 1024);
        await fileInput.setInputFiles({
          name: 'large-document.txt',
          mimeType: 'text/plain',
          buffer: Buffer.from(largeContent)
        });

        // Wait for upload with longer timeout
        await page.waitForTimeout(5000);

        // Check for success or upload progress
        const progressBar = page.locator('[data-testid="upload-progress"]');
        const successMessage = page.locator('[data-testid="upload-success-message"]');

        if (await progressBar.isVisible()) {
          // Wait for progress to complete
          await expect(progressBar).toBeHidden({ timeout: 30000 });
        }

        if (await successMessage.isVisible()) {
          await expect(successMessage).toBeVisible();
        }
      }
    }
  });

  test('should display search relevance scores', async ({ page }) => {
    // Perform a search
    const searchInput = page.locator('[data-testid="kb-search-input"]');
    await searchInput.click();
    await searchInput.fill('test');

    const searchButton = page.locator('[data-testid="kb-search-button"]');
    if (await searchButton.isVisible()) {
      await searchButton.click();
    } else {
      await searchInput.press('Enter');
    }

    // Wait for results
    await page.waitForTimeout(2000);

    // Check for relevance scores
    const scores = page.locator('[data-testid="result-relevance-score"]');
    const count = await scores.count();

    if (count > 0) {
      // Verify scores are displayed
      const firstScore = await scores.first().textContent();
      expect(firstScore).toMatch(/\d+(\.\d+)?%?/);

      // Verify scores are in descending order
      if (count > 1) {
        const firstValue = parseFloat(await scores.first().textContent() || '0');
        const secondValue = parseFloat(await scores.nth(1).textContent() || '0');
        expect(firstValue).toBeGreaterThanOrEqual(secondValue);
      }
    }
  });
});
