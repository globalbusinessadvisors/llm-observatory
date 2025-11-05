// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

/**
 * Tracing utilities and helpers for LLM Observatory.
 */

import {
  Span,
  SpanStatusCode,
  trace,
  context,
  Context,
  Tracer,
  SpanKind,
} from '@opentelemetry/api';
import { LLMSpanData, Provider, TokenUsage, Cost, Metadata } from './types';

/**
 * Semantic conventions for LLM spans.
 * Based on OpenTelemetry semantic conventions for GenAI.
 */
export const LLMSemanticAttributes = {
  // LLM System attributes
  LLM_SYSTEM: 'llm.system',
  LLM_REQUEST_MODEL: 'llm.request.model',
  LLM_REQUEST_MAX_TOKENS: 'llm.request.max_tokens',
  LLM_REQUEST_TEMPERATURE: 'llm.request.temperature',
  LLM_REQUEST_TOP_P: 'llm.request.top_p',

  // LLM Response attributes
  LLM_RESPONSE_MODEL: 'llm.response.model',
  LLM_RESPONSE_ID: 'llm.response.id',
  LLM_RESPONSE_FINISH_REASON: 'llm.response.finish_reason',

  // Token usage
  LLM_USAGE_PROMPT_TOKENS: 'llm.usage.prompt_tokens',
  LLM_USAGE_COMPLETION_TOKENS: 'llm.usage.completion_tokens',
  LLM_USAGE_TOTAL_TOKENS: 'llm.usage.total_tokens',

  // Cost
  LLM_COST_TOTAL: 'llm.cost.total_usd',
  LLM_COST_PROMPT: 'llm.cost.prompt_usd',
  LLM_COST_COMPLETION: 'llm.cost.completion_usd',

  // Latency
  LLM_LATENCY_TTFT: 'llm.latency.ttft_ms',

  // Streaming
  LLM_STREAMING_ENABLED: 'llm.streaming.enabled',
  LLM_STREAMING_CHUNK_COUNT: 'llm.streaming.chunk_count',

  // User/Session
  LLM_USER_ID: 'llm.user.id',
  LLM_SESSION_ID: 'llm.session.id',
  LLM_REQUEST_ID: 'llm.request.id',
  LLM_ENVIRONMENT: 'llm.environment',

  // Prompts (enable with caution - may contain PII)
  LLM_PROMPT: 'llm.prompt',
  LLM_COMPLETION: 'llm.completion',
} as const;

/**
 * Tracer helper for LLM operations.
 */
export class LLMTracer {
  public tracer: Tracer;

  constructor(tracerName: string = '@llm-observatory/sdk') {
    this.tracer = trace.getTracer(tracerName);
  }

  /**
   * Start a new LLM span.
   */
  startSpan(
    name: string,
    provider: Provider,
    model: string,
    options?: {
      parent?: Context;
      attributes?: Record<string, string | number | boolean>;
    }
  ): Span {
    const ctx = options?.parent || context.active();

    const span = this.tracer.startSpan(
      name,
      {
        kind: SpanKind.CLIENT,
        attributes: {
          [LLMSemanticAttributes.LLM_SYSTEM]: provider,
          [LLMSemanticAttributes.LLM_REQUEST_MODEL]: model,
          ...options?.attributes,
        },
      },
      ctx
    );

    return span;
  }

  /**
   * Record token usage on a span.
   */
  recordTokenUsage(span: Span, usage: TokenUsage): void {
    span.setAttributes({
      [LLMSemanticAttributes.LLM_USAGE_PROMPT_TOKENS]: usage.promptTokens,
      [LLMSemanticAttributes.LLM_USAGE_COMPLETION_TOKENS]: usage.completionTokens,
      [LLMSemanticAttributes.LLM_USAGE_TOTAL_TOKENS]: usage.totalTokens,
    });
  }

  /**
   * Record cost information on a span.
   */
  recordCost(span: Span, cost: Cost): void {
    span.setAttributes({
      [LLMSemanticAttributes.LLM_COST_TOTAL]: cost.amountUsd,
      ...(cost.promptCost && {
        [LLMSemanticAttributes.LLM_COST_PROMPT]: cost.promptCost,
      }),
      ...(cost.completionCost && {
        [LLMSemanticAttributes.LLM_COST_COMPLETION]: cost.completionCost,
      }),
    });
  }

  /**
   * Record metadata on a span.
   */
  recordMetadata(span: Span, metadata: Metadata): void {
    if (metadata.userId) {
      span.setAttribute(LLMSemanticAttributes.LLM_USER_ID, metadata.userId);
    }
    if (metadata.sessionId) {
      span.setAttribute(LLMSemanticAttributes.LLM_SESSION_ID, metadata.sessionId);
    }
    if (metadata.requestId) {
      span.setAttribute(LLMSemanticAttributes.LLM_REQUEST_ID, metadata.requestId);
    }
    if (metadata.environment) {
      span.setAttribute(LLMSemanticAttributes.LLM_ENVIRONMENT, metadata.environment);
    }
    if (metadata.tags && metadata.tags.length > 0) {
      span.setAttribute('llm.tags', metadata.tags.join(','));
    }
    if (metadata.attributes) {
      Object.entries(metadata.attributes).forEach(([key, value]) => {
        span.setAttribute(`llm.custom.${key}`, value);
      });
    }
  }

