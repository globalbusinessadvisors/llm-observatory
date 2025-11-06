// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

/**
 * OpenAI client instrumentation for automatic tracing and cost tracking.
 */

import { Span } from '@opentelemetry/api';
import {
  InstrumentOpenAIOptions,
  Provider,
  TokenUsage,
  ErrorType,
} from './types';
import { LLMTracer, createTracer } from './tracing';
import { PricingEngine } from './cost';

/**
 * Instrument an OpenAI client instance.
 */
export function instrumentOpenAI(client: any, options: InstrumentOpenAIOptions = {}): any {
  const defaultOptions: Required<InstrumentOpenAIOptions> = {
    enableCost: options.enableCost ?? true,
    enableStreaming: options.enableStreaming ?? true,
    logPayloads: options.logPayloads ?? false,
    metadata: options.metadata || {},
    spanProcessor: options.spanProcessor || (() => {}),
  };

  const tracer = createTracer();

  // Wrap chat completions
  if (client.chat?.completions) {
    const originalCreate = client.chat.completions.create.bind(client.chat.completions);

    client.chat.completions.create = async function (params: any) {
      return wrapChatCompletion(originalCreate, params, tracer, defaultOptions);
    };
  }

  // Wrap completions (legacy)
  if (client.completions?.create) {
    const originalCreate = client.completions.create.bind(client.completions);

    client.completions.create = async function (params: any) {
      return wrapCompletion(originalCreate, params, tracer, defaultOptions);
    };
  }

  // Wrap embeddings
  if (client.embeddings?.create) {
    const originalCreate = client.embeddings.create.bind(client.embeddings);

    client.embeddings.create = async function (params: any) {
      return wrapEmbedding(originalCreate, params, tracer, defaultOptions);
    };
  }

  return client;
}

/**
 * Wrap chat completion calls.
 */
async function wrapChatCompletion(
  originalFn: Function,
  params: any,
  tracer: LLMTracer,
  options: Required<InstrumentOpenAIOptions>
): Promise<any> {
  const model = params.model;
  const isStreaming = params.stream === true;

  // Start span
  const span = tracer.startSpan('openai.chat.completions.create', Provider.OpenAI, model, {
    attributes: {
      'llm.streaming.enabled': isStreaming,
    },
  });

  // Record request parameters
  tracer.recordRequestParams(span, params);

  // Record metadata
  if (options.metadata) {
    tracer.recordMetadata(span, options.metadata);
  }

  // Log request payload if enabled
  if (options.logPayloads) {
    span.setAttribute('llm.request.payload', JSON.stringify(params));
  }

  const startTime = Date.now();

  try {
    const response = await originalFn(params);

    // Handle streaming response
    if (isStreaming && options.enableStreaming) {
      return handleStreamingResponse(response, span, tracer, model, startTime, options);
    }

    // Handle non-streaming response
    return handleNonStreamingResponse(response, span, tracer, model, startTime, options);
  } catch (error) {
    handleError(error, span, tracer);
    throw error;
  }
}

/**
 * Handle non-streaming chat completion response.
 */
