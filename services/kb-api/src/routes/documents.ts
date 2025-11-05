import { Router, Request, Response } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs/promises';
import { v4 as uuidv4 } from 'uuid';
import pdfParse from 'pdf-parse';
import { appConfig } from '../config';
import { getQdrantService } from '../services/qdrant';
import { getChunkingService } from '../services/chunking';
import { asyncHandler } from '../middleware/errorHandler';
import logger from '../utils/logger';
import {
  Document,
  DocumentUploadSchema,
  DocumentProcessingError,
  VectorPoint,
} from '../types';
import { trackLLMOperation } from '../middleware/observatory';

const router = Router();
const qdrantService = getQdrantService();
const chunkingService = getChunkingService();

// In-memory document store (in production, use a database)
const documents = new Map<string, Document>();

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    try {
      await fs.mkdir(appConfig.uploadDir, { recursive: true });
      cb(null, appConfig.uploadDir);
    } catch (error) {
      cb(error as Error, appConfig.uploadDir);
    }
  },
  filename: (req, file, cb) => {
    const uniqueName = `${uuidv4()}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: appConfig.maxFileSize,
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = [
      'application/pdf',
      'text/plain',
      'text/markdown',
      'application/json',
    ];

    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`File type not supported: ${file.mimetype}`));
    }
  },
});

/**
 * POST /api/v1/kb/documents
 * Upload and process a document
 */
router.post(
  '/',
  upload.single('file'),
  asyncHandler(async (req: Request, res: Response) => {
    const startTime = Date.now();

    if (!req.file) {
      return res.status(400).json({
        error: {
          message: 'No file uploaded',
          code: 'NO_FILE',
        },
      });
    }

    // Parse and validate request body
    const uploadData = DocumentUploadSchema.parse(
      req.body.metadata ? { ...req.body, metadata: JSON.parse(req.body.metadata) } : req.body,
    );

    const documentId = uuidv4();

    logger.info('Processing document upload', {
      documentId,
      filename: req.file.originalname,
      size: req.file.size,
      mimeType: req.file.mimetype,
    });

    try {
      // Extract text from file
      const content = await extractTextFromFile(req.file.path, req.file.mimetype);

      // Create document record
      const document: Document = {
        id: documentId,
        filename: req.file.originalname,
        content,
        metadata: uploadData.metadata || {},
        size: req.file.size,
        mimeType: req.file.mimetype,
        uploadedAt: new Date(),
        status: 'processing',
      };

      documents.set(documentId, document);

      trackLLMOperation('document', {
        documentId,
        filename: document.filename,
        size: document.size,
      });

      // Process document asynchronously
      processDocumentAsync(documentId, content, uploadData.chunkSize, uploadData.chunkOverlap);

      const processingTime = Date.now() - startTime;

      res.status(202).json({
        id: documentId,
        filename: document.filename,
        size: document.size,
        mimeType: document.mimeType,
        status: 'processing',
        uploadedAt: document.uploadedAt,
        processingTimeMs: processingTime,
      });
    } catch (error) {
      // Update document status
      const document = documents.get(documentId);
      if (document) {
        document.status = 'failed';
        document.error = error instanceof Error ? error.message : String(error);
      }

      logger.error('Document upload failed', {
        documentId,
        error: error instanceof Error ? error.message : String(error),
      });

      throw new DocumentProcessingError(
        'Failed to process document',
        error instanceof Error ? error : undefined,
      );
    }
  }),
);

/**
 * GET /api/v1/kb/documents
 * List all documents
 */
router.get(
  '/',
  asyncHandler(async (req: Request, res: Response) => {
    const limit = parseInt(req.query.limit as string) || 10;
    const offset = parseInt(req.query.offset as string) || 0;
    const status = req.query.status as Document['status'] | undefined;

    let allDocuments = Array.from(documents.values());

    // Filter by status
    if (status) {
      allDocuments = allDocuments.filter((doc) => doc.status === status);
    }

    // Sort by upload date (newest first)
    allDocuments.sort((a, b) => b.uploadedAt.getTime() - a.uploadedAt.getTime());

    const total = allDocuments.length;
    const paginatedDocuments = allDocuments.slice(offset, offset + limit);

    res.json({
      documents: paginatedDocuments.map((doc) => ({
        id: doc.id,
        filename: doc.filename,
        size: doc.size,
        mimeType: doc.mimeType,
        status: doc.status,
        uploadedAt: doc.uploadedAt,
        processedAt: doc.processedAt,
        metadata: doc.metadata,
        error: doc.error,
      })),
      total,
      limit,
      offset,
    });
  }),
);

/**
 * GET /api/v1/kb/documents/:id
 * Get document by ID
 */
router.get(
  '/:id',
  asyncHandler(async (req: Request, res: Response) => {
    const documentId = req.params.id;
    const document = documents.get(documentId);

    if (!document) {
      return res.status(404).json({
        error: {
          message: `Document not found: ${documentId}`,
          code: 'DOCUMENT_NOT_FOUND',
        },
      });
    }

    const includeContent = req.query.includeContent === 'true';

    res.json({
      id: document.id,
      filename: document.filename,
      content: includeContent ? document.content : undefined,
      size: document.size,
      mimeType: document.mimeType,
      status: document.status,
      uploadedAt: document.uploadedAt,
      processedAt: document.processedAt,
      metadata: document.metadata,
      error: document.error,
    });
  }),
);

/**
 * DELETE /api/v1/kb/documents/:id
 * Delete document and its embeddings
 */
router.delete(
  '/:id',
  asyncHandler(async (req: Request, res: Response) => {
    const documentId = req.params.id;
    const document = documents.get(documentId);

    if (!document) {
      return res.status(404).json({
        error: {
          message: `Document not found: ${documentId}`,
          code: 'DOCUMENT_NOT_FOUND',
        },
      });
    }

    logger.info('Deleting document', { documentId });

    // Delete vectors from Qdrant
    try {
      await qdrantService.deleteByDocumentId(documentId);
    } catch (error) {
      logger.error('Failed to delete vectors', {
        documentId,
        error: error instanceof Error ? error.message : String(error),
      });
      // Continue with document deletion even if vector deletion fails
    }

    // Delete document record
    documents.delete(documentId);

    logger.info('Document deleted successfully', { documentId });

    res.json({
      message: 'Document deleted successfully',
      documentId,
    });
  }),
);

/**
 * Extract text from uploaded file
 */
async function extractTextFromFile(filePath: string, mimeType: string): Promise<string> {
  try {
    if (mimeType === 'application/pdf') {
      const dataBuffer = await fs.readFile(filePath);
      const pdfData = await pdfParse(dataBuffer);
      return pdfData.text;
    } else {
      // Text-based files
      return await fs.readFile(filePath, 'utf-8');
    }
  } catch (error) {
    logger.error('Failed to extract text from file', {
      filePath,
      mimeType,
      error: error instanceof Error ? error.message : String(error),
    });
    throw new DocumentProcessingError(
      'Failed to extract text from file',
      error instanceof Error ? error : undefined,
    );
  }
}

/**
 * Process document asynchronously (chunk and embed)
 */
async function processDocumentAsync(
  documentId: string,
  content: string,
  chunkSize: number,
  chunkOverlap: number,
): Promise<void> {
  try {
    logger.info('Starting document processing', { documentId, chunkSize, chunkOverlap });

    // Chunk text with embeddings
    const chunks = await chunkingService.chunkTextWithEmbeddings(content, documentId, {
      chunkSize,
      chunkOverlap,
    });

    trackLLMOperation('chunk', {
      documentId,
      chunksCount: chunks.length,
      avgTokens: Math.round(chunks.reduce((sum, c) => sum + c.tokens, 0) / chunks.length),
    });

    // Prepare vector points
    const points: VectorPoint[] = chunks.map((chunk) => ({
      id: chunk.id,
      vector: chunk.embedding!,
      payload: {
        documentId: chunk.documentId,
        chunkIndex: chunk.chunkIndex,
        content: chunk.content,
        metadata: {
          tokens: chunk.tokens,
          startChar: chunk.startChar,
          endChar: chunk.endChar,
          ...chunk.metadata,
        },
      },
    }));

    // Upsert to Qdrant
    await qdrantService.upsertPoints(points);

    // Update document status
    const document = documents.get(documentId);
    if (document) {
      document.status = 'completed';
      document.processedAt = new Date();
    }

    logger.info('Document processing completed', {
      documentId,
      chunksCount: chunks.length,
    });
  } catch (error) {
    logger.error('Document processing failed', {
      documentId,
      error: error instanceof Error ? error.message : String(error),
    });

    // Update document status
    const document = documents.get(documentId);
    if (document) {
      document.status = 'failed';
      document.error = error instanceof Error ? error.message : String(error);
    }
  }
}

export default router;
