// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

/**
 * Main LLMObservatory class for initializing and managing observability.
 */

import { NodeTracerProvider } from '@opentelemetry/sdk-trace-node';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';
import { BatchSpanProcessor, ConsoleSpanExporter } from '@opentelemetry/sdk-trace-base';
import { OTLPTraceExporter as OTLPGrpcTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';
import { OTLPTraceExporter as OTLPHttpTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-grpc';
import { MeterProvider, PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { diag, DiagConsoleLogger, DiagLogLevel } from '@opentelemetry/api';
import { ObservatoryConfig, ErrorType, ObservatoryError, MiddlewareOptions } from './types';
import { createTracer, LLMTracer } from './tracing';

/**
 * Main Observatory class for managing LLM observability.
 */
export class LLMObservatory {
  private config: Required<ObservatoryConfig>;
  private tracerProvider?: NodeTracerProvider;
  private meterProvider?: MeterProvider;
  private tracer: LLMTracer;
  private initialized = false;

  constructor(config: ObservatoryConfig) {
    // Set default configuration
    this.config = {
      serviceName: config.serviceName,
      serviceVersion: config.serviceVersion || '1.0.0',
      otlpEndpoint: config.otlpEndpoint || 'http://localhost:4317',
      useGrpc: config.useGrpc ?? true,
      enableMetrics: config.enableMetrics ?? true,
      enableTraces: config.enableTraces ?? true,
      sampleRate: config.sampleRate ?? 1.0,
      environment: config.environment || process.env.NODE_ENV || 'development',
      resourceAttributes: config.resourceAttributes || {},
      debug: config.debug ?? false,
      exportIntervalMs: config.exportIntervalMs || 5000,
      maxBatchSize: config.maxBatchSize || 512,
    };

    // Validate configuration
    this.validateConfig();

    // Create tracer instance
    this.tracer = createTracer();
  }

  /**
   * Validate configuration.
   */
  private validateConfig(): void {
    if (!this.config.serviceName) {
      throw new ObservatoryError(
        ErrorType.Configuration,
        'Service name is required',
        { config: this.config }
      );
    }

    if (this.config.sampleRate < 0 || this.config.sampleRate > 1) {
      throw new ObservatoryError(
        ErrorType.Configuration,
        'Sample rate must be between 0 and 1',
        { sampleRate: this.config.sampleRate }
      );
    }

    if (this.config.exportIntervalMs < 1000) {
      throw new ObservatoryError(
        ErrorType.Configuration,
        'Export interval must be at least 1000ms',
        { exportIntervalMs: this.config.exportIntervalMs }
      );
    }
  }

  /**
   * Initialize OpenTelemetry providers and exporters.
   */
  async init(): Promise<void> {
    if (this.initialized) {
      console.warn('LLMObservatory already initialized');
      return;
    }

    try {
      // Enable debug logging if configured
      if (this.config.debug) {
        diag.setLogger(new DiagConsoleLogger(), DiagLogLevel.DEBUG);
      }

      // Create resource
      const resource = this.createResource();

      // Initialize trace provider
      if (this.config.enableTraces) {
        await this.initializeTraceProvider(resource);
      }

      // Initialize metrics provider
      if (this.config.enableMetrics) {
        await this.initializeMetricsProvider(resource);
      }

      this.initialized = true;
      console.log(`LLM Observatory initialized for service: ${this.config.serviceName}`);
    } catch (error) {
      throw new ObservatoryError(
        ErrorType.Configuration,
        'Failed to initialize LLM Observatory',
        { error: error instanceof Error ? error.message : String(error) }
      );
    }
  }

  /**
   * Create OpenTelemetry resource with service information.
   */
  private createResource(): Resource {
    return new Resource({
      [SemanticResourceAttributes.SERVICE_NAME]: this.config.serviceName,
      [SemanticResourceAttributes.SERVICE_VERSION]: this.config.serviceVersion,
      [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: this.config.environment,
      ...this.config.resourceAttributes,
    });
  }

  /**
   * Initialize trace provider with OTLP exporter.
   */
  private async initializeTraceProvider(resource: Resource): Promise<void> {
    this.tracerProvider = new NodeTracerProvider({
      resource,
    });

    // Create appropriate exporter based on configuration
    let exporter;
    if (this.config.debug) {
      // Use console exporter for debugging
      exporter = new ConsoleSpanExporter();
    } else if (this.config.useGrpc) {
      exporter = new OTLPGrpcTraceExporter({
        url: this.config.otlpEndpoint,
      });
    } else {
      exporter = new OTLPHttpTraceExporter({
        url: this.config.otlpEndpoint,
      });
    }

    // Add batch span processor
    this.tracerProvider.addSpanProcessor(
      new BatchSpanProcessor(exporter, {
        maxQueueSize: 2048,
        maxExportBatchSize: this.config.maxBatchSize,
        scheduledDelayMillis: this.config.exportIntervalMs,
      })
    );

    // Register the tracer provider
    this.tracerProvider.register();
  }

  /**
   * Initialize metrics provider with OTLP exporter.
   */
  private async initializeMetricsProvider(resource: Resource): Promise<void> {
    const metricExporter = new OTLPMetricExporter({
      url: this.config.otlpEndpoint,
    });

    this.meterProvider = new MeterProvider({
      resource,
      readers: [
        new PeriodicExportingMetricReader({
          exporter: metricExporter,
          exportIntervalMillis: this.config.exportIntervalMs,
        }),
      ],
    });
  }

  /**
   * Get the tracer instance.
   */
  getTracer(): LLMTracer {
    return this.tracer;
  }

  /**
   * Get configuration.
   */
  getConfig(): Readonly<Required<ObservatoryConfig>> {
    return this.config;
  }

  /**
   * Check if observatory is initialized.
   */
  isInitialized(): boolean {
    return this.initialized;
  }

  /**
   * Create Express middleware for automatic request tracing.
   */
  middleware(options?: MiddlewareOptions): any {
    if (!this.initialized) {
      throw new ObservatoryError(
        ErrorType.Configuration,
        'Observatory must be initialized before creating middleware'
      );
    }

    const defaultOptions: Required<MiddlewareOptions> = {
      captureRequestBody: options?.captureRequestBody ?? false,
      captureResponseBody: options?.captureResponseBody ?? false,
      ignorePaths: options?.ignorePaths || ['/health', '/metrics', '/favicon.ico'],
      spanNameGenerator: options?.spanNameGenerator || ((req: any) => `${req.method} ${req.path}`),
    };

    return (req: any, res: any, next: any) => {
      // Check if path should be ignored
      if (defaultOptions.ignorePaths.some((path) => req.path.startsWith(path))) {
        return next();
      }

      const startTime = Date.now();
      const spanName = defaultOptions.spanNameGenerator(req);

      // Start a new span for this request
      const span = this.tracer.startSpan(
        spanName,
        'openai' as any, // Placeholder
        req.path,
        {
          attributes: {
            'http.method': req.method,
            'http.url': req.url,
            'http.target': req.path,
            'http.host': req.hostname,
            'http.scheme': req.protocol,
            'http.user_agent': req.get('user-agent') || '',
          },
        }
      );

      // Capture request body if enabled
      if (defaultOptions.captureRequestBody && req.body) {
        span.setAttribute('http.request.body', JSON.stringify(req.body));
      }

      // Hook into response finish event
      const originalEnd = res.end;
      res.end = function (...args: any[]) {
        const duration = Date.now() - startTime;

        // Record response attributes
        span.setAttribute('http.status_code', res.statusCode);
        span.setAttribute('http.response.duration_ms', duration);

        // Capture response body if enabled
        if (defaultOptions.captureResponseBody && args[0]) {
          span.setAttribute('http.response.body', String(args[0]).substring(0, 1000));
        }

        // End the span
        span.end();

        // Call original end
        return originalEnd.apply(res, args);
      };

      next();
    };
  }

  /**
   * Flush and shutdown all providers.
   */
  async shutdown(): Promise<void> {
    if (!this.initialized) {
      return;
    }

    try {
      // Shutdown trace provider
      if (this.tracerProvider) {
        await this.tracerProvider.shutdown();
      }

      // Shutdown metrics provider
      if (this.meterProvider) {
        await this.meterProvider.shutdown();
      }

      this.initialized = false;
      console.log('LLM Observatory shutdown complete');
    } catch (error) {
      throw new ObservatoryError(
        ErrorType.Export,
        'Failed to shutdown LLM Observatory',
        { error: error instanceof Error ? error.message : String(error) }
      );
    }
  }

  /**
   * Force flush all pending telemetry data.
   */
  async flush(): Promise<void> {
    if (!this.initialized) {
      return;
    }

    try {
      if (this.tracerProvider) {
        await this.tracerProvider.forceFlush();
      }

      if (this.meterProvider) {
        await this.meterProvider.forceFlush();
      }
    } catch (error) {
      throw new ObservatoryError(
        ErrorType.Export,
        'Failed to flush telemetry data',
        { error: error instanceof Error ? error.message : String(error) }
      );
    }
  }
}

/**
 * Global observatory instance (singleton pattern).
 */
let globalObservatory: LLMObservatory | null = null;

/**
 * Initialize the global observatory instance.
 */
export async function initObservatory(config: ObservatoryConfig): Promise<LLMObservatory> {
  if (globalObservatory) {
    console.warn('Global observatory already initialized. Returning existing instance.');
    return globalObservatory;
  }

  globalObservatory = new LLMObservatory(config);
  await globalObservatory.init();
  return globalObservatory;
}

/**
 * Get the global observatory instance.
 */
export function getObservatory(): LLMObservatory {
  if (!globalObservatory) {
    throw new ObservatoryError(
      ErrorType.Configuration,
      'Observatory not initialized. Call initObservatory() first.'
    );
  }
  return globalObservatory;
}

/**
 * Shutdown the global observatory instance.
 */
export async function shutdownObservatory(): Promise<void> {
  if (globalObservatory) {
    await globalObservatory.shutdown();
    globalObservatory = null;
  }
}
