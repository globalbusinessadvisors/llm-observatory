// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

/**
 * Cost calculation engine with real-world LLM pricing data.
 * Pricing data updated as of January 2025.
 */

import { Pricing, Provider, Cost, TokenUsage, ErrorType, ObservatoryError } from './types';

/**
 * Comprehensive pricing database for LLM models.
 */
class PricingDatabase {
  private prices: Map<string, Pricing> = new Map();

  constructor() {
    this.loadOpenAIPricing();
    this.loadAnthropicPricing();
    this.loadGooglePricing();
    this.loadMistralPricing();
  }

  /**
   * Get pricing for a specific model.
   */
  getPricing(model: string): Pricing {
    const pricing = this.prices.get(model);
    if (!pricing) {
      throw new ObservatoryError(
        ErrorType.PricingNotFound,
        `Pricing not found for model: ${model}`,
        { model }
      );
    }
    return pricing;
  }

  /**
   * Check if pricing exists for a model.
   */
  hasPricing(model: string): boolean {
    return this.prices.has(model);
  }

  /**
   * List all models with pricing data.
   */
  listModels(): string[] {
    return Array.from(this.prices.keys());
  }

  /**
   * Add custom pricing for a model.
   */
  addPricing(pricing: Pricing): void {
    this.prices.set(pricing.model, pricing);
  }

  /**
   * Load OpenAI pricing (as of January 2025).
   * Source: https://openai.com/api/pricing/
   */
  private loadOpenAIPricing(): void {
    const openaiModels: Pricing[] = [
      // GPT-4o (Latest flagship model)
      { model: 'gpt-4o', promptCostPer1k: 0.0025, completionCostPer1k: 0.01 },
      // GPT-4o mini (Cost-effective variant)
      { model: 'gpt-4o-mini', promptCostPer1k: 0.00015, completionCostPer1k: 0.0006 },
      // GPT-4 Turbo
      { model: 'gpt-4-turbo', promptCostPer1k: 0.01, completionCostPer1k: 0.03 },
      { model: 'gpt-4-turbo-preview', promptCostPer1k: 0.01, completionCostPer1k: 0.03 },
      // GPT-4 (Original)
      { model: 'gpt-4', promptCostPer1k: 0.03, completionCostPer1k: 0.06 },
      { model: 'gpt-4-0613', promptCostPer1k: 0.03, completionCostPer1k: 0.06 },
      { model: 'gpt-4-32k', promptCostPer1k: 0.06, completionCostPer1k: 0.12 },
      // GPT-3.5 Turbo
      { model: 'gpt-3.5-turbo', promptCostPer1k: 0.0005, completionCostPer1k: 0.0015 },
      { model: 'gpt-3.5-turbo-0125', promptCostPer1k: 0.0005, completionCostPer1k: 0.0015 },
      { model: 'gpt-3.5-turbo-16k', promptCostPer1k: 0.001, completionCostPer1k: 0.002 },
      // o1 models (Reasoning)
      { model: 'o1-preview', promptCostPer1k: 0.015, completionCostPer1k: 0.06 },
      { model: 'o1-mini', promptCostPer1k: 0.003, completionCostPer1k: 0.012 },
    ];

    openaiModels.forEach((pricing) => this.prices.set(pricing.model, pricing));
  }

