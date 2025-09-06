import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'export',
  trailingSlash: true,
  images: {
    unoptimized: true,
  },
  // Configure base path for GitHub Pages (if using custom domain, remove this)
  basePath: process.env.NODE_ENV === 'production' ? '/open_noisenet' : '',
  assetPrefix: process.env.NODE_ENV === 'production' ? '/open_noisenet' : '',
};

export default nextConfig;