function handleNonStreamingResponse(
  response: any,
  span: Span,
  tracer: LLMTracer,
  model: string,
  startTime: number,
  options: Required<InstrumentOpenAIOptions>
): any {
  const endTime = Date.now();
  const duration = endTime - startTime;

  // Record response data
  if (response.id) {
    tracer.recordResponseData(span, {
      id: response.id,
      model: response.model,
      finish_reason: response.choices?.[0]?.finish_reason,
    });
  }

  // Record token usage
  if (response.usage) {
    const tokenUsage: TokenUsage = {
      promptTokens: response.usage.prompt_tokens,
      completionTokens: response.usage.completion_tokens,
      totalTokens: response.usage.total_tokens,
    };
    tracer.recordTokenUsage(span, tokenUsage);

    // Calculate and record cost
    if (options.enableCost && PricingEngine.hasPricing(model)) {
      try {
        const cost = PricingEngine.calculateCostFromUsage(model, tokenUsage);
        tracer.recordCost(span, cost);
      } catch (error) {
        // Pricing not available, continue without cost tracking
        console.warn(`Cost calculation failed for model ${model}:`, error);
      }
    }
  }

  // Record duration
  span.setAttribute('llm.duration_ms', duration);

  // Log response payload if enabled
  if (options.logPayloads) {
    span.setAttribute('llm.response.payload', JSON.stringify(response));
  }

  // Call custom span processor
  options.spanProcessor({
    traceId: span.spanContext().traceId,
    spanId: span.spanContext().spanId,
    name: 'openai.chat.completions.create',
    provider: Provider.OpenAI,
    model,
    tokenUsage: response.usage
      ? {
          promptTokens: response.usage.prompt_tokens,
          completionTokens: response.usage.completion_tokens,
          totalTokens: response.usage.total_tokens,
        }
      : undefined,
    startTime: new Date(startTime),
    endTime: new Date(endTime),
  });

  // End span
  tracer.endSpan(span);

  return response;
}

/**
 * Handle streaming chat completion response.
 */
function handleStreamingResponse(
  stream: any,
  span: Span,
  tracer: LLMTracer,
  model: string,
  startTime: number,
  options: Required<InstrumentOpenAIOptions>
): any {
  let chunkCount = 0;
  let firstTokenTime: number | undefined;
  let accumulatedTokens = {
    promptTokens: 0,
    completionTokens: 0,
    totalTokens: 0,
  };

  // Create a new async generator that wraps the original stream
  const wrappedStream = (async function* () {
    try {
      for await (const chunk of stream) {
        chunkCount++;

        // Record time to first token
        if (chunkCount === 1) {
          firstTokenTime = Date.now() - startTime;
          span.setAttribute('llm.latency.ttft_ms', firstTokenTime);
        }

        // Accumulate token usage if available
        if (chunk.usage) {
          accumulatedTokens = {
            promptTokens: chunk.usage.prompt_tokens || 0,
            completionTokens: chunk.usage.completion_tokens || 0,
            totalTokens: chunk.usage.total_tokens || 0,
          };
        }

        yield chunk;
      }

      // Stream completed successfully
      const endTime = Date.now();
      const duration = endTime - startTime;

      // Record streaming metrics
      tracer.recordStreaming(span, chunkCount, firstTokenTime);
      span.setAttribute('llm.duration_ms', duration);

      // Record token usage and cost
      if (accumulatedTokens.totalTokens > 0) {
        tracer.recordTokenUsage(span, accumulatedTokens);

        if (options.enableCost && PricingEngine.hasPricing(model)) {
          try {
            const cost = PricingEngine.calculateCostFromUsage(model, accumulatedTokens);
            tracer.recordCost(span, cost);
          } catch (error) {
            console.warn(`Cost calculation failed for model ${model}:`, error);
          }
        }
      }

      // Call custom span processor
      options.spanProcessor({
        traceId: span.spanContext().traceId,
        spanId: span.spanContext().spanId,
        name: 'openai.chat.completions.create',
        provider: Provider.OpenAI,
        model,
        tokenUsage: accumulatedTokens.totalTokens > 0 ? accumulatedTokens : undefined,
        startTime: new Date(startTime),
        endTime: new Date(endTime),
      });

      // End span
      tracer.endSpan(span);
    } catch (error) {
      handleError(error, span, tracer);
      throw error;
    }
  })();

  return wrappedStream;
}

/**
 * Wrap completion calls (legacy).
 */
