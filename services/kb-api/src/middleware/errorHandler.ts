import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import logger from '../utils/logger';
import {
  DocumentNotFoundError,
  VectorStoreError,
  EmbeddingError,
  ChunkingError,
  DocumentProcessingError,
} from '../types';

export interface ErrorResponse {
  error: {
    message: string;
    code: string;
    details?: any;
    timestamp: string;
    path: string;
    method: string;
  };
}

/**
 * Global error handler middleware
 */
export function errorHandler(
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  // Log error
  logger.error('Request error', {
    error: error.message,
    stack: error.stack,
    path: req.path,
    method: req.method,
    body: req.body,
  });

  const errorResponse: ErrorResponse = {
    error: {
      message: error.message || 'Internal server error',
      code: 'INTERNAL_ERROR',
      timestamp: new Date().toISOString(),
      path: req.path,
      method: req.method,
    },
  };

  // Handle specific error types
  if (error instanceof ZodError) {
    errorResponse.error.message = 'Validation error';
    errorResponse.error.code = 'VALIDATION_ERROR';
    errorResponse.error.details = error.errors.map((e) => ({
      path: e.path.join('.'),
      message: e.message,
    }));
    return res.status(400).json(errorResponse);
  }

  if (error instanceof DocumentNotFoundError) {
    errorResponse.error.code = 'DOCUMENT_NOT_FOUND';
    return res.status(404).json(errorResponse);
  }

  if (error instanceof VectorStoreError) {
    errorResponse.error.code = 'VECTOR_STORE_ERROR';
    return res.status(503).json(errorResponse);
  }

  if (error instanceof EmbeddingError) {
    errorResponse.error.code = 'EMBEDDING_ERROR';
    return res.status(503).json(errorResponse);
  }

  if (error instanceof ChunkingError) {
    errorResponse.error.code = 'CHUNKING_ERROR';
    return res.status(500).json(errorResponse);
  }

  if (error instanceof DocumentProcessingError) {
    errorResponse.error.code = 'DOCUMENT_PROCESSING_ERROR';
    return res.status(500).json(errorResponse);
  }

  // Handle multer file upload errors
  if ((error as any).code === 'LIMIT_FILE_SIZE') {
    errorResponse.error.message = 'File size exceeds maximum limit';
    errorResponse.error.code = 'FILE_TOO_LARGE';
    return res.status(413).json(errorResponse);
  }

  if ((error as any).code === 'LIMIT_UNEXPECTED_FILE') {
    errorResponse.error.message = 'Unexpected file field';
    errorResponse.error.code = 'INVALID_FILE_FIELD';
    return res.status(400).json(errorResponse);
  }

  // Default error response
  res.status(500).json(errorResponse);
}

/**
 * 404 Not Found handler
 */
export function notFoundHandler(req: Request, res: Response): void {
  const errorResponse: ErrorResponse = {
    error: {
      message: `Route not found: ${req.method} ${req.path}`,
      code: 'ROUTE_NOT_FOUND',
      timestamp: new Date().toISOString(),
      path: req.path,
      method: req.method,
    },
  };

  logger.warn('Route not found', {
    path: req.path,
    method: req.method,
  });

  res.status(404).json(errorResponse);
}

/**
 * Async route handler wrapper to catch errors
 */
export function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<any>,
) {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}
