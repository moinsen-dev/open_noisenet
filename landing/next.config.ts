import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'export',
  trailingSlash: true,
  images: {
    unoptimized: true,
  },
  // Root for the custom domain; explicitly set this for GitHub Pages.
  basePath: process.env.NEXT_PUBLIC_BASE_PATH || '',
};

export default nextConfig;