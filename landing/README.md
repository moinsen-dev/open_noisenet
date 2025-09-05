# OpenNoiseNet Landing Page

A stunning, modern landing page for the OpenNoiseNet community noise monitoring project. Built with Next.js 15, Tailwind CSS, and shadcn/ui components.

## Features

- ✨ **Modern Design**: Dark theme with OpenNoiseNet branding colors
- 📱 **Fully Responsive**: Mobile-first design that works on all devices
- 🎯 **Performance Optimized**: Next.js 15 with Turbopack for fast development
- 🔒 **Privacy-First**: GDPR/DSGVO compliant with comprehensive legal pages
- 🌐 **Multilingual**: German and English content for EU compliance
- 📊 **Interactive Elements**: Animated noise visualizations
- 🚀 **Docker Ready**: Production and development containerized deployment

## Tech Stack

- **Framework**: Next.js 15 with App Router
- **Styling**: Tailwind CSS with custom OpenNoiseNet theme
- **Components**: shadcn/ui with custom variants
- **Icons**: Lucide React
- **Language**: TypeScript
- **Deployment**: Docker with multi-stage builds

## Getting Started

### Development

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Or using Docker
docker-compose up landing-dev
```

Open [http://localhost:3000](http://localhost:3000) to view the landing page.

### Production

```bash
# Build for production
npm run build

# Start production server
npm start

# Or using Docker
docker-compose up landing
```

## Project Structure

```
landing/
├── src/
│   ├── app/                 # Next.js App Router pages
│   │   ├── imprint/         # Legal imprint page (German law)
│   │   ├── privacy/         # Privacy policy (GDPR compliant)
│   │   ├── terms/           # Terms of service
│   │   ├── layout.tsx       # Root layout with SEO
│   │   └── page.tsx         # Main landing page
│   ├── components/
│   │   ├── ui/              # shadcn/ui components
│   │   └── noise-visualization.tsx
│   └── lib/
│       └── utils.ts         # Tailwind utilities
├── public/                  # Static assets
├── docker-compose.yml       # Docker orchestration
├── Dockerfile              # Production build
├── Dockerfile.dev          # Development build
└── tailwind.config.ts      # Custom theme config
```

## Design System

### Colors

The landing page uses OpenNoiseNet's custom color palette derived from the project images:

- **Primary**: Orange accent (`warn-500` #f97316) for CTAs and highlights
- **Secondary**: Blue tones (`noise-*`) for data visualization and accents
- **Background**: Dark slate gradients for modern, professional appearance

### Components

- **Hero Section**: Eye-catching introduction with animated noise visualization
- **Problem/Solution**: Showcases environmental noise issues and OpenNoiseNet's approach
- **Features**: Highlights key platform capabilities
- **Download**: App store links for iOS and Android applications
- **Community**: GitHub contribution and open-source information
- **Newsletter**: GDPR-compliant email signup with double opt-in
- **Legal**: Comprehensive privacy policy, imprint, and terms pages

## Legal Compliance

This landing page includes comprehensive legal pages for German and EU compliance:

- **Privacy Policy**: GDPR/DSGVO compliant data protection information
- **Imprint (Impressum)**: German law requirement for website operators
- **Terms of Service**: Community guidelines and liability limitations

## Deployment

### Docker Production

```bash
# Build and run production container
docker build -t opennoisienet-landing .
docker run -p 3000:3000 opennoisienet-landing
```

### Environment Variables

Optional environment variables for production:

```env
NODE_ENV=production
PORT=3000
HOSTNAME=0.0.0.0
GOOGLE_SITE_VERIFICATION=your_verification_code
```

## Contributing

1. Follow the existing code style and component patterns
2. Test responsive design on multiple screen sizes
3. Ensure accessibility compliance (ARIA labels, keyboard navigation)
4. Update this README if adding new features

## License

This landing page is part of the OpenNoiseNet project, licensed under MIT. See the main project repository for full license details.

## Links

- **Main Repository**: https://github.com/moinsen-dev/open_noisenet
- **Project Documentation**: See main repository README
- **Community**: Join our open-source community for environmental monitoring