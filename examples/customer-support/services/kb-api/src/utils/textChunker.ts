import { config } from '../config';

export interface ChunkResult {
  content: string;
  startPosition: number;
  endPosition: number;
  tokenCount: number;
}

export class TextChunker {
  private chunkSize: number;
  private chunkOverlap: number;

  constructor(chunkSize?: number, chunkOverlap?: number) {
    this.chunkSize = chunkSize || config.documents.chunkSize;
    this.chunkOverlap = chunkOverlap || config.documents.chunkOverlap;
  }

  chunk(text: string): ChunkResult[] {
    // Tokenize text (simplified - split by whitespace and punctuation)
    const tokens = this.tokenize(text);

    if (tokens.length === 0) {
      return [];
    }

    const chunks: ChunkResult[] = [];
    let position = 0;

    while (position < tokens.length) {
      const chunkTokens = tokens.slice(position, position + this.chunkSize);
      const chunkText = chunkTokens.join(' ');

      // Calculate actual character positions in original text
      const startPosition = this.findPosition(text, chunkText, position > 0 ? chunks[chunks.length - 1]?.endPosition || 0 : 0);
      const endPosition = startPosition + chunkText.length;

      chunks.push({
        content: chunkText.trim(),
        startPosition,
        endPosition,
        tokenCount: chunkTokens.length,
      });

      // Move position forward, accounting for overlap
      position += this.chunkSize - this.chunkOverlap;

      // Ensure we don't create infinite loops
      if (position <= 0) position = this.chunkSize;
    }

    return chunks;
  }

  private tokenize(text: string): string[] {
    // Simple tokenization by whitespace and punctuation
    // In production, consider using a proper tokenizer like tiktoken
    return text
      .replace(/([.,!?;:])/g, ' $1 ')
      .split(/\s+/)
      .filter((token) => token.length > 0);
  }

  private findPosition(text: string, chunk: string, startFrom: number = 0): number {
    const index = text.indexOf(chunk.substring(0, Math.min(50, chunk.length)), startFrom);
    return index >= 0 ? index : startFrom;
  }

  chunkByParagraphs(text: string, maxTokensPerChunk?: number): ChunkResult[] {
    const maxTokens = maxTokensPerChunk || this.chunkSize;
    const paragraphs = text.split(/\n\s*\n/);

    const chunks: ChunkResult[] = [];
    let currentChunk = '';
    let currentTokenCount = 0;
    let startPosition = 0;

    for (const paragraph of paragraphs) {
      const paragraphTokens = this.tokenize(paragraph);
      const paragraphTokenCount = paragraphTokens.length;

      if (currentTokenCount + paragraphTokenCount > maxTokens && currentChunk.length > 0) {
        // Save current chunk
        chunks.push({
          content: currentChunk.trim(),
          startPosition,
          endPosition: startPosition + currentChunk.length,
          tokenCount: currentTokenCount,
        });

        // Start new chunk
        startPosition += currentChunk.length;
        currentChunk = paragraph + '\n\n';
        currentTokenCount = paragraphTokenCount;
      } else {
        currentChunk += paragraph + '\n\n';
        currentTokenCount += paragraphTokenCount;
      }
    }

    // Add final chunk
    if (currentChunk.length > 0) {
      chunks.push({
        content: currentChunk.trim(),
        startPosition,
        endPosition: startPosition + currentChunk.length,
        tokenCount: currentTokenCount,
      });
    }

    return chunks;
  }

  chunkBySentences(text: string, maxTokensPerChunk?: number): ChunkResult[] {
    const maxTokens = maxTokensPerChunk || this.chunkSize;

    // Split by sentence boundaries (simple approach)
    const sentences = text.match(/[^.!?]+[.!?]+/g) || [text];

    const chunks: ChunkResult[] = [];
    let currentChunk = '';
    let currentTokenCount = 0;
    let startPosition = 0;

    for (const sentence of sentences) {
      const sentenceTokens = this.tokenize(sentence);
      const sentenceTokenCount = sentenceTokens.length;

      if (currentTokenCount + sentenceTokenCount > maxTokens && currentChunk.length > 0) {
        // Save current chunk
        chunks.push({
          content: currentChunk.trim(),
          startPosition,
          endPosition: startPosition + currentChunk.length,
          tokenCount: currentTokenCount,
        });

        // Start new chunk with overlap (last sentence from previous chunk)
        const overlapSentences = this.getLastSentences(currentChunk, this.chunkOverlap);
        startPosition += currentChunk.length - overlapSentences.length;
        currentChunk = overlapSentences + ' ' + sentence;
        currentTokenCount = this.tokenize(currentChunk).length;
      } else {
        currentChunk += ' ' + sentence;
        currentTokenCount += sentenceTokenCount;
      }
    }

    // Add final chunk
    if (currentChunk.length > 0) {
      chunks.push({
        content: currentChunk.trim(),
        startPosition,
        endPosition: startPosition + currentChunk.length,
        tokenCount: currentTokenCount,
      });
    }

    return chunks;
  }

  private getLastSentences(text: string, maxTokens: number): string {
    const sentences = text.match(/[^.!?]+[.!?]+/g) || [text];
    let result = '';
    let tokenCount = 0;

    for (let i = sentences.length - 1; i >= 0; i--) {
      const sentence = sentences[i];
      if (!sentence) continue;

      const sentenceTokenCount = this.tokenize(sentence).length;
      if (tokenCount + sentenceTokenCount > maxTokens) break;

      result = sentence + result;
      tokenCount += sentenceTokenCount;
    }

    return result.trim();
  }

  estimateTokenCount(text: string): number {
    return this.tokenize(text).length;
  }
}

export default TextChunker;
