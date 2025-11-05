// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

/**
 * Integration tests for the complete SDK workflow.
 * These tests verify end-to-end functionality.
 */

import { initObservatory, instrumentOpenAI, PricingEngine, shutdownObservatory } from '../src';

describe('Integration Tests', () => {
  beforeEach(async () => {
    await shutdownObservatory();
  });

  afterEach(async () => {
    await shutdownObservatory();
  });

  describe('Complete Workflow', () => {
    it('should initialize and instrument successfully', async () => {
      // Initialize observatory
      const observatory = await initObservatory({
        serviceName: 'integration-test',
        otlpEndpoint: 'http://localhost:4317',
        debug: false,
      });

      expect(observatory.isInitialized()).toBe(true);

      // Create mock OpenAI client
      const mockClient = {
        chat: {
          completions: {
            create: jest.fn().mockResolvedValue({
              id: 'test-id',
              model: 'gpt-4o',
              choices: [
                {
                  message: { content: 'Hello!' },
                  finish_reason: 'stop',
                },
              ],
              usage: {
                prompt_tokens: 10,
                completion_tokens: 5,
                total_tokens: 15,
              },
            }),
          },
        },
      };

      // Instrument the client
      instrumentOpenAI(mockClient as any);

      // Make a call
      const response = await mockClient.chat.completions.create({
        model: 'gpt-4o',
        messages: [{ role: 'user', content: 'Hi' }],
      });

      expect(response.choices[0].message.content).toBe('Hello!');
      expect(mockClient.chat.completions.create).toHaveBeenCalled();

      // Shutdown
      await observatory.shutdown();
      expect(observatory.isInitialized()).toBe(false);
    });

    it('should track costs correctly', async () => {
      await initObservatory({
        serviceName: 'cost-test',
        debug: false,
      });

      const costs: any[] = [];

      const mockClient = {
        chat: {
          completions: {
            create: jest.fn().mockResolvedValue({
              model: 'gpt-4o',
              usage: {
                prompt_tokens: 1000,
                completion_tokens: 500,
                total_tokens: 1500,
              },
            }),
          },
        },
      };

      instrumentOpenAI(mockClient as any, {
        enableCost: true,
        spanProcessor: (span) => {
          if (span.cost) {
            costs.push(span.cost);
          }
        },
      });

      await mockClient.chat.completions.create({
        model: 'gpt-4o',
        messages: [{ role: 'user', content: 'Test' }],
      });

      // Verify cost was calculated
      expect(costs.length).toBeGreaterThan(0);
      expect(costs[0].amountUsd).toBeGreaterThan(0);
    });
  });

  describe('Pricing Integration', () => {
    it('should have pricing for common models', () => {
      const commonModels = [
        'gpt-4o',
        'gpt-4o-mini',
        'gpt-4',
        'gpt-3.5-turbo',
        'claude-3-opus-20240229',
        'claude-3-5-sonnet-20241022',
        'gemini-1.5-pro',
        'mistral-large-latest',
      ];

      commonModels.forEach((model) => {
        expect(PricingEngine.hasPricing(model)).toBe(true);
      });
    });

    it('should calculate realistic costs', () => {
      // GPT-4o with 1k prompt and 1k completion
      const cost = PricingEngine.calculateCost('gpt-4o', 1000, 1000);

      // Should be $0.0025 + $0.010 = $0.0125
      expect(cost).toBeCloseTo(0.0125, 4);
      expect(cost).toBeGreaterThan(0);
      expect(cost).toBeLessThan(1); // Sanity check
    });

    it('should compare models accurately', () => {
      const models = ['gpt-4o', 'gpt-4o-mini'];
      const results = PricingEngine.compareCosts(models, 1000, 1000);

      expect(results).toHaveLength(2);

      const gpt4oCost = results.find((r) => r.model === 'gpt-4o')!.cost;
      const miniCost = results.find((r) => r.model === 'gpt-4o-mini')!.cost;

      // GPT-4o mini should be significantly cheaper
      expect(miniCost).toBeLessThan(gpt4oCost);
    });
  });

  describe('Error Handling', () => {
    it('should handle instrumentation errors gracefully', async () => {
      await initObservatory({
        serviceName: 'error-test',
        debug: false,
      });

      const mockClient = {
        chat: {
          completions: {
            create: jest.fn().mockRejectedValue(new Error('API Error')),
          },
        },
      };

      instrumentOpenAI(mockClient as any);

      // Error should propagate but be captured in trace
      await expect(
        mockClient.chat.completions.create({
          model: 'gpt-4o',
          messages: [{ role: 'user', content: 'Test' }],
        })
      ).rejects.toThrow('API Error');
    });

    it('should handle missing pricing gracefully', () => {
      const result = PricingEngine.compareCosts(
        ['gpt-4o', 'nonexistent-model'],
        1000,
        1000
      );

      expect(result).toHaveLength(2);
      expect(result[0].error).toBeUndefined();
      expect(result[1].error).toBeDefined();
    });
  });

  describe('Metadata Tracking', () => {
    it('should attach custom metadata to spans', async () => {
      await initObservatory({
        serviceName: 'metadata-test',
      });

      const capturedSpans: any[] = [];

      const mockClient = {
        chat: {
          completions: {
            create: jest.fn().mockResolvedValue({
              model: 'gpt-4o',
              usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 },
            }),
          },
        },
      };

      instrumentOpenAI(mockClient as any, {
        metadata: {
          userId: 'user-123',
          sessionId: 'session-456',
          environment: 'test',
          tags: ['test', 'integration'],
        },
        spanProcessor: (span) => {
          capturedSpans.push(span);
        },
      });

      await mockClient.chat.completions.create({
        model: 'gpt-4o',
        messages: [{ role: 'user', content: 'Test' }],
      });

      expect(capturedSpans.length).toBeGreaterThan(0);
      expect(capturedSpans[0].metadata).toBeDefined();
    });
  });
});
