import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'gRPC Testify',
  description: 'Automate gRPC server testing with configuration files',
  
  // Theme configuration
  themeConfig: {
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Getting Started', link: '/getting-started/installation' },
      { text: 'Examples', link: '/examples/' },
      { text: 'API Reference', link: '/api-reference/' },
      { text: 'Generator', link: '/generator' }
    ],

    sidebar: {
      '/getting-started/': [
        {
          text: 'Getting Started',
          items: [
            { text: 'Installation', link: '/getting-started/installation' },
            { text: 'Quick Start', link: '/getting-started/quick-start' },
            { text: 'Basic Concepts', link: '/getting-started/basic-concepts' }
          ]
        }
      ],
      '/examples/': [
        {
          text: 'Examples',
          items: [
            { text: 'Overview', link: '/examples/' },
            {
              text: 'Unary RPC',
              items: [
                { text: 'User Management', link: '/examples/user-management' }
              ]
            },
            {
              text: 'Streaming RPC', 
              items: [
                { text: 'File Storage (Client)', link: '/examples/file-storage' },
                { text: 'Payment System (Server)', link: '/examples/payment-system' },
                { text: 'Real-time Chat (Bidirectional)', link: '/examples/real-time-chat' }
              ]
            },
            {
              text: 'Advanced',
              items: [
                { text: 'Monitoring System', link: '/examples/monitoring-system' }
              ]
            }
          ]
        }
      ],
      '/api-reference/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Overview', link: '/api-reference/' },
            { text: 'Command Line', link: '/api-reference/command-line' },
            { text: 'Test Files', link: '/api-reference/test-files' },
            { text: 'Assertions', link: '/api-reference/assertions' },
            { text: 'Plugins', link: '/api-reference/plugins' }
          ]
        }
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/gripmock/grpctestify' }
    ],

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2024 gRPC Testify'
    }
  },

  // Custom head
  head: [
    ['link', { rel: 'icon', href: 'https://github.com/user-attachments/assets/d331a8db-4f4c-4296-950c-86b91ea5540a' }],
    ['meta', { name: 'viewport', content: 'width=device-width, initial-scale=1.0' }]
  ],

  // Build configuration
  build: {
    outDir: '../dist'
  },

  // Ignore dead links during build
  ignoreDeadLinks: false,

  // Custom syntax highlighting for GCTF files
  markdown: {
    config: (md) => {
      // Register GCTF language as PHP for better highlighting
      md.options.highlight = (str, lang) => {
        if (lang === 'gctf') {
          lang = 'php'
        }
        return str
      }
    }
  }
})
