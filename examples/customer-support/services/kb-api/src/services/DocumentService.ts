import { v4 as uuidv4 } from 'uuid';
import pdf from 'pdf-parse';
import mammoth from 'mammoth';
import { marked } from 'marked';
import {
  Document,
  DocumentChunk,
  DocumentMetadata,
  UploadDocumentResponse,
  ListDocumentsQuery,
  ListDocumentsResponse,
  DocumentSummary,
} from '../types';
import { TextChunker, ChunkResult } from '../utils/textChunker';
import { EmbeddingService } from './EmbeddingService';
import { QdrantService } from './QdrantService';
import logger from '../utils/logger';
import { NotFoundError, InternalServerError, BadRequestError } from '../middleware/errorHandler';
import { config } from '../config';

export class DocumentService {
  private embeddingService: EmbeddingService;
  private qdrantService: QdrantService;
  private textChunker: TextChunker;

  // In-memory storage (replace with database in production)
  private documents: Map<string, Document> = new Map();

  constructor(embeddingService: EmbeddingService, qdrantService: QdrantService) {
    this.embeddingService = embeddingService;
    this.qdrantService = qdrantService;
    this.textChunker = new TextChunker();
  }

  async processDocument(
    file: Express.Multer.File,
    metadata: Partial<DocumentMetadata>
  ): Promise<UploadDocumentResponse> {
    const documentId = uuidv4();

    try {
      logger.info(`Processing document: ${file.originalname}`, { documentId });

      // Extract text from file
      const content = await this.extractText(file);

      if (!content || content.trim().length === 0) {
        throw new BadRequestError('Document contains no extractable text');
      }

      // Create document metadata
      const documentMetadata: DocumentMetadata = {
        filename: file.originalname,
        mimeType: file.mimetype,
        size: file.size,
        source: metadata.source,
        author: metadata.author,
        category: metadata.category,
        tags: metadata.tags,
        customFields: metadata.customFields,
      };

      // Chunk the document
      const chunkResults = this.textChunker.chunkByParagraphs(content);
      logger.info(`Created ${chunkResults.length} chunks from document`, { documentId });

      // Generate embeddings for chunks
      const chunkTexts = chunkResults.map((chunk) => chunk.content);
      const embeddingResult = await this.embeddingService.batchEmbeddings(chunkTexts);

      // Create document chunks
      const chunks: DocumentChunk[] = chunkResults.map((chunk, index) => ({
        id: `${documentId}_chunk_${index}`,
        documentId,
        content: chunk.content,
        chunkIndex: index,
        embedding: embeddingResult.embeddings[index],
        metadata: {
          startPosition: chunk.startPosition,
          endPosition: chunk.endPosition,
          tokenCount: chunk.tokenCount,
        },
      }));

      // Store in Qdrant
      await this.storeChunksInQdrant(chunks, documentMetadata);

      // Create document
      const document: Document = {
        id: documentId,
        title: metadata.source || file.originalname,
        content,
        metadata: documentMetadata,
        chunks,
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      // Store document (in-memory for now)
      this.documents.set(documentId, document);

      logger.info(`Document processed successfully`, {
        documentId,
        chunksCreated: chunks.length,
        tokensUsed: embeddingResult.tokensUsed,
      });

      return {
        id: documentId,
        title: document.title,
        filename: file.originalname,
        size: file.size,
        chunksCreated: chunks.length,
        status: 'completed',
      };
    } catch (error) {
      logger.error('Failed to process document', { documentId, error });

      // Cleanup on failure
      try {
        await this.qdrantService.deleteByDocumentId(documentId);
        this.documents.delete(documentId);
      } catch (cleanupError) {
        logger.error('Failed to cleanup after error', { documentId, cleanupError });
      }

      if (error instanceof BadRequestError) {
        throw error;
      }

      throw new InternalServerError('Failed to process document');
    }
  }

  private async extractText(file: Express.Multer.File): Promise<string> {
    const mimeType = file.mimetype;

    try {
      switch (mimeType) {
        case 'application/pdf':
          return await this.extractPdfText(file.buffer);

        case 'text/plain':
        case 'text/markdown':
          return file.buffer.toString('utf-8');

        case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
          return await this.extractDocxText(file.buffer);

        default:
          throw new BadRequestError(`Unsupported file type: ${mimeType}`);
      }
    } catch (error) {
      logger.error('Failed to extract text from document', { mimeType, error });
      throw new BadRequestError('Failed to extract text from document');
    }
  }

  private async extractPdfText(buffer: Buffer): Promise<string> {
    const data = await pdf(buffer);
    return data.text;
  }

  private async extractDocxText(buffer: Buffer): Promise<string> {
    const result = await mammoth.extractRawText({ buffer });
    return result.value;
  }

  private async storeChunksInQdrant(
    chunks: DocumentChunk[],
    documentMetadata: DocumentMetadata
  ): Promise<void> {
    const points = chunks.map((chunk) => ({
      id: chunk.id,
      vector: chunk.embedding || [],
      payload: {
        documentId: chunk.documentId,
        content: chunk.content,
        chunkIndex: chunk.chunkIndex,
        documentTitle: documentMetadata.filename,
        filename: documentMetadata.filename,
        category: documentMetadata.category,
        tags: documentMetadata.tags || [],
        source: documentMetadata.source,
        author: documentMetadata.author,
        createdAt: new Date().toISOString(),
        ...chunk.metadata,
      },
    }));

    await this.qdrantService.upsertPoints(points);
  }

  async getDocument(documentId: string): Promise<Document> {
    const document = this.documents.get(documentId);

    if (!document) {
      throw new NotFoundError('Document', documentId);
    }

    return document;
  }

  async listDocuments(query: ListDocumentsQuery): Promise<ListDocumentsResponse> {
    const page = query.page || 1;
    const limit = query.limit || 20;
    const sortBy = query.sortBy || 'createdAt';
    const sortOrder = query.sortOrder || 'desc';

    let documents = Array.from(this.documents.values());

    // Filter by category
    if (query.category) {
      documents = documents.filter((doc) => doc.metadata.category === query.category);
    }

    // Filter by tags
    if (query.tags && query.tags.length > 0) {
      documents = documents.filter(
        (doc) =>
          doc.metadata.tags?.some((tag) => query.tags?.includes(tag))
      );
    }

    // Search by title or filename
    if (query.search) {
      const searchLower = query.search.toLowerCase();
      documents = documents.filter(
        (doc) =>
          doc.title.toLowerCase().includes(searchLower) ||
          doc.metadata.filename.toLowerCase().includes(searchLower)
      );
    }

    // Sort
    documents.sort((a, b) => {
      let aVal: string | Date = a[sortBy] as string | Date;
      let bVal: string | Date = b[sortBy] as string | Date;

      if (aVal instanceof Date && bVal instanceof Date) {
        return sortOrder === 'asc'
          ? aVal.getTime() - bVal.getTime()
          : bVal.getTime() - aVal.getTime();
      }

      if (typeof aVal === 'string' && typeof bVal === 'string') {
        return sortOrder === 'asc'
          ? aVal.localeCompare(bVal)
          : bVal.localeCompare(aVal);
      }

      return 0;
    });

    // Paginate
    const total = documents.length;
    const totalPages = Math.ceil(total / limit);
    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + limit;
    const paginatedDocuments = documents.slice(startIndex, endIndex);

    // Convert to summaries
    const documentSummaries: DocumentSummary[] = paginatedDocuments.map((doc) => ({
      id: doc.id,
      title: doc.title,
      filename: doc.metadata.filename,
      size: doc.metadata.size,
      chunksCount: doc.chunks.length,
      category: doc.metadata.category,
      tags: doc.metadata.tags,
      createdAt: doc.createdAt.toISOString(),
      updatedAt: doc.updatedAt.toISOString(),
    }));

    return {
      documents: documentSummaries,
      total,
      page,
      limit,
      totalPages,
    };
  }

  async deleteDocument(documentId: string): Promise<void> {
    const document = this.documents.get(documentId);

    if (!document) {
      throw new NotFoundError('Document', documentId);
    }

    // Delete from Qdrant
    await this.qdrantService.deleteByDocumentId(documentId);

    // Delete from in-memory storage
    this.documents.delete(documentId);

    logger.info(`Document deleted successfully`, { documentId });
  }

  async getDocumentCount(): Promise<number> {
    return this.documents.size;
  }

  async getChunksCount(): Promise<number> {
    let count = 0;
    for (const doc of this.documents.values()) {
      count += doc.chunks.length;
    }
    return count;
  }
}

export default DocumentService;
