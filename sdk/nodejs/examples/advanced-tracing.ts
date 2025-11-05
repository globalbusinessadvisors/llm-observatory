// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

/**
 * Advanced tracing example with custom spans.
 */

import { initObservatory, instrumentOpenAI, withSpan, getObservatory, Provider } from '../src';
import OpenAI from 'openai';

async function main() {
  await initObservatory({
    serviceName: 'advanced-tracing',
    otlpEndpoint: 'http://localhost:4317',
    debug: true,
  });

  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  instrumentOpenAI(openai);

  try {
    // RAG workflow with nested spans
    await performRAGWorkflow(openai, 'What is observability?');
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await getObservatory().shutdown();
  }
}

/**
 * Simulated RAG (Retrieval-Augmented Generation) workflow.
 */
async function performRAGWorkflow(openai: OpenAI, query: string): Promise<void> {
  await withSpan(
    'rag.query',
    async (span) => {
      console.log('Starting RAG workflow...');
      span.setAttribute('query', query);

      // Step 1: Generate embedding for query
      const embedding = await withSpan(
        'rag.embed_query',
        async (embedSpan) => {
          console.log('Generating query embedding...');
          embedSpan.setAttribute('query_length', query.length);

          const response = await openai.embeddings.create({
            model: 'text-embedding-3-small',
            input: query,
          });

          console.log('Embedding generated:', response.data[0].embedding.slice(0, 5), '...');
          return response.data[0].embedding;
        },
        { provider: Provider.OpenAI, model: 'text-embedding-3-small' }
      );

      // Step 2: Retrieve relevant documents (simulated)
      const documents = await withSpan(
        'rag.retrieve_documents',
        async (retrieveSpan) => {
          console.log('Retrieving documents...');
          retrieveSpan.setAttribute('embedding_dimensions', embedding.length);

          // Simulate vector search
          await new Promise((resolve) => setTimeout(resolve, 100));

          const docs = [
            'Observability is the ability to understand system state from outputs.',
            'It consists of metrics, logs, and traces.',
          ];

          retrieveSpan.setAttribute('documents_retrieved', docs.length);
          console.log(`Retrieved ${docs.length} documents`);

          return docs;
        },
        { provider: Provider.OpenAI, model: 'vector-db' }
      );

      // Step 3: Generate response with context
      const response = await withSpan(
        'rag.generate_response',
        async (genSpan) => {
          console.log('Generating response with context...');
          genSpan.setAttribute('context_length', documents.join(' ').length);

          const context = documents.join('\n\n');
          const prompt = `Context:\n${context}\n\nQuestion: ${query}\n\nAnswer:`;

          const completion = await openai.chat.completions.create({
            model: 'gpt-4o-mini',
            messages: [
              {
                role: 'system',
                content: 'Answer questions based on the provided context.',
              },
              {
                role: 'user',
                content: prompt,
              },
            ],
            max_tokens: 200,
          });

          const answer = completion.choices[0].message.content;
          console.log('\nFinal answer:', answer);

          return answer;
        },
        { provider: Provider.OpenAI, model: 'gpt-4o-mini' }
      );

      span.setAttribute('response_generated', true);
      console.log('\nRAG workflow completed!');
    },
    { attributes: { 'workflow.type': 'rag' } }
  );
}

main().catch(console.error);
