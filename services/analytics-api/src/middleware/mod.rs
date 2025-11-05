// Authentication and authorization middleware
pub mod auth;
pub mod caching;
pub mod rate_limit;

pub use auth::{AuthContext, JwtClaims, RequireAuth, Role};
pub use caching::{CacheConfig, CacheMiddleware};
pub use rate_limit::{RateLimitLayer, RateLimiter};
