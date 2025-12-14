// This file configures a web proxy for local development with the Flutter app
// running on port 8080 and the backend on port 8001.

export default {
  '/api/*': {
    target: 'http://localhost:8001',
    pathRewrite: { '^/api': '' },
    changeOrigin: true,
    secure: false,
  },
};