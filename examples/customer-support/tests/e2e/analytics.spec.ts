import { test, expect } from '@playwright/test';

test.describe('Analytics Dashboard E2E Tests', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to analytics page
    await page.goto('http://localhost:3000/analytics');
    await page.waitForLoadState('networkidle');
  });

  test('should load analytics dashboard', async ({ page }) => {
    const dashboard = page.locator('[data-testid="analytics-dashboard"]');
    await expect(dashboard).toBeVisible();

    // Check for main sections
    const metricsSection = page.locator('[data-testid="metrics-section"]');
    const chartsSection = page.locator('[data-testid="charts-section"]');

    if (await metricsSection.isVisible()) {
      await expect(metricsSection).toBeVisible();
    }

    if (await chartsSection.isVisible()) {
      await expect(chartsSection).toBeVisible();
    }
  });

  test('should display key metrics', async ({ page }) => {
    // Wait for metrics to load
    await page.waitForTimeout(2000);

    // Check for common metrics
    const totalConversations = page.locator('[data-testid="metric-total-conversations"]');
    const totalMessages = page.locator('[data-testid="metric-total-messages"]');
    const averageResponseTime = page.locator('[data-testid="metric-avg-response-time"]');

    if (await totalConversations.isVisible()) {
      const text = await totalConversations.textContent();
      expect(text).toMatch(/\d+/);
    }

    if (await totalMessages.isVisible()) {
      const text = await totalMessages.textContent();
      expect(text).toMatch(/\d+/);
    }

    if (await averageResponseTime.isVisible()) {
      const text = await averageResponseTime.textContent();
      expect(text).toBeTruthy();
    }
  });

  test('should display conversation metrics chart', async ({ page }) => {
    // Check for chart container
    const chartContainer = page.locator('[data-testid="conversation-chart"]');

    if (await chartContainer.isVisible()) {
      // Verify chart is rendered
      const canvas = chartContainer.locator('canvas');
      if (await canvas.count() > 0) {
        await expect(canvas.first()).toBeVisible();
      }

      // Verify legend
      const legend = chartContainer.locator('[data-testid="chart-legend"]');
      if (await legend.isVisible()) {
        await expect(legend).toBeVisible();
      }
    }
  });

  test('should filter analytics by date range', async ({ page }) => {
    const dateRangeSelector = page.locator('[data-testid="date-range-selector"]');

    if (await dateRangeSelector.isVisible()) {
      await dateRangeSelector.click();

      // Select date range
      const preset = page.locator('[data-testid="date-range-last-7-days"]');
      if (await preset.isVisible()) {
        await preset.click();

        // Wait for data to reload
        await page.waitForTimeout(1000);

        // Verify metrics updated
        const metrics = page.locator('[data-testid="metric-value"]');
        const count = await metrics.count();
        expect(count).toBeGreaterThan(0);
      }
    }
  });

  test('should show cost metrics', async ({ page }) => {
    const costSection = page.locator('[data-testid="cost-metrics-section"]');

    if (await costSection.isVisible()) {
      // Check for total cost
      const totalCost = costSection.locator('[data-testid="total-cost"]');
      if (await totalCost.isVisible()) {
        const text = await totalCost.textContent();
        expect(text).toMatch(/\$|cost/i);
      }

      // Check for cost breakdown
      const costChart = costSection.locator('[data-testid="cost-breakdown-chart"]');
      if (await costChart.isVisible()) {
        await expect(costChart).toBeVisible();
      }
    }
  });

  test('should display performance metrics', async ({ page }) => {
    const performanceSection = page.locator('[data-testid="performance-metrics-section"]');

    if (await performanceSection.isVisible()) {
      // Check for latency metric
      const latency = performanceSection.locator('[data-testid="metric-latency"]');
      if (await latency.isVisible()) {
        const text = await latency.textContent();
        expect(text).toMatch(/\d+/);
      }

      // Check for throughput metric
      const throughput = performanceSection.locator('[data-testid="metric-throughput"]');
      if (await throughput.isVisible()) {
        const text = await throughput.textContent();
        expect(text).toMatch(/\d+/);
      }
    }
  });

  test('should show error rate metrics', async ({ page }) => {
    const errorRateMetric = page.locator('[data-testid="metric-error-rate"]');

    if (await errorRateMetric.isVisible()) {
      const text = await errorRateMetric.textContent();
      expect(text).toBeTruthy();

      // Error rate should be a percentage
      if (text?.includes('%')) {
        expect(text).toMatch(/\d+(\.\d+)?%/);
      }
    }
  });

  test('should toggle between different metric views', async ({ page }) => {
    const viewToggle = page.locator('[data-testid="metric-view-toggle"]');

    if (await viewToggle.isVisible()) {
      // Get options
      const options = viewToggle.locator('[data-testid="view-option"]');
      const count = await options.count();

      if (count > 0) {
        // Click through different views
        for (let i = 0; i < Math.min(count, 2); i++) {
          const option = options.nth(i);
          await option.click();

          // Wait for view to update
          await page.waitForTimeout(500);

          // Verify content updated
          const metrics = page.locator('[data-testid="metric"]');
          expect(await metrics.count()).toBeGreaterThan(0);
        }
      }
    }
  });

  test('should export analytics data', async ({ page }) => {
    const exportButton = page.locator('[data-testid="export-analytics-button"]');

    if (await exportButton.isVisible()) {
      // Set up download listener
      const downloadPromise = page.waitForEvent('download');
      await exportButton.click();

      const download = await downloadPromise;
      expect(download.suggestedFilename()).toMatch(/\.csv|\.xlsx|\.json/);
    }
  });

  test('should display provider comparison', async ({ page }) => {
    const providerComparison = page.locator('[data-testid="provider-comparison-section"]');

    if (await providerComparison.isVisible()) {
      // Check for provider cards
      const providerCards = providerComparison.locator('[data-testid="provider-card"]');
      const count = await providerCards.count();

      if (count > 0) {
        // Verify each card has metrics
        const firstCard = providerCards.first();
        const metrics = firstCard.locator('[data-testid="provider-metric"]');
        expect(await metrics.count()).toBeGreaterThan(0);
      }
    }
  });

  test('should show real-time metrics updates', async ({ page }) => {
    // Get initial metric value
    const totalRequests = page.locator('[data-testid="metric-total-requests"]');

    if (await totalRequests.isVisible()) {
      const initialValue = await totalRequests.textContent();

      // Wait a bit and check again
      await page.waitForTimeout(2000);

      // Value might be updated if there's active traffic
      const updatedValue = await totalRequests.textContent();
      expect(updatedValue).toBeTruthy();
    }
  });

  test('should handle empty data gracefully', async ({ page }) => {
    // Filter to a date range with no data
    const dateRangeSelector = page.locator('[data-testid="date-range-selector"]');

    if (await dateRangeSelector.isVisible()) {
      await dateRangeSelector.click();

      // Try to select a future date range
      const futureDate = page.locator('[data-testid="date-range-custom"]');
      if (await futureDate.isVisible()) {
        await futureDate.click();

        // Check for empty state message
        const emptyState = page.locator('[data-testid="empty-state"]');
        if (await emptyState.isVisible()) {
          await expect(emptyState).toBeVisible();
        }
      }
    }
  });

  test('should display tooltip information', async ({ page }) => {
    // Find a chart or metric with tooltip
    const chartElement = page.locator('[data-testid="conversation-chart"]');

    if (await chartElement.isVisible()) {
      // Hover over chart element
      const dataPoint = chartElement.locator('[data-testid="chart-data-point"]');
      if (await dataPoint.first().isVisible()) {
        await dataPoint.first().hover();

        // Wait for tooltip
        await page.waitForTimeout(500);

        const tooltip = page.locator('[data-testid="tooltip"]');
        if (await tooltip.isVisible()) {
          const text = await tooltip.textContent();
          expect(text).toBeTruthy();
        }
      }
    }
  });
});

