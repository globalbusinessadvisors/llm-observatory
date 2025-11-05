import { create } from 'zustand';
import { devtools } from 'zustand/middleware';
import { KnowledgeBaseDocument } from '@/types';
import { knowledgeBaseApi } from '@/api/client';

interface KnowledgeBaseState {
  // State
  documents: KnowledgeBaseDocument[];
  currentDocument: KnowledgeBaseDocument | null;
  categories: string[];
  tags: string[];
  isLoading: boolean;
  error: string | null;

  // Filters
  selectedCategory: string | null;
  selectedTags: string[];
  searchQuery: string;

  // Actions
  fetchDocuments: () => Promise<void>;
  fetchDocument: (documentId: string) => Promise<void>;
  createDocument: (document: Partial<KnowledgeBaseDocument>) => Promise<void>;
  updateDocument: (documentId: string, updates: Partial<KnowledgeBaseDocument>) => Promise<void>;
  deleteDocument: (documentId: string) => Promise<void>;
  uploadDocument: (file: File, metadata?: Record<string, unknown>) => Promise<void>;
  searchDocuments: (query: string) => Promise<void>;

  fetchCategories: () => Promise<void>;
  fetchTags: () => Promise<void>;

  setCurrentDocument: (document: KnowledgeBaseDocument | null) => void;
  setSelectedCategory: (category: string | null) => void;
  setSelectedTags: (tags: string[]) => void;
  setSearchQuery: (query: string) => void;

  clearError: () => void;
  reset: () => void;
}

const initialState = {
  documents: [],
  currentDocument: null,
  categories: [],
  tags: [],
  isLoading: false,
  error: null,
  selectedCategory: null,
  selectedTags: [],
  searchQuery: '',
};

export const useKnowledgeBaseStore = create<KnowledgeBaseState>()(
  devtools(
    (set, get) => ({
      ...initialState,

      fetchDocuments: async () => {
        set({ isLoading: true, error: null });
        try {
          const { selectedCategory, selectedTags } = get();
          const response = await knowledgeBaseApi.getDocuments(
            1,
            50,
            selectedCategory || undefined,
            selectedTags.length > 0 ? selectedTags : undefined
          );
          set({ documents: response.items, isLoading: false });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to fetch documents',
            isLoading: false
          });
        }
      },

      fetchDocument: async (documentId: string) => {
        set({ isLoading: true, error: null });
        try {
          const document = await knowledgeBaseApi.getDocument(documentId);
          set({ currentDocument: document, isLoading: false });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to fetch document',
            isLoading: false
          });
        }
      },

      createDocument: async (document: Partial<KnowledgeBaseDocument>) => {
        set({ isLoading: true, error: null });
        try {
          const newDocument = await knowledgeBaseApi.createDocument(document);
          set((state) => ({
            documents: [newDocument, ...state.documents],
            currentDocument: newDocument,
            isLoading: false,
          }));
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to create document',
            isLoading: false
          });
          throw error;
        }
      },

      updateDocument: async (
        documentId: string,
        updates: Partial<KnowledgeBaseDocument>
      ) => {
        set({ isLoading: true, error: null });
        try {
          const updatedDocument = await knowledgeBaseApi.updateDocument(
            documentId,
            updates
          );
          set((state) => ({
            documents: state.documents.map((doc) =>
              doc.id === documentId ? updatedDocument : doc
            ),
            currentDocument: state.currentDocument?.id === documentId
              ? updatedDocument
              : state.currentDocument,
            isLoading: false,
          }));
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to update document',
            isLoading: false
          });
          throw error;
        }
      },

      deleteDocument: async (documentId: string) => {
        set({ isLoading: true, error: null });
        try {
          await knowledgeBaseApi.deleteDocument(documentId);
          set((state) => ({
            documents: state.documents.filter((doc) => doc.id !== documentId),
            currentDocument: state.currentDocument?.id === documentId
              ? null
              : state.currentDocument,
            isLoading: false,
          }));
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to delete document',
            isLoading: false
          });
        }
      },

      uploadDocument: async (file: File, metadata?: Record<string, unknown>) => {
        set({ isLoading: true, error: null });
        try {
          const document = await knowledgeBaseApi.uploadDocument(file, metadata);
          set((state) => ({
            documents: [document, ...state.documents],
            isLoading: false,
          }));
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to upload document',
            isLoading: false
          });
          throw error;
        }
      },

      searchDocuments: async (query: string) => {
        set({ isLoading: true, error: null, searchQuery: query });
        try {
          const documents = await knowledgeBaseApi.searchDocuments(query);
          set({ documents, isLoading: false });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to search documents',
            isLoading: false
          });
        }
      },

      fetchCategories: async () => {
        try {
          const categories = await knowledgeBaseApi.getCategories();
          set({ categories });
        } catch (error) {
          console.error('Failed to fetch categories:', error);
        }
      },

      fetchTags: async () => {
        try {
          const tags = await knowledgeBaseApi.getTags();
          set({ tags });
        } catch (error) {
          console.error('Failed to fetch tags:', error);
        }
      },

      setCurrentDocument: (document: KnowledgeBaseDocument | null) => {
        set({ currentDocument: document });
      },

      setSelectedCategory: (category: string | null) => {
        set({ selectedCategory: category });
        get().fetchDocuments();
      },

      setSelectedTags: (tags: string[]) => {
        set({ selectedTags: tags });
        get().fetchDocuments();
      },

      setSearchQuery: (query: string) => {
        set({ searchQuery: query });
      },

      clearError: () => set({ error: null }),

      reset: () => set(initialState),
    }),
    { name: 'KnowledgeBaseStore' }
  )
);
