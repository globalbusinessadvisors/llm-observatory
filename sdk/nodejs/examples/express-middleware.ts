// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

/**
 * Express middleware example for LLM Observatory SDK.
 */

import express from 'express';
import { initObservatory, instrumentOpenAI, getObservatory } from '../src';
import OpenAI from 'openai';

async function main() {
  // Initialize observatory
  const observatory = await initObservatory({
    serviceName: 'llm-api',
    serviceVersion: '1.0.0',
    otlpEndpoint: 'http://localhost:4317',
    environment: 'production',
  });

  // Create Express app
  const app = express();
  app.use(express.json());

  // Add observatory middleware for request tracing
  app.use(
    observatory.middleware({
      captureRequestBody: true,
      captureResponseBody: false,
      ignorePaths: ['/health', '/metrics'],
      spanNameGenerator: (req) => `HTTP ${req.method} ${req.path}`,
    })
  );

  // Create and instrument OpenAI client
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  instrumentOpenAI(openai, {
    enableCost: true,
    metadata: {
      environment: 'production',
      tags: ['api', 'express'],
    },
  });

  // Health check endpoint
  app.get('/health', (req, res) => {
    res.json({ status: 'healthy', service: 'llm-api' });
  });

  // Chat completion endpoint
  app.post('/chat', async (req, res) => {
    try {
      const { message, model = 'gpt-4o-mini' } = req.body;

      if (!message) {
        return res.status(400).json({ error: 'Message is required' });
      }

      const response = await openai.chat.completions.create({
        model,
        messages: [{ role: 'user', content: message }],
        max_tokens: 500,
      });

      res.json({
        response: response.choices[0].message.content,
        usage: response.usage,
        model: response.model,
      });
    } catch (error) {
      console.error('Error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  // Streaming endpoint
  app.post('/chat/stream', async (req, res) => {
    try {
      const { message, model = 'gpt-4o-mini' } = req.body;

      if (!message) {
        return res.status(400).json({ error: 'Message is required' });
      }

      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');

      const stream = await openai.chat.completions.create({
        model,
        messages: [{ role: 'user', content: message }],
        stream: true,
        max_tokens: 500,
      });

      for await (const chunk of stream) {
        const content = chunk.choices[0]?.delta?.content || '';
        if (content) {
          res.write(`data: ${JSON.stringify({ content })}\n\n`);
        }
      }

      res.write('data: [DONE]\n\n');
      res.end();
    } catch (error) {
      console.error('Error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  // Start server
  const PORT = process.env.PORT || 3000;
  const server = app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
  });

  // Graceful shutdown
  process.on('SIGTERM', async () => {
    console.log('SIGTERM received, shutting down gracefully...');
    server.close(async () => {
      await observatory.shutdown();
      process.exit(0);
    });
  });
}

main().catch(console.error);