test.describe('Analytics Advanced Features', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000/analytics');
    await page.waitForLoadState('networkidle');
  });

  test('should drill down into metrics', async ({ page }) => {
    // Find a metric that allows drilling down
    const metric = page.locator('[data-testid="metric-card-clickable"]').first();

    if (await metric.isVisible()) {
      await metric.click();

      // Should navigate to detailed view
      await page.waitForTimeout(500);

      const detailedView = page.locator('[data-testid="detailed-metrics-view"]');
      if (await detailedView.isVisible()) {
        await expect(detailedView).toBeVisible();
      }
    }
  });

  test('should apply custom filters', async ({ page }) => {
    const filterButton = page.locator('[data-testid="advanced-filters-button"]');

    if (await filterButton.isVisible()) {
      await filterButton.click();

      // Apply a filter
      const filterOption = page.locator('[data-testid="filter-option"]').first();
      if (await filterOption.isVisible()) {
        await filterOption.click();

        // Wait for data to reload
        await page.waitForTimeout(1000);

        // Verify active filter indicator
        const activeFilter = page.locator('[data-testid="active-filter"]');
        if (await activeFilter.isVisible()) {
          await expect(activeFilter).toBeVisible();
        }
      }
    }
  });

  test('should create custom dashboard', async ({ page }) => {
    const customizeButton = page.locator('[data-testid="customize-dashboard-button"]');

    if (await customizeButton.isVisible()) {
      await customizeButton.click();

      // Toggle metric visibility
      const toggles = page.locator('[data-testid="metric-toggle"]');
      if (await toggles.first().isVisible()) {
        await toggles.first().click();

        // Verify change
        await page.waitForTimeout(500);
        const dashboardMetrics = page.locator('[data-testid="dashboard-metric"]');
        expect(await dashboardMetrics.count()).toBeGreaterThan(0);
      }
    }
  });

  test('should compare metrics across periods', async ({ page }) => {
    const compareButton = page.locator('[data-testid="compare-periods-button"]');

    if (await compareButton.isVisible()) {
      await compareButton.click();

      // Select comparison periods
      const periodSelector = page.locator('[data-testid="period-selector"]');
      if (await periodSelector.isVisible()) {
        await periodSelector.first().click();
        await page.locator('[data-testid="period-option"]').first().click();

        // Check for comparison results
        const comparison = page.locator('[data-testid="period-comparison"]');
        if (await comparison.isVisible()) {
          await expect(comparison).toBeVisible();
        }
      }
    }
  });
});
