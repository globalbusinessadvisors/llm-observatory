import { useEffect, useState } from 'react';
import { useKnowledgeBaseStore } from '@/stores/knowledgeBaseStore';
import { format } from 'date-fns';
import {
  FileText,
  Search,
  Filter,
  Edit,
  Trash2,
  Eye,
  MoreVertical,
} from 'lucide-react';
import clsx from 'clsx';

interface DocumentListProps {
  onSelectDocument?: (documentId: string) => void;
  onEditDocument?: (documentId: string) => void;
}

export default function DocumentList({
  onSelectDocument,
  onEditDocument,
}: DocumentListProps) {
  const {
    documents,
    categories,
    tags,
    selectedCategory,
    selectedTags,
    searchQuery,
    fetchDocuments,
    fetchCategories,
    fetchTags,
    deleteDocument,
    setSelectedCategory,
    setSelectedTags,
    setSearchQuery,
    isLoading,
  } = useKnowledgeBaseStore();

  const [localSearch, setLocalSearch] = useState('');
  const [showFilters, setShowFilters] = useState(false);

  useEffect(() => {
    fetchDocuments();
    fetchCategories();
    fetchTags();
  }, []);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setSearchQuery(localSearch);
    if (localSearch.trim()) {
      // Trigger semantic search
    } else {
      fetchDocuments();
    }
  };

  const handleDelete = async (documentId: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (confirm('Are you sure you want to delete this document?')) {
      await deleteDocument(documentId);
    }
  };

  const filteredDocuments = documents.filter((doc) => {
    if (selectedCategory && doc.category !== selectedCategory) return false;
    if (selectedTags.length > 0) {
      return selectedTags.some((tag) => doc.tags.includes(tag));
    }
    return true;
  });

  return (
    <div className="flex h-full flex-col bg-white">
      {/* Search and Filters */}
      <div className="border-b border-gray-200 p-4">
        <form onSubmit={handleSearch} className="flex gap-2">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 h-5 w-5 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              value={localSearch}
              onChange={(e) => setLocalSearch(e.target.value)}
              placeholder="Search documents..."
              className="w-full rounded-lg border border-gray-300 py-2 pl-10 pr-4 text-sm focus:border-primary-500 focus:outline-none focus:ring-2 focus:ring-primary-500/20"
            />
          </div>
          <button
            type="button"
            onClick={() => setShowFilters(!showFilters)}
            className={clsx(
              'flex items-center gap-2 rounded-lg border px-4 py-2 text-sm font-medium transition-colors',
              showFilters
                ? 'border-primary-500 bg-primary-50 text-primary-700'
                : 'border-gray-300 bg-white text-gray-700 hover:bg-gray-50'
            )}
          >
            <Filter className="h-4 w-4" />
            Filters
          </button>
        </form>

        {/* Filter Panel */}
        {showFilters && (
          <div className="mt-4 space-y-4 rounded-lg border border-gray-200 bg-gray-50 p-4">
            {/* Category Filter */}
            <div>
              <label className="mb-2 block text-sm font-medium text-gray-700">
                Category
              </label>
              <select
                value={selectedCategory || ''}
                onChange={(e) => setSelectedCategory(e.target.value || null)}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary-500 focus:outline-none focus:ring-2 focus:ring-primary-500/20"
              >
                <option value="">All Categories</option>
                {categories.map((category) => (
                  <option key={category} value={category}>
                    {category}
                  </option>
                ))}
              </select>
            </div>

            {/* Tags Filter */}
            <div>
              <label className="mb-2 block text-sm font-medium text-gray-700">Tags</label>
              <div className="flex flex-wrap gap-2">
                {tags.map((tag) => (
                  <button
                    key={tag}
                    onClick={() => {
                      const newTags = selectedTags.includes(tag)
                        ? selectedTags.filter((t) => t !== tag)
                        : [...selectedTags, tag];
                      setSelectedTags(newTags);
                    }}
                    className={clsx(
                      'rounded-full px-3 py-1 text-xs font-medium transition-colors',
                      selectedTags.includes(tag)
                        ? 'bg-primary-600 text-white'
                        : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                    )}
                  >
                    {tag}
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Documents List */}
      <div className="flex-1 overflow-y-auto">
        {isLoading ? (
          <div className="flex h-full items-center justify-center">
            <div className="text-center">
              <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary-500 border-t-transparent"></div>
              <p className="mt-4 text-sm text-gray-500">Loading documents...</p>
            </div>
          </div>
        ) : filteredDocuments.length === 0 ? (
          <div className="flex h-full items-center justify-center p-8">
            <div className="text-center">
              <FileText className="mx-auto h-16 w-16 text-gray-300" />
              <h3 className="mt-4 text-lg font-medium text-gray-900">
                No documents found
              </h3>
              <p className="mt-2 text-sm text-gray-500">
                Try adjusting your search or filters
              </p>
            </div>
          </div>
        ) : (
          <div className="divide-y divide-gray-100">
            {filteredDocuments.map((document) => (
              <div
                key={document.id}
                className="group cursor-pointer p-4 transition-colors hover:bg-gray-50"
                onClick={() => onSelectDocument?.(document.id)}
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="flex-1 overflow-hidden">
                    <div className="flex items-center gap-2">
                      <FileText className="h-5 w-5 flex-shrink-0 text-primary-600" />
                      <h3 className="truncate font-medium text-gray-900">
                        {document.title}
                      </h3>
                    </div>

                    <p className="mt-2 line-clamp-2 text-sm text-gray-600">
                      {document.content.substring(0, 150)}...
                    </p>

                    <div className="mt-3 flex items-center gap-4 text-xs text-gray-500">
                      <span className="rounded-full bg-gray-100 px-2 py-1">
                        {document.category}
                      </span>
                      <span>{format(new Date(document.updatedAt), 'MMM d, yyyy')}</span>
                      {document.chunkCount && (
                        <span>{document.chunkCount} chunks</span>
                      )}
                      <span
                        className={clsx(
                          'rounded-full px-2 py-1',
                          document.metadata.status === 'published'
                            ? 'bg-green-100 text-green-700'
                            : document.metadata.status === 'draft'
                              ? 'bg-yellow-100 text-yellow-700'
                              : 'bg-gray-100 text-gray-700'
                        )}
                      >
                        {document.metadata.status}
                      </span>
                    </div>

                    {document.tags.length > 0 && (
                      <div className="mt-2 flex flex-wrap gap-1">
                        {document.tags.map((tag) => (
                          <span
                            key={tag}
                            className="inline-flex items-center rounded bg-blue-50 px-2 py-0.5 text-xs text-blue-700"
                          >
                            {tag}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Actions */}
                  <div className="flex items-center gap-1 opacity-0 transition-opacity group-hover:opacity-100">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        onSelectDocument?.(document.id);
                      }}
                      className="rounded p-2 text-gray-400 transition-colors hover:bg-blue-50 hover:text-blue-600"
                      title="View"
                    >
                      <Eye className="h-4 w-4" />
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        onEditDocument?.(document.id);
                      }}
                      className="rounded p-2 text-gray-400 transition-colors hover:bg-green-50 hover:text-green-600"
                      title="Edit"
                    >
                      <Edit className="h-4 w-4" />
                    </button>
                    <button
                      onClick={(e) => handleDelete(document.id, e)}
                      className="rounded p-2 text-gray-400 transition-colors hover:bg-red-50 hover:text-red-600"
                      title="Delete"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                    <button
                      className="rounded p-2 text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-600"
                      title="More"
                    >
                      <MoreVertical className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Footer */}
      <div className="border-t border-gray-200 p-4">
        <p className="text-sm text-gray-500">
          Showing {filteredDocuments.length} of {documents.length} documents
        </p>
      </div>
    </div>
  );
}
