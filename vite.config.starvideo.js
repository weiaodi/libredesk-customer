import { defineConfig } from 'vite'

export default defineConfig({
  root: '.',
  // 以 starvideo.html 作为入口页面
  server: {
    host: '0.0.0.0',
    port: 3333,
    open: '/starvideo.html',
    proxy: {
      // 将 /api 请求代理到后端，避免跨域
      '/api': {
        target: 'http://127.0.0.1:9000',
        changeOrigin: true,
      },
      // 代理 widget.js 和 widget 资源
      '/widget.js': {
        target: 'http://127.0.0.1:9000',
        changeOrigin: true,
      },
      '/widget/ws': {
        target: 'ws://127.0.0.1:9000',
        ws: true,
        changeOrigin: true,
      },
      '/ws': {
        target: 'ws://127.0.0.1:9000',
        ws: true,
        changeOrigin: true,
      },
      '/uploads': {
        target: 'http://127.0.0.1:9000',
        changeOrigin: true,
      },
    },
  },
})
