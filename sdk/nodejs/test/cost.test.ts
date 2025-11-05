// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

import { PricingEngine } from '../src/cost';
import { Provider, ErrorType, ObservatoryError } from '../src/types';

describe('PricingEngine', () => {
  describe('calculateCost', () => {
    it('should calculate cost for GPT-4', () => {
      const cost = PricingEngine.calculateCost('gpt-4', 1000, 500);
      // $0.03 for 1k prompt + $0.03 for 500 completion = $0.06
      expect(cost).toBeCloseTo(0.06, 4);
    });

    it('should calculate cost for GPT-4o', () => {
      const cost = PricingEngine.calculateCost('gpt-4o', 1000, 1000);
      // $0.0025 for 1k prompt + $0.010 for 1k completion = $0.0125
      expect(cost).toBeCloseTo(0.0125, 4);
    });

    it('should calculate cost for Claude', () => {
      const cost = PricingEngine.calculateCost('claude-3-opus-20240229', 1000, 1000);
      // $0.015 for 1k prompt + $0.075 for 1k completion = $0.09
      expect(cost).toBeCloseTo(0.09, 4);
    });

    it('should throw error for unknown model', () => {
      expect(() => {
        PricingEngine.calculateCost('unknown-model', 1000, 1000);
      }).toThrow(ObservatoryError);
    });
  });

  describe('calculateCostBreakdown', () => {
    it('should return cost breakdown', () => {
      const cost = PricingEngine.calculateCostBreakdown('gpt-4o', 1000, 1000);

      expect(cost.amountUsd).toBeCloseTo(0.0125, 4);
      expect(cost.promptCost).toBeCloseTo(0.0025, 4);
      expect(cost.completionCost).toBeCloseTo(0.01, 4);
      expect(cost.currency).toBe('USD');
    });
  });

  describe('calculateCostFromUsage', () => {
    it('should calculate cost from token usage object', () => {
      const usage = {
        promptTokens: 1000,
        completionTokens: 500,
        totalTokens: 1500,
      };

      const cost = PricingEngine.calculateCostFromUsage('gpt-4o-mini', usage);
      expect(cost.amountUsd).toBeGreaterThan(0);
      expect(cost.promptCost).toBeDefined();
      expect(cost.completionCost).toBeDefined();
    });
  });

  describe('compareCosts', () => {
    it('should compare costs across models', () => {
      const models = ['gpt-4o', 'gpt-4o-mini', 'gpt-3.5-turbo'];
      const comparisons = PricingEngine.compareCosts(models, 1000, 1000);

      expect(comparisons).toHaveLength(3);
      comparisons.forEach((result) => {
        expect(result.model).toBeDefined();
        expect(result.cost).toBeGreaterThan(0);
        expect(result.error).toBeUndefined();
      });

      // gpt-4o-mini should be cheaper than gpt-4o
      const miniCost = comparisons.find((c) => c.model === 'gpt-4o-mini')!.cost;
      const gpt4oCost = comparisons.find((c) => c.model === 'gpt-4o')!.cost;
      expect(miniCost).toBeLessThan(gpt4oCost);
    });

    it('should handle errors for unknown models', () => {
      const models = ['gpt-4o', 'unknown-model'];
      const comparisons = PricingEngine.compareCosts(models, 1000, 1000);

      expect(comparisons).toHaveLength(2);
      expect(comparisons[0].error).toBeUndefined();
      expect(comparisons[1].error).toBeDefined();
    });
  });

  describe('addCustomPricing', () => {
    it('should add custom pricing', () => {
      const customModel = 'test-model-' + Date.now();
      PricingEngine.addCustomPricing({
        model: customModel,
        promptCostPer1k: 0.001,
        completionCostPer1k: 0.002,
      });

      expect(PricingEngine.hasPricing(customModel)).toBe(true);
      const cost = PricingEngine.calculateCost(customModel, 1000, 500);
      expect(cost).toBeCloseTo(0.002, 4); // 0.001 + 0.001
    });
  });

  describe('getProviderFromModel', () => {
    it('should identify OpenAI models', () => {
      expect(PricingEngine.getProviderFromModel('gpt-4')).toBe(Provider.OpenAI);
      expect(PricingEngine.getProviderFromModel('gpt-3.5-turbo')).toBe(Provider.OpenAI);
      expect(PricingEngine.getProviderFromModel('o1-preview')).toBe(Provider.OpenAI);
    });

    it('should identify Anthropic models', () => {
      expect(PricingEngine.getProviderFromModel('claude-3-opus')).toBe(Provider.Anthropic);
      expect(PricingEngine.getProviderFromModel('claude-sonnet-4.5')).toBe(Provider.Anthropic);
    });

    it('should identify Google models', () => {
      expect(PricingEngine.getProviderFromModel('gemini-pro')).toBe(Provider.Google);
      expect(PricingEngine.getProviderFromModel('gemini-1.5-flash')).toBe(Provider.Google);
    });

    it('should default to SelfHosted for unknown', () => {
      expect(PricingEngine.getProviderFromModel('unknown-model')).toBe(Provider.SelfHosted);
    });
  });

  describe('listModels', () => {
    it('should list all available models', () => {
      const models = PricingEngine.listModels();
      expect(models.length).toBeGreaterThan(15);
      expect(models).toContain('gpt-4');
      expect(models).toContain('claude-3-opus-20240229');
      expect(models).toContain('gemini-1.5-pro');
    });
  });
});