async function wrapCompletion(
  originalFn: Function,
  params: any,
  tracer: LLMTracer,
  options: Required<InstrumentOpenAIOptions>
): Promise<any> {
  const model = params.model;
  const span = tracer.startSpan('openai.completions.create', Provider.OpenAI, model);

  tracer.recordRequestParams(span, params);
  if (options.metadata) {
    tracer.recordMetadata(span, options.metadata);
  }

  const startTime = Date.now();

  try {
    const response = await originalFn(params);
    const endTime = Date.now();

    // Record token usage
    if (response.usage) {
      const tokenUsage: TokenUsage = {
        promptTokens: response.usage.prompt_tokens,
        completionTokens: response.usage.completion_tokens,
        totalTokens: response.usage.total_tokens,
      };
      tracer.recordTokenUsage(span, tokenUsage);

      // Calculate cost
      if (options.enableCost && PricingEngine.hasPricing(model)) {
        try {
          const cost = PricingEngine.calculateCostFromUsage(model, tokenUsage);
          tracer.recordCost(span, cost);
        } catch (error) {
          console.warn(`Cost calculation failed for model ${model}:`, error);
        }
      }
    }

    span.setAttribute('llm.duration_ms', endTime - startTime);
    tracer.endSpan(span);

    return response;
  } catch (error) {
    handleError(error, span, tracer);
    throw error;
  }
}

/**
 * Wrap embedding calls.
 */
async function wrapEmbedding(
  originalFn: Function,
  params: any,
  tracer: LLMTracer,
  options: Required<InstrumentOpenAIOptions>
): Promise<any> {
  const model = params.model;
  const span = tracer.startSpan('openai.embeddings.create', Provider.OpenAI, model);

  if (options.metadata) {
    tracer.recordMetadata(span, options.metadata);
  }

  const startTime = Date.now();

  try {
    const response = await originalFn(params);
    const endTime = Date.now();

    // Record token usage
    if (response.usage) {
      const tokenUsage: TokenUsage = {
        promptTokens: response.usage.prompt_tokens,
        completionTokens: 0,
        totalTokens: response.usage.total_tokens,
      };
      tracer.recordTokenUsage(span, tokenUsage);

      // Calculate cost
      if (options.enableCost && PricingEngine.hasPricing(model)) {
        try {
          const cost = PricingEngine.calculateCostFromUsage(model, tokenUsage);
          tracer.recordCost(span, cost);
        } catch (error) {
          console.warn(`Cost calculation failed for model ${model}:`, error);
        }
      }
    }

    // Record embedding dimensions
    if (response.data && response.data.length > 0) {
      span.setAttribute('llm.embedding.dimensions', response.data[0].embedding.length);
      span.setAttribute('llm.embedding.count', response.data.length);
    }

    span.setAttribute('llm.duration_ms', endTime - startTime);
    tracer.endSpan(span);

    return response;
  } catch (error) {
    handleError(error, span, tracer);
    throw error;
  }
}

/**
 * Handle errors and record them on the span.
 */
function handleError(error: any, span: Span, tracer: LLMTracer): void {
  if (error instanceof Error) {
    tracer.recordError(span, error);

    // Record additional error attributes
    if ((error as any).response) {
      span.setAttribute('error.status_code', (error as any).response.status);
    }

    // Determine error type
    let errorType = ErrorType.Unknown;
    const errorMessage = error.message.toLowerCase();

    if (errorMessage.includes('timeout')) {
      errorType = ErrorType.Timeout;
    } else if (errorMessage.includes('rate limit')) {
      errorType = ErrorType.RateLimited;
    } else if (errorMessage.includes('auth')) {
      errorType = ErrorType.AuthenticationError;
    } else if (errorMessage.includes('network') || errorMessage.includes('connection')) {
      errorType = ErrorType.NetworkError;
    }

    span.setAttribute('error.type', errorType);
  }

  span.end();
}

/**
 * Create a traced wrapper around any async function.
 */
export function traced<T extends (...args: any[]) => Promise<any>>(
  fn: T,
  spanName: string,
  provider: Provider,
  model: string
): T {
  const tracer = createTracer();

  return (async (...args: any[]) => {
    const span = tracer.startSpan(spanName, provider, model);
    const startTime = Date.now();

    try {
      const result = await fn(...args);
      const endTime = Date.now();

      span.setAttribute('llm.duration_ms', endTime - startTime);
      tracer.endSpan(span);

      return result;
    } catch (error) {
      if (error instanceof Error) {
        tracer.recordError(span, error);
      }
      span.end();
      throw error;
    }
  }) as T;
}
