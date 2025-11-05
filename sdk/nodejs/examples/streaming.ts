// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

/**
 * Streaming example for LLM Observatory SDK.
 */

import { initObservatory, instrumentOpenAI, shutdownObservatory } from '../src';
import OpenAI from 'openai';

async function main() {
  // Initialize observatory
  await initObservatory({
    serviceName: 'streaming-example',
    otlpEndpoint: 'http://localhost:4317',
    debug: true,
  });

  // Create and instrument OpenAI client
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  instrumentOpenAI(openai, {
    enableCost: true,
    enableStreaming: true,
    metadata: {
      userId: 'user-123',
      sessionId: 'session-456',
    },
  });

  try {
    console.log('Starting streaming chat completion...\n');

    const stream = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'user',
          content: 'Write a haiku about observability.',
        },
      ],
      stream: true,
      max_tokens: 150,
    });

    // Process the stream
    let fullResponse = '';
    for await (const chunk of stream) {
      const content = chunk.choices[0]?.delta?.content || '';
      fullResponse += content;
      process.stdout.write(content);
    }

    console.log('\n\nStreaming completed!');
    console.log('Full response:', fullResponse);
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await shutdownObservatory();
  }
}

main().catch(console.error);
