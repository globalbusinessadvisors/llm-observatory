import { Router, Request, Response } from 'express';
import multer from 'multer';
import { DocumentService } from '../services/DocumentService';
import { asyncHandler } from '../middleware/errorHandler';
import { config } from '../config';
import { z } from 'zod';
import { BadRequestError } from '../middleware/errorHandler';

const router = Router();

// Configure multer for file uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: config.documents.maxFileSize,
  },
  fileFilter: (req, file, cb) => {
    if (config.documents.allowedMimeTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`File type ${file.mimetype} is not supported`));
    }
  },
});

// Validation schemas
const uploadMetadataSchema = z.object({
  title: z.string().optional(),
  source: z.string().optional(),
  author: z.string().optional(),
  category: z.string().optional(),
  tags: z.array(z.string()).optional(),
  metadata: z.record(z.unknown()).optional(),
});

const listDocumentsSchema = z.object({
  page: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
  category: z.string().optional(),
  tags: z.string().transform((val) => val.split(',')).optional(),
  search: z.string().optional(),
  sortBy: z.enum(['createdAt', 'updatedAt', 'title']).optional(),
  sortOrder: z.enum(['asc', 'desc']).optional(),
});

export function createDocumentsRouter(documentService: DocumentService): Router {
  // Upload document
  router.post(
    '/',
    upload.single('file'),
    asyncHandler(async (req: Request, res: Response) => {
      if (!req.file) {
        throw new BadRequestError('No file uploaded');
      }

      // Parse and validate metadata
      const metadata = uploadMetadataSchema.parse({
        title: req.body.title,
        source: req.body.source,
        author: req.body.author,
        category: req.body.category,
        tags: req.body.tags ? JSON.parse(req.body.tags) : undefined,
        metadata: req.body.metadata ? JSON.parse(req.body.metadata) : undefined,
      });

      const result = await documentService.processDocument(req.file, metadata);

      res.status(201).json({
        success: true,
        data: result,
      });
    })
  );

  // List documents
  router.get(
    '/',
    asyncHandler(async (req: Request, res: Response) => {
      const query = listDocumentsSchema.parse(req.query);
      const result = await documentService.listDocuments(query);

      res.json({
        success: true,
        data: result,
      });
    })
  );

  // Get document by ID
  router.get(
    '/:id',
    asyncHandler(async (req: Request, res: Response) => {
      const { id } = req.params;
      const document = await documentService.getDocument(id);

      res.json({
        success: true,
        data: document,
      });
    })
  );

  // Delete document
  router.delete(
    '/:id',
    asyncHandler(async (req: Request, res: Response) => {
      const { id } = req.params;
      await documentService.deleteDocument(id);

      res.json({
        success: true,
        message: 'Document deleted successfully',
      });
    })
  );

  // Get document statistics
  router.get(
    '/stats',
    asyncHandler(async (req: Request, res: Response) => {
      const documentsCount = await documentService.getDocumentCount();
      const chunksCount = await documentService.getChunksCount();

      res.json({
        success: true,
        data: {
          documents: documentsCount,
          chunks: chunksCount,
        },
      });
    })
  );

  return router;
}

export default createDocumentsRouter;
