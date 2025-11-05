import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';
import { Request, Response, NextFunction } from 'express';
import { trace, context, SpanStatusCode, Span } from '@opentelemetry/api';
import { observatoryConfig } from '../config';
import logger from '../utils/logger';

let sdk: NodeSDK | null = null;

/**
 * Initialize OpenTelemetry SDK for Observatory integration
 */
export function initializeObservatory(): NodeSDK | null {
  if (!observatoryConfig.enabled) {
    logger.info('Observatory integration is disabled');
    return null;
  }

  try {
    logger.info('Initializing Observatory integration', {
      serviceName: observatoryConfig.serviceName,
      collectorUrl: observatoryConfig.collectorUrl,
    });

    const resource = new Resource({
      [SemanticResourceAttributes.SERVICE_NAME]: observatoryConfig.serviceName,
      [SemanticResourceAttributes.SERVICE_VERSION]: observatoryConfig.serviceVersion,
      [SemanticResourceAttributes.SERVICE_NAMESPACE]: 'llm-observatory',
      'service.type': 'kb-api',
    });

    // Configure trace exporter
    const traceExporter = new OTLPTraceExporter({
      url: `${observatoryConfig.collectorUrl}/v1/traces`,
      headers: {},
    });

    // Configure metrics exporter
    const metricExporter = new OTLPMetricExporter({
      url: `${observatoryConfig.collectorUrl}/v1/metrics`,
      headers: {},
    });

    // Initialize SDK with auto-instrumentations
    sdk = new NodeSDK({
      resource,
      traceExporter,
      metricReader: new PeriodicExportingMetricReader({
        exporter: metricExporter,
        exportIntervalMillis: 60000, // Export every 60 seconds
      }),
      instrumentations: [
        getNodeAutoInstrumentations({
          // Customize auto-instrumentation
          '@opentelemetry/instrumentation-fs': { enabled: false },
          '@opentelemetry/instrumentation-http': {
            ignoreIncomingPaths: ['/health', '/metrics'],
          },
          '@opentelemetry/instrumentation-express': { enabled: true },
        }),
      ],
    });

    sdk.start();

    logger.info('Observatory integration initialized successfully');

    // Graceful shutdown
    process.on('SIGTERM', () => {
      sdk
        ?.shutdown()
        .then(() => logger.info('Observatory SDK shut down successfully'))
        .catch((error) => logger.error('Error shutting down Observatory SDK', { error }));
    });

    return sdk;
  } catch (error) {
    logger.error('Failed to initialize Observatory integration', {
      error: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
}

/**
 * Express middleware for request tracing
 */
export function observatoryMiddleware(req: Request, res: Response, next: NextFunction): void {
  if (!observatoryConfig.enabled) {
    return next();
  }

  const tracer = trace.getTracer('kb-api-http');
  const span = tracer.startSpan(`${req.method} ${req.path}`, {
    attributes: {
      'http.method': req.method,
      'http.url': req.url,
      'http.target': req.path,
      'http.host': req.get('host') || '',
      'http.scheme': req.protocol,
      'http.user_agent': req.get('user-agent') || '',
      'http.request_content_length': req.get('content-length') || 0,
    },
  });

  // Store span in request for access in route handlers
  (req as any).span = span;

  // Record response details
  const originalSend = res.send;
  res.send = function (data): Response {
    span.setAttribute('http.status_code', res.statusCode);
    span.setAttribute('http.response_content_length', data ? data.length : 0);

    if (res.statusCode >= 400) {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: `HTTP ${res.statusCode}`,
      });
    } else {
      span.setStatus({ code: SpanStatusCode.OK });
    }

    span.end();
    return originalSend.call(this, data);
  };

  // Handle errors
  res.on('error', (error: Error) => {
    span.recordException(error);
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message,
    });
    span.end();
  });

  next();
}

/**
 * Middleware to add custom attributes to the current span
 */
export function addSpanAttributes(attributes: Record<string, string | number | boolean>): void {
  const span = trace.getActiveSpan();
  if (span) {
    Object.entries(attributes).forEach(([key, value]) => {
      span.setAttribute(key, value);
    });
  }
}

/**
 * Middleware to record custom events
 */
export function recordSpanEvent(name: string, attributes?: Record<string, any>): void {
  const span = trace.getActiveSpan();
  if (span) {
    span.addEvent(name, attributes);
  }
}

/**
 * Create a child span for async operations
 */
export async function withSpan<T>(
  name: string,
  operation: (span: Span) => Promise<T>,
  attributes?: Record<string, string | number | boolean>,
): Promise<T> {
  const tracer = trace.getTracer('kb-api');
  return tracer.startActiveSpan(name, { attributes }, async (span) => {
    try {
      const result = await operation(span);
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (error) {
      span.recordException(error as Error);
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error instanceof Error ? error.message : String(error),
      });
      throw error;
    } finally {
      span.end();
    }
  });
}

/**
 * Middleware for tracking LLM-specific operations
 */
export function trackLLMOperation(
  operationType: 'embedding' | 'search' | 'chunk' | 'document',
  metadata: Record<string, any>,
): void {
  const span = trace.getActiveSpan();
  if (span) {
    span.setAttribute('llm.operation_type', operationType);

    // Add operation-specific attributes
    switch (operationType) {
      case 'embedding':
        if (metadata.model) span.setAttribute('llm.embedding.model', metadata.model);
        if (metadata.tokens) span.setAttribute('llm.embedding.tokens', metadata.tokens);
        if (metadata.dimensions) span.setAttribute('llm.embedding.dimensions', metadata.dimensions);
        break;

      case 'search':
        if (metadata.query) span.setAttribute('llm.search.query', metadata.query);
        if (metadata.resultsCount) span.setAttribute('llm.search.results_count', metadata.resultsCount);
        if (metadata.searchType) span.setAttribute('llm.search.type', metadata.searchType);
        break;

      case 'chunk':
        if (metadata.documentId) span.setAttribute('llm.chunk.document_id', metadata.documentId);
        if (metadata.chunksCount) span.setAttribute('llm.chunk.count', metadata.chunksCount);
        if (metadata.avgTokens) span.setAttribute('llm.chunk.avg_tokens', metadata.avgTokens);
        break;

      case 'document':
        if (metadata.documentId) span.setAttribute('llm.document.id', metadata.documentId);
        if (metadata.filename) span.setAttribute('llm.document.filename', metadata.filename);
        if (metadata.size) span.setAttribute('llm.document.size', metadata.size);
        break;
    }

    // Record event
    span.addEvent(`llm.${operationType}.completed`, metadata);
  }
}

/**
 * Get the current SDK instance
 */
export function getObservatorySDK(): NodeSDK | null {
  return sdk;
}

/**
 * Shutdown Observatory integration
 */
export async function shutdownObservatory(): Promise<void> {
  if (sdk) {
    try {
      await sdk.shutdown();
      logger.info('Observatory integration shut down successfully');
    } catch (error) {
      logger.error('Error shutting down Observatory integration', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
}