  /**
   * Record request parameters on a span.
   */
  recordRequestParams(span: Span, params: Record<string, unknown>): void {
    if (params.temperature !== undefined) {
      span.setAttribute(LLMSemanticAttributes.LLM_REQUEST_TEMPERATURE, params.temperature as number);
    }
    if (params.max_tokens !== undefined || params.maxTokens !== undefined) {
      const maxTokens = (params.max_tokens || params.maxTokens) as number;
      span.setAttribute(LLMSemanticAttributes.LLM_REQUEST_MAX_TOKENS, maxTokens);
    }
    if (params.top_p !== undefined || params.topP !== undefined) {
      const topP = (params.top_p || params.topP) as number;
      span.setAttribute(LLMSemanticAttributes.LLM_REQUEST_TOP_P, topP);
    }
  }

  /**
   * Record response data on a span.
   */
  recordResponseData(span: Span, response: Record<string, unknown>): void {
    if (response.id) {
      span.setAttribute(LLMSemanticAttributes.LLM_RESPONSE_ID, response.id as string);
    }
    if (response.model) {
      span.setAttribute(LLMSemanticAttributes.LLM_RESPONSE_MODEL, response.model as string);
    }
    if (response.finish_reason || response.finishReason) {
      const finishReason = (response.finish_reason || response.finishReason) as string;
      span.setAttribute(LLMSemanticAttributes.LLM_RESPONSE_FINISH_REASON, finishReason);
    }
  }

  /**
   * Record an error on a span.
   */
  recordError(span: Span, error: Error): void {
    span.recordException(error);
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message,
    });
    span.setAttribute('error.type', error.name);
  }

  /**
   * Record streaming metrics on a span.
   */
  recordStreaming(span: Span, chunkCount: number, ttft?: number): void {
    span.setAttribute(LLMSemanticAttributes.LLM_STREAMING_ENABLED, true);
    span.setAttribute(LLMSemanticAttributes.LLM_STREAMING_CHUNK_COUNT, chunkCount);
    if (ttft !== undefined) {
      span.setAttribute(LLMSemanticAttributes.LLM_LATENCY_TTFT, ttft);
    }
  }

  /**
   * End a span with success status.
   */
  endSpan(span: Span): void {
    span.setStatus({ code: SpanStatusCode.OK });
    span.end();
  }

  /**
   * Get the current active context.
   */
  getActiveContext(): Context {
    return context.active();
  }

  /**
   * Set a span as active in the current context.
   */
  withSpan<T>(span: Span, fn: () => T): T {
    return trace.getTracer('@llm-observatory/sdk').startActiveSpan(span.spanContext().spanId, (activeSpan) => {
      try {
        return fn();
      } finally {
        activeSpan.end();
      }
    });
  }

  /**
   * Extract span data for custom processing.
   */
  extractSpanData(span: Span): LLMSpanData {
    const spanContext = span.spanContext();

    return {
      traceId: spanContext.traceId,
      spanId: spanContext.spanId,
      name: '', // Name is not available from span context
      provider: Provider.OpenAI, // Default, should be set properly
      model: '',
      startTime: new Date(),
    };
  }
}

/**
 * Create a new LLM tracer instance.
 */
export function createTracer(tracerName?: string): LLMTracer {
  return new LLMTracer(tracerName);
}

/**
 * Decorator for automatic span creation (experimental).
 */
export function traced(spanName?: string) {
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor
  ): PropertyDescriptor {
    const originalMethod = descriptor.value;

    descriptor.value = async function (...args: any[]) {
      const tracer = new LLMTracer();
      const name = spanName || `${target.constructor.name}.${propertyKey}`;
      const span = tracer.tracer.startSpan(name);

      try {
        const result = await originalMethod.apply(this, args);
        span.setStatus({ code: SpanStatusCode.OK });
        return result;
      } catch (error) {
        if (error instanceof Error) {
          tracer.recordError(span, error);
        }
        throw error;
      } finally {
        span.end();
      }
    };

    return descriptor;
  };
}

/**
 * Helper to run a function within a span.
 */
export async function withSpan<T>(
  spanName: string,
  fn: (span: Span) => Promise<T>,
  options?: {
    provider?: Provider;
    model?: string;
    attributes?: Record<string, string | number | boolean>;
  }
): Promise<T> {
  const tracer = new LLMTracer();
  const span = options?.provider && options?.model
    ? tracer.startSpan(spanName, options.provider, options.model, { attributes: options.attributes })
    : trace.getTracer('@llm-observatory/sdk').startSpan(spanName, { attributes: options?.attributes });

  try {
    const result = await fn(span);
    span.setStatus({ code: SpanStatusCode.OK });
    return result;
  } catch (error) {
    if (error instanceof Error) {
      span.recordException(error);
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error.message,
      });
    }
    throw error;
  } finally {
    span.end();
  }
}
