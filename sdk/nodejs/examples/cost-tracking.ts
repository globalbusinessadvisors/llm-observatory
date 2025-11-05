// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

/**
 * Cost tracking and comparison example.
 */

import { initObservatory, instrumentOpenAI, PricingEngine, shutdownObservatory } from '../src';
import OpenAI from 'openai';

async function main() {
  // Initialize observatory
  await initObservatory({
    serviceName: 'cost-tracking-example',
    otlpEndpoint: 'http://localhost:4317',
  });

  // List all available models with pricing
  console.log('Available models with pricing:');
  const models = PricingEngine.listModels();
  console.log(`Total models: ${models.length}\n`);

  // Compare costs across models
  console.log('Cost comparison for 1000 prompt tokens and 500 completion tokens:');
  const testModels = ['gpt-4o', 'gpt-4o-mini', 'gpt-3.5-turbo', 'claude-3-5-sonnet-20241022'];
  const comparisons = PricingEngine.compareCosts(testModels, 1000, 500);

  comparisons.forEach(({ model, cost, error }) => {
    if (error) {
      console.log(`  ${model}: Error - ${error}`);
    } else {
      console.log(`  ${model}: $${cost.toFixed(6)}`);
    }
  });

  // Create and instrument OpenAI client
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  instrumentOpenAI(openai, {
    enableCost: true,
    spanProcessor: (span) => {
      // Custom cost tracking
      if (span.cost) {
        console.log(`\n[Cost Alert] ${span.model}:`);
        console.log(`  Total: $${span.cost.amountUsd.toFixed(6)}`);
        console.log(`  Prompt: $${span.cost.promptCost?.toFixed(6) || 'N/A'}`);
        console.log(`  Completion: $${span.cost.completionCost?.toFixed(6) || 'N/A'}`);
      }
    },
  });

  try {
    console.log('\n\nTesting different models...\n');

    // Test GPT-4o mini (cheapest)
    console.log('1. Testing GPT-4o mini:');
    const response1 = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: 'Say hello!' }],
      max_tokens: 50,
    });

    // Test GPT-4o (flagship)
    console.log('\n2. Testing GPT-4o:');
    const response2 = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [{ role: 'user', content: 'Say hello!' }],
      max_tokens: 50,
    });

    // Calculate custom pricing
    console.log('\n\nCustom cost calculation:');
    const customModel = 'my-custom-model';
    PricingEngine.addCustomPricing({
      model: customModel,
      promptCostPer1k: 0.001,
      completionCostPer1k: 0.002,
    });

    const customCost = PricingEngine.calculateCost(customModel, 1000, 500);
    console.log(`Custom model cost: $${customCost.toFixed(6)}`);
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await shutdownObservatory();
  }
}

main().catch(console.error);
