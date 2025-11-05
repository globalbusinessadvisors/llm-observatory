# Customer Support Frontend

Modern React/TypeScript frontend for the AI Customer Support Platform with Vite, Tailwind CSS, and real-time chat capabilities.

## Features

- **Real-time Chat Interface** - WebSocket-powered chat with typing indicators and message streaming
- **Conversation Management** - Browse, search, and manage conversation history
- **Knowledge Base** - Upload, search, and manage support documentation
- **Analytics Dashboard** - Visualize metrics, costs, and performance with Recharts
- **Settings Panel** - Configure AI model parameters, RAG settings, and system options
- **Responsive Design** - Mobile-first design that works on all screen sizes
- **Type-Safe** - Full TypeScript implementation with strict typing
- **State Management** - Zustand for efficient and scalable state management

## Tech Stack

- **Framework**: React 18 with TypeScript
- **Build Tool**: Vite 5
- **Styling**: Tailwind CSS 3
- **State Management**: Zustand
- **Routing**: React Router v6
- **API Client**: Axios
- **WebSocket**: Socket.IO Client
- **Charts**: Recharts
- **Icons**: Lucide React
- **Date Handling**: date-fns

## Quick Start

### Prerequisites

- Node.js >= 20.0.0
- npm >= 10.0.0

### Installation

```bash
# Install dependencies
npm install

# Copy environment variables
cp .env.example .env.local

# Update .env.local with your API endpoints
```

### Development

```bash
# Start development server
npm run dev

# Access at http://localhost:3000
```

The dev server includes:
- Hot Module Replacement (HMR)
- API proxying to backend services
- TypeScript type checking
- ESLint integration

## Building for Production

```bash
# Build for production
npm run build

# Preview production build
npm run preview

# Output will be in ./dist directory
```

## Project Structure

```
frontend/
├── src/
│   ├── api/                    # API clients and WebSocket
│   │   ├── client.ts           # HTTP API client (Axios)
│   │   └── websocket.ts        # WebSocket client (Socket.IO)
│   ├── components/             # React components
│   │   ├── Analytics/          # Analytics dashboard components
│   │   │   ├── Dashboard.tsx
│   │   │   ├── CostChart.tsx
│   │   │   ├── PerformanceChart.tsx
│   │   │   ├── ModelUsageChart.tsx
│   │   │   └── DateRangePicker.tsx
│   │   ├── Chat/               # Chat interface components
│   │   │   ├── ChatInterface.tsx
│   │   │   ├── MessageList.tsx
│   │   │   ├── MessageInput.tsx
│   │   │   └── ConversationSidebar.tsx
│   │   ├── KnowledgeBase/      # KB management components
│   │   │   ├── DocumentList.tsx
│   │   │   └── DocumentUpload.tsx
│   │   └── Layout/             # Layout components
│   │       ├── Layout.tsx
│   │       └── Sidebar.tsx
│   ├── pages/                  # Page components
│   │   ├── ChatPage.tsx
│   │   ├── AnalyticsPage.tsx
│   │   ├── KnowledgeBasePage.tsx
│   │   └── SettingsPage.tsx
│   ├── stores/                 # Zustand stores
│   │   ├── chatStore.ts        # Chat state management
│   │   ├── analyticsStore.ts   # Analytics state
│   │   └── knowledgeBaseStore.ts # KB state
│   ├── types/                  # TypeScript definitions
│   │   └── index.ts            # All type definitions
│   ├── utils/                  # Utility functions
│   │   ├── cn.ts               # Class name utilities
│   │   └── formatters.ts       # Formatting helpers
│   ├── App.tsx                 # Main app component
│   ├── main.tsx                # Application entry point
│   └── index.css               # Global styles
├── index.html                  # HTML template
├── vite.config.ts              # Vite configuration
├── tailwind.config.js          # Tailwind CSS config
├── tsconfig.json               # TypeScript config
└── package.json                # Dependencies
```

## Environment Variables

Create a `.env.local` file based on `.env.example`:

```bash
# API Configuration
VITE_CHAT_API_URL=http://localhost:8000
VITE_KB_API_URL=http://localhost:8001
VITE_ANALYTICS_API_URL=http://localhost:8002

# WebSocket Configuration
VITE_CHAT_WS_URL=ws://localhost:8000

# Application Configuration
VITE_APP_NAME=AI Customer Support
VITE_APP_VERSION=1.0.0

# Feature Flags
VITE_ENABLE_ANALYTICS=true
VITE_ENABLE_KB=true
VITE_ENABLE_SETTINGS=true
```

## API Integration

The frontend integrates with three backend services:

1. **Chat Service** (port 8000)
   - Conversation management
   - Message sending/receiving
   - Real-time chat via WebSocket

2. **Knowledge Base Service** (port 8001)
   - Document upload and storage
   - Semantic search
   - Category and tag management

3. **Analytics Service** (port 8002)
   - Usage metrics
   - Cost tracking
   - Performance monitoring

## Key Components

### Chat Interface

Real-time chat with message streaming, typing indicators, and citation display.

```typescript
import ChatInterface from '@/components/Chat/ChatInterface';

<ChatInterface conversationId={conversationId} />
```

### Analytics Dashboard

Comprehensive analytics with charts and metrics visualization.

```typescript
import Dashboard from '@/components/Analytics/Dashboard';

<Dashboard />
```

### Knowledge Base

Document management with upload, search, and filtering capabilities.

```typescript
import DocumentList from '@/components/KnowledgeBase/DocumentList';
import DocumentUpload from '@/components/KnowledgeBase/DocumentUpload';
```

## State Management

Using Zustand for lightweight and efficient state management:

```typescript
// Chat store
import { useChatStore } from '@/stores/chatStore';

const { messages, sendMessage } = useChatStore();

// Analytics store
import { useAnalyticsStore } from '@/stores/analyticsStore';

const { metrics, fetchMetrics } = useAnalyticsStore();
```

## Code Quality

```bash
# Type checking
npm run typecheck

# Linting
npm run lint
npm run lint:fix

# Formatting
npm run format
npm run format:check
```

## Testing

```bash
# Run tests
npm test

# Run tests with UI
npm run test:ui

# Run with coverage
npm run test:coverage
```

## Docker Deployment

```bash
# Build Docker image
docker build -t customer-support-frontend .

# Run container
docker run -p 80:80 customer-support-frontend
```

## Performance Optimization

- Code splitting with React.lazy()
- Memoization with React.memo() and useMemo()
- Virtual scrolling for large lists
- Optimized re-renders with Zustand
- Image lazy loading
- Bundle size optimization with Vite

## Browser Support

- Chrome (last 2 versions)
- Firefox (last 2 versions)
- Safari (last 2 versions)
- Edge (last 2 versions)

## Troubleshooting

### WebSocket connection fails

Check that the WebSocket URL in `.env.local` matches your backend configuration.

### API requests fail

Verify API URLs are correct and services are running. Check browser console for CORS errors.

### Build errors

Clear node_modules and reinstall:
```bash
rm -rf node_modules package-lock.json
npm install
```

## Contributing

1. Follow TypeScript strict mode
2. Use Tailwind CSS for styling
3. Add proper type definitions
4. Test components before committing
5. Follow existing code structure

## License

MIT
