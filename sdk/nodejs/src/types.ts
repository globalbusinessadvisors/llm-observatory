// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

/**
 * Core type definitions for LLM Observatory SDK.
 */

import { Context } from '@opentelemetry/api';

/**
 * LLM provider identifiers.
 */
export enum Provider {
  OpenAI = 'openai',
  Anthropic = 'anthropic',
  Google = 'google',
  Mistral = 'mistral',
  Cohere = 'cohere',
  SelfHosted = 'self-hosted',
}

/**
 * Token usage statistics for an LLM call.
 */
export interface TokenUsage {
  /** Number of tokens in the prompt */
  promptTokens: number;
  /** Number of tokens in the completion */
  completionTokens: number;
  /** Total tokens (prompt + completion) */
  totalTokens: number;
}

/**
 * Cost information for an LLM call.
 */
export interface Cost {
  /** Total cost in USD */
  amountUsd: number;
  /** Currency (default: USD) */
  currency: string;
  /** Prompt cost breakdown */
  promptCost?: number;
  /** Completion cost breakdown */
  completionCost?: number;
}

/**
 * Latency metrics for an LLM call.
 */
export interface Latency {
  /** Total duration in milliseconds */
  totalMs: number;
  /** Time to first token in milliseconds */
  ttftMs?: number;
  /** Start timestamp */
  startTime: Date;
  /** End timestamp */
  endTime: Date;
}

/**
 * Metadata for an LLM request/response.
 */
export interface Metadata {
  /** User identifier */
  userId?: string;
  /** Session identifier */
  sessionId?: string;
  /** Request identifier */
  requestId?: string;
  /** Environment (production, staging, development) */
  environment?: string;
  /** Custom tags */
  tags?: string[];
  /** Custom attributes */
  attributes?: Record<string, string | number | boolean>;
}

/**
 * LLM Observatory configuration options.
 */
export interface ObservatoryConfig {
  /** Service name for telemetry */
  serviceName: string;
  /** Service version */
  serviceVersion?: string;
  /** OTLP endpoint (gRPC or HTTP) */
  otlpEndpoint?: string;
  /** Use gRPC protocol (default: true) */
  useGrpc?: boolean;
  /** Enable metrics collection (default: true) */
  enableMetrics?: boolean;
  /** Enable trace collection (default: true) */
  enableTraces?: boolean;
  /** Sample rate (0.0 to 1.0, default: 1.0) */
  sampleRate?: number;
  /** Environment name */
  environment?: string;
  /** Custom resource attributes */
  resourceAttributes?: Record<string, string | number | boolean>;
  /** Enable debug logging (default: false) */
  debug?: boolean;
  /** Export interval in milliseconds (default: 5000) */
  exportIntervalMs?: number;
  /** Maximum batch size for traces (default: 512) */
  maxBatchSize?: number;
}

/**
 * Options for instrumenting OpenAI client.
 */
export interface InstrumentOpenAIOptions {
  /** Enable cost calculation (default: true) */
  enableCost?: boolean;
  /** Enable streaming support (default: true) */
  enableStreaming?: boolean;
  /** Enable request/response logging (default: false) */
  logPayloads?: boolean;
  /** Custom metadata to attach to all spans */
  metadata?: Metadata;
  /** Custom span processor */
  spanProcessor?: (span: LLMSpanData) => void;
}

/**
 * LLM span data captured during instrumentation.
 */
export interface LLMSpanData {
  /** Trace ID */
  traceId: string;
  /** Span ID */
  spanId: string;
  /** Parent span ID */
  parentSpanId?: string;
  /** Operation name */
  name: string;
  /** Provider */
  provider: Provider;
  /** Model name */
  model: string;
  /** Token usage */
  tokenUsage?: TokenUsage;
  /** Cost information */
  cost?: Cost;
  /** Latency metrics */
  latency?: Latency;
  /** Metadata */
  metadata?: Metadata;
  /** Request parameters */
  requestParams?: Record<string, unknown>;
  /** Response data */
  responseData?: Record<string, unknown>;
  /** Error information */
  error?: {
    message: string;
    type: string;
    stack?: string;
  };
  /** Start time */
  startTime: Date;
  /** End time */
  endTime?: Date;
  /** Status code */
  statusCode?: number;
  /** OpenTelemetry context */
  context?: Context;
}

/**
 * Streaming event types.
 */
export enum StreamingEvent {
  Start = 'stream.start',
  Chunk = 'stream.chunk',
  End = 'stream.end',
  Error = 'stream.error',
}

/**
 * Streaming chunk data.
 */
export interface StreamingChunk {
  /** Chunk content */
  content: string;
  /** Chunk index */
  index: number;
  /** Timestamp */
  timestamp: Date;
  /** Time since first token (ms) */
  timeSinceStart?: number;
}

/**
 * Express middleware options.
 */
export interface MiddlewareOptions {
  /** Capture request body (default: false) */
  captureRequestBody?: boolean;
  /** Capture response body (default: false) */
  captureResponseBody?: boolean;
  /** Ignored paths (won't create spans) */
  ignorePaths?: string[];
  /** Custom span name generator */
  spanNameGenerator?: (req: any) => string;
}

/**
 * Pricing information for a model.
 */
export interface Pricing {
  /** Model identifier */
  model: string;
  /** Cost per 1K prompt tokens in USD */
  promptCostPer1k: number;
  /** Cost per 1K completion tokens in USD */
  completionCostPer1k: number;
}

/**
 * Sampling decision.
 */
export interface SamplingDecision {
  /** Whether to sample this trace */
  shouldSample: boolean;
  /** Reason for decision */
  reason?: string;
  /** Priority level */
  priority?: number;
}

/**
 * Error types in LLM Observatory.
 */
export enum ErrorType {
  Configuration = 'CONFIGURATION_ERROR',
  Instrumentation = 'INSTRUMENTATION_ERROR',
  Export = 'EXPORT_ERROR',
  PricingNotFound = 'PRICING_NOT_FOUND',
  InvalidModel = 'INVALID_MODEL',
  NetworkError = 'NETWORK_ERROR',
  Timeout = 'TIMEOUT',
  RateLimited = 'RATE_LIMITED',
  AuthenticationError = 'AUTHENTICATION_ERROR',
  Unknown = 'UNKNOWN_ERROR',
}

/**
 * Observatory error class.
 */
export class ObservatoryError extends Error {
  public readonly type: ErrorType;
  public readonly details?: Record<string, unknown>;

  constructor(type: ErrorType, message: string, details?: Record<string, unknown>) {
    super(message);
    this.name = 'ObservatoryError';
    this.type = type;
    this.details = details;
    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * Model capabilities and metadata.
 */
export interface ModelInfo {
  /** Model identifier */
  model: string;
  /** Provider */
  provider: Provider;
  /** Maximum context length */
  maxContextLength?: number;
  /** Supports streaming */
  supportsStreaming?: boolean;
  /** Supports function calling */
  supportsFunctions?: boolean;
  /** Supports vision */
  supportsVision?: boolean;
  /** Training data cutoff */
  trainingDataCutoff?: string;
}
