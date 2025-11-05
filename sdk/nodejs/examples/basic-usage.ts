// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

/**
 * Basic usage example for LLM Observatory SDK.
 */

import { initObservatory, instrumentOpenAI, shutdownObservatory } from '../src';
import OpenAI from 'openai';

async function main() {
  // Initialize LLM Observatory
  const observatory = await initObservatory({
    serviceName: 'basic-example',
    serviceVersion: '1.0.0',
    otlpEndpoint: 'http://localhost:4317',
    environment: 'development',
    debug: true, // Enable debug logging
  });

  console.log('Observatory initialized');

  // Create OpenAI client
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  // Instrument the OpenAI client
  instrumentOpenAI(openai, {
    enableCost: true,
    enableStreaming: true,
    metadata: {
      environment: 'development',
      tags: ['example', 'basic'],
    },
  });

  console.log('OpenAI client instrumented');

  try {
    // Make a simple chat completion call
    console.log('\nMaking chat completion request...');
    const response = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: 'You are a helpful assistant.',
        },
        {
          role: 'user',
          content: 'What is the capital of France?',
        },
      ],
      max_tokens: 100,
      temperature: 0.7,
    });

    console.log('\nResponse:', response.choices[0].message.content);
    console.log('Tokens used:', response.usage);

    // Flush telemetry data
    await observatory.flush();
    console.log('\nTelemetry data flushed');
  } catch (error) {
    console.error('Error:', error);
  } finally {
    // Shutdown observatory
    await shutdownObservatory();
    console.log('Observatory shutdown');
  }
}

main().catch(console.error);
