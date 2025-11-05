import { useState } from 'react';
import DocumentList from '@/components/KnowledgeBase/DocumentList';
import DocumentUpload from '@/components/KnowledgeBase/DocumentUpload';
import { Plus, X } from 'lucide-react';

export default function KnowledgeBasePage() {
  const [showUpload, setShowUpload] = useState(false);
  const [selectedDocumentId, setSelectedDocumentId] = useState<string | null>(null);

  return (
    <div className="flex h-full">
      <div className="flex-1">
        <DocumentList
          onSelectDocument={setSelectedDocumentId}
          onEditDocument={setSelectedDocumentId}
        />
      </div>

      {/* Upload Panel */}
      {showUpload ? (
        <div className="w-96 border-l border-gray-200 bg-gray-50 p-6">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-lg font-semibold text-gray-900">Add Document</h2>
            <button
              onClick={() => setShowUpload(false)}
              className="rounded p-1 text-gray-400 transition-colors hover:bg-gray-200 hover:text-gray-600"
            >
              <X className="h-5 w-5" />
            </button>
          </div>
          <DocumentUpload onUploadComplete={() => setShowUpload(false)} />
        </div>
      ) : (
        <div className="border-l border-gray-200 bg-white p-6">
          <button
            onClick={() => setShowUpload(true)}
            className="flex w-full items-center justify-center gap-2 rounded-lg bg-primary-600 px-4 py-3 text-sm font-medium text-white transition-colors hover:bg-primary-700"
          >
            <Plus className="h-5 w-5" />
            Add Document
          </button>
        </div>
      )}
    </div>
  );
}