  /**
   * Load Anthropic pricing (as of January 2025).
   * Source: https://www.anthropic.com/api
   */
  private loadAnthropicPricing(): void {
    const anthropicModels: Pricing[] = [
      // Claude Sonnet 4.5 (Latest flagship)
      { model: 'claude-sonnet-4.5', promptCostPer1k: 0.003, completionCostPer1k: 0.015 },
      { model: 'claude-sonnet-4-5-20250929', promptCostPer1k: 0.003, completionCostPer1k: 0.015 },
      // Claude 3.5 Sonnet
      {
        model: 'claude-3-5-sonnet-20241022',
        promptCostPer1k: 0.003,
        completionCostPer1k: 0.015,
      },
      // Claude 3.5 Haiku
      { model: 'claude-3-5-haiku-20241022', promptCostPer1k: 0.001, completionCostPer1k: 0.005 },
      // Claude 3 Opus
      { model: 'claude-3-opus-20240229', promptCostPer1k: 0.015, completionCostPer1k: 0.075 },
      // Claude 3 Sonnet
      { model: 'claude-3-sonnet-20240229', promptCostPer1k: 0.003, completionCostPer1k: 0.015 },
      // Claude 3 Haiku
      {
        model: 'claude-3-haiku-20240307',
        promptCostPer1k: 0.00025,
        completionCostPer1k: 0.00125,
      },
      // Claude 2.1
      { model: 'claude-2.1', promptCostPer1k: 0.008, completionCostPer1k: 0.024 },
      // Claude 2.0
      { model: 'claude-2.0', promptCostPer1k: 0.008, completionCostPer1k: 0.024 },
      // Claude Instant
      { model: 'claude-instant-1.2', promptCostPer1k: 0.0008, completionCostPer1k: 0.0024 },
    ];

    anthropicModels.forEach((pricing) => this.prices.set(pricing.model, pricing));
  }

  /**
   * Load Google Gemini pricing (as of January 2025).
   * Source: https://ai.google.dev/pricing
   */
  private loadGooglePricing(): void {
    const googleModels: Pricing[] = [
      // Gemini 2.5 Pro (Latest)
      { model: 'gemini-2.5-pro', promptCostPer1k: 0.00125, completionCostPer1k: 0.005 },
      // Gemini 2.5 Flash
      { model: 'gemini-2.5-flash', promptCostPer1k: 0.000075, completionCostPer1k: 0.0003 },
      // Gemini 1.5 Pro
      { model: 'gemini-1.5-pro', promptCostPer1k: 0.00125, completionCostPer1k: 0.005 },
      { model: 'gemini-1.5-pro-latest', promptCostPer1k: 0.00125, completionCostPer1k: 0.005 },
      // Gemini 1.5 Flash
      { model: 'gemini-1.5-flash', promptCostPer1k: 0.000075, completionCostPer1k: 0.0003 },
      { model: 'gemini-1.5-flash-latest', promptCostPer1k: 0.000075, completionCostPer1k: 0.0003 },
      // Gemini 1.0 Pro
      { model: 'gemini-1.0-pro', promptCostPer1k: 0.0005, completionCostPer1k: 0.0015 },
      { model: 'gemini-pro', promptCostPer1k: 0.0005, completionCostPer1k: 0.0015 },
    ];

    googleModels.forEach((pricing) => this.prices.set(pricing.model, pricing));
  }

  /**
   * Load Mistral AI pricing (as of January 2025).
   * Source: https://mistral.ai/technology/#pricing
   */
  private loadMistralPricing(): void {
    const mistralModels: Pricing[] = [
      // Mistral Large
      { model: 'mistral-large-latest', promptCostPer1k: 0.002, completionCostPer1k: 0.006 },
      { model: 'mistral-large-2407', promptCostPer1k: 0.002, completionCostPer1k: 0.006 },
      // Mistral Medium
      { model: 'mistral-medium-latest', promptCostPer1k: 0.0027, completionCostPer1k: 0.0081 },
      // Mistral Small
      { model: 'mistral-small-latest', promptCostPer1k: 0.0002, completionCostPer1k: 0.0006 },
      // Mistral 7B (self-hosted)
      { model: 'mistral-7b', promptCostPer1k: 0.0, completionCostPer1k: 0.0 },
      // Mistral 8x7B (self-hosted)
      { model: 'mixtral-8x7b', promptCostPer1k: 0.0, completionCostPer1k: 0.0 },
    ];

    mistralModels.forEach((pricing) => this.prices.set(pricing.model, pricing));
  }
}

/**
 * Global pricing database singleton.
 */
const pricingDB = new PricingDatabase();

/**
 * Pricing engine for calculating LLM costs.
 */
export class PricingEngine {
  /**
   * Calculate cost for a given model and token usage.
   *
   * @param model - Model identifier (e.g., "gpt-4", "claude-3-opus")
   * @param promptTokens - Number of input tokens
   * @param completionTokens - Number of output tokens
   * @returns Total cost in USD
   */
  static calculateCost(model: string, promptTokens: number, completionTokens: number): number {
    const pricing = pricingDB.getPricing(model);
    const promptCost = (promptTokens / 1000) * pricing.promptCostPer1k;
    const completionCost = (completionTokens / 1000) * pricing.completionCostPer1k;
    return promptCost + completionCost;
  }

  /**
   * Calculate cost breakdown for a given model and token usage.
   *
   * @returns Cost object with breakdown
   */
  static calculateCostBreakdown(
    model: string,
    promptTokens: number,
    completionTokens: number
  ): Cost {
    const pricing = pricingDB.getPricing(model);
    const promptCost = (promptTokens / 1000) * pricing.promptCostPer1k;
    const completionCost = (completionTokens / 1000) * pricing.completionCostPer1k;
    const totalCost = promptCost + completionCost;

    return {
      amountUsd: totalCost,
      currency: 'USD',
      promptCost,
      completionCost,
    };
  }

  /**
   * Calculate cost from TokenUsage object.
   */
  static calculateCostFromUsage(model: string, usage: TokenUsage): Cost {
    return this.calculateCostBreakdown(model, usage.promptTokens, usage.completionTokens);
  }

  /**
   * Estimate cost for a given model and approximate token count.
   * Assumes 70/30 split between prompt and completion (common pattern).
   */
  static estimateCost(model: string, estimatedTokens: number): number {
    const promptTokens = Math.floor(estimatedTokens * 0.7);
    const completionTokens = Math.floor(estimatedTokens * 0.3);
    return this.calculateCost(model, promptTokens, completionTokens);
  }

  /**
   * Compare costs across different models for the same token usage.
   */
  static compareCosts(
    models: string[],
    promptTokens: number,
    completionTokens: number
  ): Array<{ model: string; cost: number; error?: string }> {
    return models.map((model) => {
      try {
        const cost = this.calculateCost(model, promptTokens, completionTokens);
        return { model, cost };
      } catch (error) {
        return {
          model,
          cost: 0,
          error: error instanceof Error ? error.message : 'Unknown error',
        };
      }
    });
  }

  /**
   * Get pricing information for a model.
   */
  static getPricing(model: string): Pricing {
    return pricingDB.getPricing(model);
  }

  /**
   * Check if pricing exists for a model.
   */
  static hasPricing(model: string): boolean {
    return pricingDB.hasPricing(model);
  }

  /**
   * List all models with pricing data.
   */
  static listModels(): string[] {
    return pricingDB.listModels();
  }

  /**
   * Add custom pricing for a model.
   */
  static addCustomPricing(pricing: Pricing): void {
    pricingDB.addPricing(pricing);
  }

  /**
   * Get provider from model name (heuristic-based).
   */
  static getProviderFromModel(model: string): Provider {
    const modelLower = model.toLowerCase();

    if (modelLower.includes('gpt') || modelLower.includes('o1')) {
      return Provider.OpenAI;
    }
    if (modelLower.includes('claude')) {
      return Provider.Anthropic;
    }
    if (modelLower.includes('gemini')) {
      return Provider.Google;
    }
    if (modelLower.includes('mistral') || modelLower.includes('mixtral')) {
      return Provider.Mistral;
    }

    return Provider.SelfHosted;
  }
}

/**
 * Export pricing database instance for testing.
 */
export { pricingDB };
